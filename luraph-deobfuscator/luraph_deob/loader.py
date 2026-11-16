"""Stage 1: evaluate the Luraph loader inside the sandboxed emulator and
capture the deserialised main prototype, *without* running the program.

The VM factory, its wrapper and the runtime closure are located statically
(see vm_analysis).  Hooks are installed on them:
  * factory(T, fields...)      -> records the prototype fields
  * wrapper(upvals, ...)        -> records which proto/upvalues a closure has
  * runtime(...)                -> STOP: this would start the user program
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from . import interp as I
from . import luau_ast as A
from . import stdlib
from . import vm_analysis as V


class LoaderError(Exception):
    pass


@dataclass
class Captured:
    vm: V.VMInfo
    vm_ast: A.Block
    main_runtime: Any  # LuaFunction of the runtime closure
    factory_args: tuple  # args the factory was called with for main proto
    wrapper_args: tuple
    interp: I.Interp
    env: I.LuaTable
    factory_calls: List[tuple] = field(default_factory=list)
    factory_map: Dict[int, tuple] = field(default_factory=dict)  # live: id(wrapper fn) -> factory args
    loaded_chunks: List[tuple] = field(default_factory=list)
    elapsed: float = 0.0


def _split_entry(ast: A.Block):
    """Return (loader_expr, calls_runtime_directly).

    Forms seen in v15.2:
        return setmetatable(T, {}):M()(...)
        return setmetatable(T, {}):M(...)
    """
    ret = ast.body[-1] if ast.body else None
    if not isinstance(ret, A.Return) or len(ret.values) != 1:
        raise LoaderError("unexpected top-level structure (no `return <loader>`)")
    e = ret.values[0]
    if isinstance(e, A.Call) and len(e.args) == 1 and isinstance(e.args[0], A.Vararg):
        return e.func, False
    if isinstance(e, A.MethodCall):
        return e, True
    return e, True


def capture(src: bytes, verbose=False, log=print) -> Captured:
    t0 = time.time()
    ast = A.parse(src)
    it = I.Interp()
    env = stdlib.make_env(it)
    state: Dict[str, Any] = {"vm": None, "vm_ast": None, "factory": {}, "wrapper": {}, "calls": []}

    def install(tree):
        try:
            vm = V.analyze(tree)
        except V.AnalysisError:
            return False
        state["vm"] = vm
        state["vm_ast"] = tree

        def on_factory(fn, args, inv):
            res = inv(fn, args)
            if res:
                state["factory"][id(res[0])] = args
                state["calls"].append(args)
            return res

        def on_wrapper(fn, args, inv):
            res = inv(fn, args)
            if res:
                state["wrapper"][id(res[0])] = (fn, args)
            return res

        def on_runtime(fn, args, inv):
            raise I.StopEmulation(fn)

        it.invoke_hooks[id(vm.factory)] = on_factory
        it.invoke_hooks[id(vm.wrapper)] = on_wrapper
        it.invoke_hooks[id(vm.runtime)] = on_runtime
        if verbose:
            log("[*] VM located: %d dispatch loops (modes %s)" % (
                len(vm.loops), ", ".join(str(l.mode) for l in vm.loops)))
        return True

    install(ast)
    # A compressed build ships the VM inside a loadstring'd chunk.
    it.on_load = lambda tree: (state["vm"] is None) and install(tree)

    loader, direct = _split_entry(ast)
    comp = I.Compiler(it, env, "Luraph")
    fn = comp.compile_chunk(A.Block([A.Return([loader])]))
    main = None
    try:
        res = fn()
        if res and isinstance(res[0], I.LuaFunction):
            main = res[0]
    except I.StopEmulation as st:
        main = st.value
    except I.LuaError as e:
        raise LoaderError("loader raised a Lua error: %r" % (e.value,))
    if state["vm"] is None:
        raise LoaderError("could not locate the VM")
    if main is None or id(main) not in state["wrapper"]:
        raise LoaderError("loader finished without producing the VM closure")
    wfn, wargs = state["wrapper"][id(main)]
    fargs = state["factory"].get(id(wfn))
    if fargs is None:
        raise LoaderError("main closure has no recorded prototype")
    return Captured(
        vm=state["vm"], vm_ast=state["vm_ast"], main_runtime=main, factory_args=fargs,
        wrapper_args=wargs, interp=it, env=env, factory_calls=state["calls"], factory_map=state["factory"],
        loaded_chunks=list(it.loaded_chunks), elapsed=time.time() - t0,
    )
