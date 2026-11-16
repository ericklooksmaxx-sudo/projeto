"""Dynamic dumper ("environment logger") for Luau scripts.

The target script is *executed* inside the sandboxed emulator (``interp`` +
``stdlib``: no file, network or OS access) with a Roblox-like environment
made of recording proxies.  Every interaction with the environment
(``game:GetService(...)``, ``Instance.new``, property reads/writes, method
calls, ``loadstring`` ...) is logged and re-emitted as readable Lua, so the
observable behaviour of an obfuscated script is reconstructed independently
of the obfuscator (works for any Luraph version, or any other VM-based
obfuscator, as long as the script reaches the environment).

Limits (inherent to tracing): only the code paths that actually execute are
seen; branches never taken, and values that only a real Roblox server would
produce, cannot be recovered.
"""
from __future__ import annotations

import ctypes
import re
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from . import interp as I
from . import luau_ast as A
from . import stdlib
from .interp import Builtin, LuaError, LuaFunction, LuaTable

# constructors / datatypes whose calls are pure values: rendered inline, never as statements
EXTRA_DATATYPES = ["Path2DControlPoint", "Content", "CatalogSearchParams", "DockWidgetPluginGuiInfo", "FloatCurveKey",
                   "RotationCurveKey", "SecurityCapabilities", "SharedTable", "TextChatMessageProperties", "UniqueId",
                   "Vector3int16", "Vector2int16", "Region3int16", "CFrameKeyframe", "PathWaypoint", "Secret"]
PURE_ROOTS = {
    "Vector3", "Vector2", "UDim", "UDim2", "Color3", "Rect", "CFrame", "BrickColor", "NumberRange",
    "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Ray",
    "Region3", "TweenInfo", "Enum", "Axes", "Faces", "PhysicalProperties", "Font", "DateTime",
    "Random", "OverlapParams", "RaycastParams",
}
GLOBAL_PROXIES = ["game", "workspace", "script", "shared", "plugin", "Instance", "Enum", "task", "Drawing",
                  "Vector3", "Vector2", "UDim", "UDim2", "Color3", "Rect", "CFrame", "BrickColor", "NumberRange",
                  "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Ray",
                  "Region3", "TweenInfo", "Axes", "Faces", "PhysicalProperties", "Font", "DateTime", "Random",
                  "OverlapParams", "RaycastParams", "RaycastResult", "Stats", "settings", "UserSettings",
                  "Players", "Lighting", "ReplicatedStorage", "RunService", "UserInputService", "TweenService",
                  "HttpService", "TeleportService", "StarterGui", "CoreGui", "SoundService", "Workspace",
                  "Game"]
IMMEDIATE_CALLS = {"task.spawn", "task.defer", "task.delay", "spawn", "delay", "defer", "coroutine.wrap",
                   "coroutine.create", "xpcall", "pcall"}
_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_LUA_KW = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
           "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue"}


class WatchdogTimeout(BaseException):
    pass


@dataclass
class Block:
    items: List[Any] = field(default_factory=list)  # ("stmt", var, text) | ("raw", text)


@dataclass
class DumpResult:
    source: str
    chunks: List[bytes] = field(default_factory=list)
    error: Optional[str] = None
    timed_out: bool = False
    events: int = 0
    seconds: float = 0.0


def lua_str(b: bytes) -> str:
    out = ['"']
    for c in b:
        ch = chr(c)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif 32 <= c < 127:
            out.append(ch)
        else:
            out.append("\\%03d" % c)
    out.append('"')
    return "".join(out)


def fmt_num(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if v != v:
        return "(0/0)"
    if v in (float("inf"), float("-inf")):
        return "math.huge" if v > 0 else "-math.huge"
    if v == int(v) and abs(v) < 2 ** 53:
        return str(int(v))
    return repr(v)


class Info:
    __slots__ = ("expr", "parent", "key", "pure", "var", "kind")

    def __init__(self, expr, parent=None, key=None, pure=False, var=None, kind="userdata"):
        self.expr = expr
        self.parent = parent
        self.key = key
        self.pure = pure
        self.var = var
        self.kind = kind


class Tracer:
    def __init__(self, it: I.Interp, max_events=200000, max_depth=6):
        self.it = it
        self.root = Block()
        self.cur = self.root
        self.info: Dict[int, Info] = {}
        self.keep: List[Any] = []  # keep proxies alive so ids stay unique
        self.fn_blocks: Dict[int, Block] = {}
        self.fn_params: Dict[int, List[str]] = {}
        self.fn_obj: Dict[int, Any] = {}
        self.pending: List[Any] = []
        self.chunks: List[bytes] = []
        self.var_count = 0
        self.var_names: Dict[str, int] = {}
        self.events = 0
        self.max_events = max_events
        self.max_depth = max_depth
        self.service_cache: Dict[str, LuaTable] = {}
        self.meta = self._make_meta()
        self.running_cb = 0
        self.spec_params = set()

    # ------------------------------------------------------------------ proxies
    def new_proxy(self, expr, **kw) -> LuaTable:
        t = LuaTable()
        t.meta = self.meta
        self.info[id(t)] = Info(expr, **kw)
        self.keep.append(t)
        return t

    def is_proxy(self, v) -> bool:
        return type(v) is LuaTable and id(v) in self.info

    def _make_meta(self) -> LuaTable:
        m = LuaTable()
        tr = self

        def reg(name, f):
            m.h[name] = Builtin(f, name.decode())

        def index(o, k, *r):
            return (tr.index(o, k),)

        def newindex(o, k, v, *r):
            tr.assign(o, k, v)
            return ()

        def call(f, *args):
            return tr.call(f, args)

        def tostr(o, *r):
            return (tr.info[id(o)].expr.encode(),)

        def binop(sym):
            def f(a, b, *r):
                return (tr.value("(%s %s %s)" % (tr.fmt(a), sym, tr.fmt(b))),)
            return f

        def unm(a, *r):
            return (tr.value("(-%s)" % tr.fmt(a)),)

        reg(b"__index", index)
        reg(b"__newindex", newindex)
        reg(b"__call", call)
        reg(b"__tostring", tostr)
        for ev, sym in ((b"__add", "+"), (b"__sub", "-"), (b"__mul", "*"), (b"__div", "/"), (b"__mod", "%"),
                        (b"__pow", "^"), (b"__idiv", "//"), (b"__concat", "..")):
            reg(ev, binop(sym))
        reg(b"__unm", unm)
        reg(b"__len", lambda o, *r: (0,))
        reg(b"__eq", lambda a, b, *r: (False,))
        reg(b"__lt", lambda a, b, *r: (False,))
        reg(b"__le", lambda a, b, *r: (False,))
        return m

    def value(self, expr) -> LuaTable:
        return self.new_proxy(expr, pure=True)

    # ------------------------------------------------------------------ formatting
    def key_suffix(self, k):
        if type(k) is bytes:
            try:
                s = k.decode("ascii")
            except UnicodeDecodeError:
                s = None
            if s is not None and _IDENT.match(s) and s not in _LUA_KW:
                return "." + s
            return "[%s]" % lua_str(k)
        return "[%s]" % self.fmt(k)

    def fmt(self, v, depth=0) -> str:
        t = type(v)
        if v is None:
            return "nil"
        if t is bool:
            return "true" if v else "false"
        if t in (int, float):
            return fmt_num(v)
        if t is bytes:
            return lua_str(v)
        if t is LuaTable:
            inf = self.info.get(id(v))
            if inf is not None:
                if inf.var:
                    self.mark_use(inf.var)
                return inf.expr
            return self.fmt_table(v, depth)
        if t is LuaFunction:
            return self.fmt_function(v)
        if t is Builtin:
            return v.name
        if t is I.Vector:
            return "Vector3.new(%s, %s, %s)" % tuple(fmt_num(x) for x in v)
        if t is I.Opaque:
            return "%s(%s)" % (v.kind, ", ".join(self.fmt(a) for a in v.args))
        return "nil --[[%s]]" % I.type_name(v)

    def mark_use(self, var):
        pass  # usage is counted textually when rendering

    def fmt_table(self, tb: LuaTable, depth) -> str:
        if depth >= self.max_depth:
            return "{}"
        items = []
        n = tb.length()
        seen = set()
        for i in range(1, n + 1):
            seen.add(i)
            items.append(self.fmt(tb.h.get(i), depth + 1))
            if len(items) > 200:
                items.append("--[[ ... ]]")
                break
        count = 0
        for k, val in tb.h.items():
            if k in seen:
                continue
            count += 1
            if count > 200:
                items.append("--[[ ... ]]")
                break
            kk = I.unkey(k) if hasattr(I, "unkey") else k
            if type(kk) is bytes:
                try:
                    s = kk.decode("ascii")
                except UnicodeDecodeError:
                    s = None
                ks = s if (s is not None and _IDENT.match(s) and s not in _LUA_KW) else "[%s]" % lua_str(kk)
            else:
                ks = "[%s]" % self.fmt(kk, depth + 1)
            items.append("%s = %s" % (ks, self.fmt(val, depth + 1)))
        return "{%s}" % ", ".join(items)

    def fmt_function(self, f) -> str:
        blk = self.fn_blocks.get(id(f))
        if blk is None:
            blk = Block()
            self.fn_blocks[id(f)] = blk
            self.fn_obj[id(f)] = f
            self.pending.append(f)
        if id(f) not in self.fn_params:
            self.fn_params[id(f)] = self.params_of(f)
        return "\x00FN%d\x00" % id(f)

    def params_of(self, f):
        """Callback parameter names; vararg functions (all obfuscator VM closures)
        get speculative names a1..a3, trimmed at render time to those actually used."""
        pr = getattr(f, "proto", None)
        n = getattr(pr, "nparams", 0) or 0
        if getattr(pr, "vararg", False) and n == 0:
            self.spec_params.add(id(f))
            n = 3
        return ["a%d" % (i + 1) for i in range(n)]

    # ------------------------------------------------------------------ events
    def emit(self, text, var=None):
        self.events += 1
        if self.events > self.max_events:
            raise WatchdogTimeout()
        self.cur.items.append(("stmt", var, text))

    def raw(self, text):
        self.cur.items.append(("raw", text))

    def hint(self, text, key=None):
        base = None
        m = re.match(r'^.*:GetService\("([A-Za-z0-9_]+)"\)$', text)
        if m:
            base = m.group(1)
        m = re.match(r'^Instance\.new\("([A-Za-z0-9_]+)"', text)
        if m:
            base = m.group(1)[0].lower() + m.group(1)[1:]
        m = re.match(r'^.*:(?:FindFirstChild|WaitForChild|FindFirstChildOfClass|FindFirstAncestor)\("([A-Za-z_][A-Za-z0-9_]*)"', text)
        if m:
            base = m.group(1)[0].lower() + m.group(1)[1:]
        if text == "loaded":
            base = "loaded"
        if base is None or base in _LUA_KW:
            base = "v"
        n = self.var_names.get(base, 0) + 1
        self.var_names[base] = n
        return base if n == 1 and base != "v" else "%s%d" % (base, n)

    def index(self, o, k):
        inf = self.info[id(o)]
        suffix = self.key_suffix(k)
        expr = inf.expr + suffix
        child = self.new_proxy(expr, parent=o, key=k, pure=inf.pure)
        return child

    def assign(self, o, k, v):
        inf = self.info[id(o)]
        self.emit("%s%s = %s" % (inf.expr, self.key_suffix(k), self.fmt(v)))

    def call(self, f, args):
        inf = self.info[id(f)]
        args = list(args)
        method = None
        if inf.parent is not None and args and args[0] is inf.parent and type(inf.key) is bytes:
            # obj:Method(...)
            method = inf.key
            args = args[1:]
            pexpr = self.fmt(inf.parent)
            name = method.decode("latin-1")
            callee = "%s:%s" % (pexpr, name) if (_IDENT.match(name) and name not in _LUA_KW) else None
            if callee is None:
                callee = "%s%s" % (pexpr, self.key_suffix(inf.key))
                args = [inf.parent] + args
        else:
            callee = inf.expr
        root = callee.split(".")[0].split(":")[0]
        qual = callee.replace(":", ".")
        immediate = qual in IMMEDIATE_CALLS
        # functions passed in are scripts' callbacks: run inline for spawn-like, later otherwise
        for a in args:
            if type(a) is LuaFunction and immediate:
                self.run_callback(a, [])
        text = "%s(%s)" % (callee, ", ".join(self.fmt(a) for a in args))
        if inf.pure or root in PURE_ROOTS and method is None:
            return (self.value(text),)
        if method == b"GetService" and args and type(args[0]) is bytes:
            cached = self.service_cache.get(text)
            if cached is not None:
                return (cached,)
        var = self.hint(text)
        res = self.new_proxy(var, var=var)
        self.emit(text, var)
        if method == b"GetService" and args and type(args[0]) is bytes:
            self.service_cache[text] = res
        if method in (b"HttpGet", b"HttpGetAsync", b"GetAsync", b"RequestAsync") or qual.endswith("request"):
            self.info[id(res)].kind = "http"
        return (res,)

    # ------------------------------------------------------------------ callbacks
    def run_callback(self, f, args, depth=0):
        blk = self.fn_blocks.get(id(f))
        if blk is None:
            blk = Block()
            self.fn_blocks[id(f)] = blk
            self.fn_obj[id(f)] = f
        if getattr(blk, "ran", False):
            return
        blk.ran = True
        saved = self.cur
        self.cur = blk
        try:
            self.it.call(f, tuple(args))
        except LuaError as e:
            self.raw("-- error: %s" % self.err_text(e))
        finally:
            self.cur = saved

    def err_text(self, e):
        v = e.value
        msg = (v.decode("latin-1") if type(v) is bytes else str(v)).replace("\n", " ")[:300]
        if e.lua_traceback:
            msg += " [%s]" % e.lua_traceback
        return msg

    def run_pending(self, budget=2000):
        rounds = 0
        while self.pending and rounds < budget:
            f = self.pending.pop(0)
            blk = self.fn_blocks.get(id(f))
            if blk is not None and getattr(blk, "ran", False):
                continue
            params = self.fn_params.get(id(f)) or self.params_of(f)
            self.fn_params[id(f)] = params
            args = [self.new_proxy(p) for p in params]
            self.run_callback(f, args)
            rounds += 1

    # ------------------------------------------------------------------ rendering
    def render_block(self, blk: Block, indent: int, depth: int = 0) -> str:
        pad = "    " * indent
        lines = []
        tok = re.compile("\x00FN(\\d+)\x00")

        def expand(m, pad_):
            fid = int(m.group(1))
            b = self.fn_blocks.get(fid)
            plist = list(self.fn_params.get(fid, []))
            if b is None or not b.items or depth > 40:
                if fid in self.spec_params:
                    plist = []
                return "function(%s) end" % ", ".join(plist)
            body = self.render_block(b, len(pad_) // 4 + 1, depth + 1)
            if fid in self.spec_params:
                used = [int(x) for x in re.findall(r"(?<![A-Za-z0-9_])a(\d+)(?![A-Za-z0-9_])", body)]
                plist = plist[:max(used)] if used else []
            return "function(%s)\n%s\n%send" % (", ".join(plist), body, pad_)

        for item in blk.items:
            if item[0] == "raw":
                text = item[1]
            else:
                _, var, t = item
                text = ("local %s = %s" % (var, t)) if var else t
            text = tok.sub(lambda m: expand(m, pad), text)
            first, *rest = text.split("\n")
            lines.append(pad + first)
            lines.extend(rest)
        return "\n".join(lines)

    def render(self) -> str:
        text = self.render_block(self.root, 0)
        # drop `local vN = ` for variables never used afterwards
        names = set()
        for m in re.finditer(r"^\s*local ([A-Za-z_][A-Za-z0-9_]*) = ", text, re.M):
            names.add(m.group(1))
        for n in names:
            uses = len(re.findall(r"(?<![A-Za-z0-9_.\"])%s(?![A-Za-z0-9_\"])" % re.escape(n), text))
            if uses <= 1:
                text = re.sub(r"^(\s*)local %s = " % re.escape(n), r"\1", text, flags=re.M)
        return text


# ---------------------------------------------------------------------------
# environment
# ---------------------------------------------------------------------------

def build_env(it: I.Interp, tr: Tracer, opts) -> LuaTable:
    G = stdlib.make_env(it)

    def reg(tbl, name, f):
        tbl.h[name.encode()] = Builtin(f, name)

    for nm in EXTRA_DATATYPES:
        PURE_ROOTS.add(nm)
    for nm in GLOBAL_PROXIES + EXTRA_DATATYPES:
        G.h[nm.encode()] = tr.new_proxy(nm, pure=(nm in PURE_ROOTS))
    # `task` is a proxy: spawn/wait etc. are logged and executed inline by Tracer.call

    base_type = G.h[b"type"]
    orig_typeof = G.h[b"typeof"]

    def l_typeof(*a):
        v = a[0] if a else None
        if tr.is_proxy(v):
            k = tr.info[id(v)].kind
            return (b"Instance" if k == "userdata" else b"userdata",)
        return orig_typeof.f(*a)

    def l_type(*a):
        v = a[0] if a else None
        if tr.is_proxy(v):
            return (b"userdata",)
        return base_type.f(*a)

    reg(G, "typeof", l_typeof)
    reg(G, "type", l_type)

    def stmt_call(name):
        def f(*args):
            text = "%s(%s)" % (name, ", ".join(tr.fmt(a) for a in args))
            tr.emit(text)
            for a in args:
                if type(a) is LuaFunction and name in ("spawn", "delay", "defer"):
                    tr.run_callback(a, [])
            return ()
        return f

    for nm in ("print", "warn", "printidentity"):
        reg(G, nm, stmt_call(nm))
    for nm in ("spawn", "delay", "defer"):
        reg(G, nm, stmt_call(nm))

    def l_wait(*a):
        return (0.03, 0.0)
    reg(G, "wait", l_wait)

    clock = [0.0]

    def l_tick(*a):
        clock[0] += 0.01
        return (1_700_000_000.0 + clock[0],)
    reg(G, "tick", l_tick)
    reg(G, "time", l_tick)
    reg(G, "elapsedTime", l_tick)

    # loadstring: capture and execute the chunk under the tracer
    def l_loadstring(src=None, name=b"=(load)", *r):
        if tr.is_proxy(src):
            expr = tr.fmt(src)

            def remote_chunk(*a):
                var = tr.hint("loaded")
                res = tr.new_proxy(var, var=var)
                tr.emit("loadstring(%s)(%s)" % (expr, ", ".join(tr.fmt(x) for x in a)), var)
                return (res,)
            tr.raw("-- loadstring of remote/unknown source (not executed in the sandbox)")
            return (Builtin(remote_chunk, "loadstring_chunk"),)
        if type(src) is not bytes:
            return (None, b"bad argument")
        idx = len(tr.chunks) + 1
        tr.chunks.append(src)
        try:
            ast = A.parse(src)
        except Exception as e:
            tr.raw("-- loadstring chunk %d (%d bytes): syntax error: %s" % (idx, len(src), str(e)[:100]))
            return (None, str(e).encode())
        tr.raw("-- loadstring chunk %d (%d bytes) -> chunk%d.lua" % (idx, len(src), idx))
        comp = I.Compiler(it, G, "chunk%d" % idx)
        fn = comp.compile_chunk(ast)

        def run(*a):
            tr.raw("-- begin chunk %d" % idx)
            res = it.call(fn, a)
            tr.raw("-- end chunk %d" % idx)
            return res
        return (Builtin(run, "chunk%d" % idx),)
    reg(G, "loadstring", l_loadstring)
    reg(G, "load", l_loadstring)

    # executor-style globals
    reg(G, "getgenv", lambda *a: (G,))
    reg(G, "getrenv", lambda *a: (G,))
    reg(G, "getfenv", lambda *a: (G,))
    reg(G, "setfenv", lambda f=None, *a: (f,))
    reg(G, "getreg", lambda *a: (LuaTable(),))
    isl = lambda f=None, *a: (type(f) is LuaFunction,)
    for nm in ("islclosure", "is_l_closure", "is_lua_closure"):
        reg(G, nm, isl)
    for nm in ("iscclosure", "is_c_closure", "is_cclosure"):
        reg(G, nm, lambda f=None, *a: (type(f) is not LuaFunction,))
    for nm in ("isexecutorclosure", "is_synapse_function", "is_our_closure", "checkclosure"):
        reg(G, nm, lambda f=None, *a: (False,))
    for nm in ("getconstants", "getupvalues", "getprotos", "getstack", "getupvalues", "get_upvalues"):
        reg(G, nm, lambda *a: (LuaTable(),))
    for nm in ("getconstant", "getupvalue", "getproto", "get_upvalue"):
        reg(G, nm, lambda *a: (None,))
    reg(G, "identifyexecutor", lambda *a: (b"Dumper", b"1.0"))
    reg(G, "checkcaller", lambda *a: (True,))
    reg(G, "hookfunction", lambda f=None, g=None, *a: (f,))
    reg(G, "newcclosure", lambda f=None, *a: (f,))
    reg(G, "clonefunction", lambda f=None, *a: (f,))
    reg(G, "setclipboard", stmt_call("setclipboard"))
    reg(G, "queue_on_teleport", stmt_call("queue_on_teleport"))
    reg(G, "request", lambda *a: (tr.call(tr.new_proxy("request", pure=False), a)[0],))
    reg(G, "http_request", lambda *a: (tr.call(tr.new_proxy("http_request", pure=False), a)[0],))
    reg(G, "require", lambda *a: (tr.call(tr.new_proxy("require"), a)[0],))
    G.h[b"_G"] = G
    # remember which undefined globals the script reads (useful to spot missing API)
    missing = tr.missing = {}
    gm = LuaTable()

    def g_index(_t, k, *r):
        if type(k) is bytes:
            missing[k.decode("latin-1")] = missing.get(k.decode("latin-1"), 0) + 1
        return (None,)
    gm.h[b"__index"] = Builtin(g_index, "__index")
    G.meta = gm
    return G


def _dump_once(src: bytes, timeout: float = 120.0, max_events: int = 200000, run_callbacks: bool = True,
         recursion: int = 200000) -> DumpResult:
    import sys
    t0 = time.time()
    it = I.Interp()
    tr = Tracer(it, max_events=max_events)
    G = build_env(it, tr, None)
    out = {"error": None, "timeout": False}

    def target():
        try:
            ast = A.parse(src)
            comp = I.Compiler(it, G, "script")
            fn = comp.compile_chunk(ast)
            try:
                it.call(fn, ())
            except LuaError as e:
                out["error"] = tr.err_text(e)
                tr.raw("-- error: %s" % out["error"])
                if getattr(tr, "missing", None):
                    tr.raw("-- undefined globals read: %s" % ", ".join(sorted(tr.missing)[:40]))
            if run_callbacks:
                tr.run_pending()
        except WatchdogTimeout:
            out["timeout"] = True
            tr.raw("-- dump stopped: time/event budget exhausted")
        except RecursionError:
            out["error"] = "recursion limit"
            tr.raw("-- error: recursion limit")
        except Exception as e:  # parse errors etc.
            out["error"] = "%s: %s" % (type(e).__name__, str(e)[:200])
            tr.raw("-- error: %s" % out["error"])

    old = sys.getrecursionlimit()
    sys.setrecursionlimit(recursion)
    threading.stack_size(512 * 1024 * 1024)
    th = threading.Thread(target=target, daemon=True)
    th.start()
    th.join(timeout)
    if th.is_alive():
        ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_ulong(th.ident), ctypes.py_object(WatchdogTimeout))
        th.join(10)
        out["timeout"] = True
    sys.setrecursionlimit(old)
    threading.stack_size(0)
    header = ["-- Dumped by luraph-deob envlog (script executed in a sandboxed emulator)",
              "-- events: %d | loadstring chunks: %d%s" % (
                  tr.events, len(tr.chunks), " | INCOMPLETE (timeout)" if out["timeout"] else ""), ""]
    text = "\n".join(header) + tr.render() + "\n"
    return DumpResult(text, tr.chunks, out["error"], out["timeout"], tr.events, time.time() - t0)


def repair_mojibake(src: bytes) -> Optional[bytes]:
    """Some sample sets were re-encoded (Latin-1/cp1252 bytes -> UTF-8), which corrupts
    the binary payload inside string literals.  Undo that when the whole file is valid
    UTF-8 with non-ASCII text that maps back to single bytes."""
    if all(b < 128 for b in src):
        return None
    try:
        text = src.decode("utf-8")
    except UnicodeDecodeError:
        return None
    out = bytearray()
    for ch in text:
        o = ord(ch)
        if o < 128:
            out.append(o)
            continue
        try:
            out += ch.encode("cp1252")
        except UnicodeEncodeError:
            if o < 256:
                out.append(o)
            else:
                return None
    return bytes(out)


def dump(src: bytes, timeout: float = 120.0, max_events: int = 200000, run_callbacks: bool = True,
         recursion: int = 200000, repair: bool = True) -> DumpResult:
    res = _dump_once(src, timeout, max_events, run_callbacks, recursion)
    if repair and (res.error or res.events == 0):
        fixed = repair_mojibake(src)
        if fixed is not None and fixed != src:
            alt = _dump_once(fixed, timeout, max_events, run_callbacks, recursion)
            if alt.events > res.events or (res.error and not alt.error):
                alt.source = alt.source.replace(
                    "\n", "\n-- note: input was UTF-8/cp1252 re-encoded; repaired before running\n", 1)
                return alt
    return res
