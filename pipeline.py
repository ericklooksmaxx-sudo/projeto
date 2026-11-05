import os
import re
import json
import tempfile
import asyncio
import shutil
import platform
from typing import Optional, Tuple, List

from tidy import format_lua
import fingerprint
import classifier

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TOOLS_DIR = os.path.join(BASE_DIR, "tools")
VENDOR_DIR = os.path.join(BASE_DIR, "vendor")

HOLLOW_HEADER = "--  [[ Logged by Hollow Logger https://discord.gg/UWjSZ5ugGJ ]]"

WEBHOOK_REGEXES = [
    re.compile(
        r"https?://(?:ptb\.|canary\.)?discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_\-]+",
        re.IGNORECASE,
    ),
    re.compile(
        r"https?://(?:www\.)?guilded\.gg/api/webhooks/[a-f0-9\-]+/[A-Za-z0-9_\-]+",
        re.IGNORECASE,
    ),
]

FOREIGN_WATERMARKS_REGEXES = [
    re.compile(r"^\s*--\s*(?:Disassembled with MoonSec[^\n]*|MoonsecDeobfuscator[^\n]*|by #tupsutumppu[^\n]*)", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*--\s*(?:Deobfuscated by|Detected obfuscation|Local names are inferred|source:|NOTE: reconstructed|during the trace)[^\n]*", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*--\s*\[envlog\][^\n]*", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*--\s*This file was (?:protected|obfuscated) using [^\n]*", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*--\s*\[\[\s*(?:Logged by|Deobfuscated by)\s+Hollow Logger[^\n]*\]\]", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*--\s*\[\[\s*(?:Logged by|Deobfuscated by)[^\n]*\]\]", re.MULTILINE | re.IGNORECASE),
]


def find_webhooks(text: str) -> List[str]:
    found = []
    for rx in WEBHOOK_REGEXES:
        for match in rx.finditer(text):
            url = match.group(0)
            if url not in found:
                found.append(url)
    return found


def clean_foreign_watermarks(code: str) -> str:
    """Removes previous tool watermarks and headers so only Hollow Logger header remains."""
    cleaned = code
    for rx in FOREIGN_WATERMARKS_REGEXES:
        cleaned = rx.sub("", cleaned)
    # Strip empty lines from top
    cleaned = cleaned.lstrip("\r\n \t")
    return cleaned


def with_hollow_header(code: str) -> str:
    cleaned = clean_foreign_watermarks(code)
    if cleaned.startswith(HOLLOW_HEADER):
        return cleaned
    return f"{HOLLOW_HEADER}\n\n{cleaned}"


def _find_java() -> Optional[str]:
    return shutil.which("java")


def _find_dotnet() -> Optional[str]:
    return shutil.which("dotnet")


def _find_node() -> Optional[str]:
    return shutil.which("node")


def _prepare_luau_bin() -> str:
    """Ensures luau, luau-ast and darklua are in a non-noexec directory (/tmp/bin_exec) and executable."""
    tmp_bin = "/tmp/bin_exec"
    try:
        os.makedirs(tmp_bin, exist_ok=True)
        arch = platform.machine().lower()
        suffix = "aarch64" if ("aarch64" in arch or "arm64" in arch) else "x86_64"

        for tool in ("luau", "luau-ast", "darklua"):
            dest = os.path.join(tmp_bin, tool)
            src_cands = [
                os.path.join(TOOLS_DIR, f"{tool}-{suffix}"),
                os.path.join(TOOLS_DIR, tool),
                os.path.join(BASE_DIR, tool),
            ]
            for cand in src_cands:
                if os.path.isfile(cand):
                    if not os.path.isfile(dest) or os.path.getmtime(cand) > os.path.getmtime(dest):
                        shutil.copy2(cand, dest)
                        os.chmod(dest, 0o755)
                    break
        return tmp_bin
    except Exception as exc:
        print(f"[pipeline] prepare luau bin error: {exc}")
        return tmp_bin


def _prepare_moonsec_dir() -> str:
    """Ensures MoonSec native binaries and libraries are in a non-noexec directory (/tmp/moonsec_bin)."""
    src_dir = os.path.join(TOOLS_DIR, "moonsec")
    tmp_dir = "/tmp/moonsec_bin"
    try:
        os.makedirs(tmp_dir, exist_ok=True)
        if os.path.isdir(src_dir):
            for item in os.listdir(src_dir):
                s = os.path.join(src_dir, item)
                d = os.path.join(tmp_dir, item)
                if not os.path.exists(d) or os.path.getmtime(s) > os.path.getmtime(d):
                    if os.path.isdir(s):
                        shutil.copytree(s, d, dirs_exist_ok=True)
                    else:
                        shutil.copy2(s, d)
        return tmp_dir
    except Exception:
        return src_dir


async def decompile_bytecode_unluac(luac_path: str) -> Optional[str]:
    """Decompiles Lua 5.1 bytecode (.luac) to clean Lua source using unluac."""
    unluac_jar = os.path.join(TOOLS_DIR, "unluac.jar")
    java_bin = _find_java()
    if not java_bin or not os.path.isfile(unluac_jar) or not os.path.isfile(luac_path):
        return None

    try:
        proc = await asyncio.create_subprocess_exec(
            java_bin, "-jar", unluac_jar, luac_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=20)
        if proc.returncode == 0 and stdout:
            text = stdout.decode("utf-8", errors="replace")
            if text.strip():
                return text
    except Exception as exc:
        print(f"[pipeline] unluac decompile failed: {exc}")
    return None



def post_reconstruct_luau(code: str) -> str:
    """
    Structural Luau reconstruction pass:
    - Prunes dead environment probe lines (`local _ = _G["string"]`, etc.)
    - Converts `obj["Method"](obj, a, b)` -> `obj:Method(a, b)` and `obj["Method"](obj)` -> `obj:Method()`
    - Converts `obj["field"]` -> `obj.field` for valid Luau identifiers
    - Folds repeated `local _ = task.wait(X)` + body sequences inside callbacks into `while task.wait(X) do ... end`
    """
    if not code:
        return code

    LUA_KEYWORDS = {
        "and", "break", "do", "else", "elseif", "end", "false", "for",
        "function", "if", "in", "local", "nil", "not", "or", "repeat",
        "return", "then", "true", "until", "while", "continue",
    }

    lines = code.splitlines()
    pruned = []
    for line in lines:
        stripped = line.strip()
        # Prune discarded _G / getgenv stdlib probes emitted by obfuscator VM headers
        if re.match(r'^local\s+_\s*=\s*(?:_G|genv|fenv)\["(?:string|table|math|tonumber|tostring|pcall|xpcall|select|unpack|next|pairs|ipairs|type|typeof|assert|error|getfenv|setfenv|rawget|rawset|rawequal|rawlen|setmetatable|getmetatable|bit|bit32|buffer|utf8|coroutine|os|debug)"\]\s*$', stripped):
            continue
        pruned.append(line)

    text = "\n".join(pruned)

    # Convert obj["Method"](obj, ...) -> obj:Method(...)
    text = re.sub(
        r'([A-Za-z_][A-Za-z0-9_\.\[\]]*)\["([A-Za-z_][A-Za-z0-9_]*)"\]\(\1\s*,\s*',
        r'\1:\2(',
        text,
    )
    text = re.sub(
        r'([A-Za-z_][A-Za-z0-9_\.\[\]]*)\["([A-Za-z_][A-Za-z0-9_]*)"\]\(\1\)',
        r'\1:\2()',
        text,
    )

    # Convert bracket string indexing obj["Prop"] -> obj.Prop when Prop is a valid non-keyword identifier
    def _bracket_to_dot(m: re.Match) -> str:
        prefix, prop = m.group(1), m.group(2)
        if prop in LUA_KEYWORDS:
            return m.group(0)
        return f"{prefix}.{prop}"

    text = re.sub(
        r'([A-Za-z0-9_\)\]])\["([A-Za-z_][A-Za-z0-9_]*)"\]',
        _bracket_to_dot,
        text,
    )

    # Fold repeated `local _ = task.wait(...)` loop bodies into a `while task.wait(...) do ... end` block
    text = re.sub(
        r"(?:local\s+_\s*=\s*((?:task\.)?wait\([^)]*\))\n([^\n]+)(?:\nlocal\s+_\s*=\s*[^\n]+)+)",
        r"while \1 do\n    \2\nend\n",
        text,
    )

    # Remove unused `local _ = ` prefix on standalone statement calls like `local _ = task.spawn(...)` or `local _ = print(...)`
    text = re.sub(
        r'^(\s*)local\s+_\s*=\s*((?:task\.(?:spawn|defer|delay|wait|cancel|desynchronize|synchronize)|wait|spawn|delay|print|warn|error|writefile|appendfile|mkdir|setclipboard|toclipboard|rconsoleprint|rconsolewarn))',
        r'\1\2',
        text,
        flags=re.MULTILINE,
    )

    return text


async def reconstruct_and_format_lua(source: str, rename: bool = False) -> str:
    """
    Reconstructs deobfuscated Lua code to make it readable and formatted:
    1. Foreign watermarks stripping
    2. Darklua optimization rules pass (convert_index_to_field, remove_nil, etc.)
    3. Variable renaming pass if requested or beneficial
    4. Lexer-based formatting and indentation pass
    5. Hollow Logger header placement
    """
    if not source or not source.strip():
        return source

    cleaned = post_reconstruct_luau(clean_foreign_watermarks(source))

    # 1. Darklua readable pass
    tmp_bin = _prepare_luau_bin()
    darklua_bin = os.path.join(tmp_bin, "darklua")
    if not os.path.isfile(darklua_bin):
        darklua_bin = shutil.which("darklua") or "darklua"

    config_data = {
        "generator": "readable",
        "rules": [
            "convert_index_to_field",
            "remove_nil_declaration",
            "remove_unused_if_branch",
            "remove_unused_while",
            "compute_expression",
        ]
    }

    try:
        with tempfile.NamedTemporaryFile(mode="w+", delete=False, suffix=".json") as tf:
            json.dump(config_data, tf)
            cfg_path = tf.name

        with tempfile.NamedTemporaryFile(mode="w+", delete=False, suffix=".lua") as sf:
            sf.write(cleaned)
            src_path = sf.name

        proc = await asyncio.create_subprocess_exec(
            darklua_bin, "process", src_path, src_path, "--config", cfg_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await asyncio.wait_for(proc.communicate(), timeout=15)
        if proc.returncode == 0 and os.path.isfile(src_path):
            with open(src_path, "r", encoding="utf-8", errors="replace") as rf:
                processed = rf.read()
            if processed and processed.strip():
                cleaned = processed

        try:
            os.remove(cfg_path)
            os.remove(src_path)
        except Exception:
            pass
    except Exception as exc:
        print(f"[pipeline] darklua reconstruct pass error: {exc}")

    # 2. Variable renaming pass (heuristic-based)
    if rename:
        try:
            from namer import renamecode
            renamed = renamecode(cleaned)
            if renamed and renamed.strip():
                cleaned = renamed
        except Exception as exc:
            print(f"[pipeline] rename pass error: {exc}")

    # 3. Lexer-based formatting pass
    try:
        formatted = format_lua(post_reconstruct_luau(cleaned))
        if formatted and formatted.strip():
            cleaned = formatted
    except Exception as exc:
        print(f"[pipeline] formatting pass error: {exc}")

    return with_hollow_header(cleaned)


async def deobfuscate_luraph_v15(script_content: str) -> Optional[str]:
    """
    Deobfuscates Luraph / Luraph V15 scripts using AST devirtualizer with fallback to behavior trace.
    Adapts without replacing the overall pipeline.
    """
    node_bin = _find_node()
    luraph_deob = os.path.join(VENDOR_DIR, "luraph_v15", "deob.js")
    if not node_bin or not os.path.isfile(luraph_deob):
        return None

    tmp_bin = _prepare_luau_bin()
    env = dict(os.environ)
    env["PATH"] = f"{tmp_bin}:{env.get('PATH', '')}"

    # Strip UTF-8 BOM and shebang if present
    cleaned_input = script_content
    if cleaned_input.startswith("\ufeff"):
        cleaned_input = cleaned_input[1:]
    if cleaned_input.startswith("#!"):
        first_nl = cleaned_input.find("\n")
        if first_nl != -1:
            cleaned_input = cleaned_input[first_nl + 1:]

    with tempfile.TemporaryDirectory() as tmpdir:
        in_file = os.path.join(tmpdir, "in.luau")
        out_file = os.path.join(tmpdir, "out.luau")
        with open(in_file, "w", encoding="utf-8", newline="\n") as f:
            f.write(cleaned_input)

        # 1. Try full devirtualization
        try:
            proc = await asyncio.create_subprocess_exec(
                node_bin, luraph_deob, in_file, "-o", out_file, "--timeout", "30",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=os.path.join(VENDOR_DIR, "luraph_v15"),
                env=env,
            )
            await asyncio.wait_for(proc.communicate(), timeout=45)
            if os.path.isfile(out_file) and os.path.getsize(out_file) > 10:
                with open(out_file, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                if content.strip():
                    return content
        except Exception as exc:
            print(f"[pipeline] luraph_v15 full devirt failed: {exc}")

        # 2. Fallback to --no-devirt behavior trace
        try:
            if os.path.isfile(out_file):
                os.remove(out_file)
            proc2 = await asyncio.create_subprocess_exec(
                node_bin, luraph_deob, in_file, "-o", out_file, "--no-devirt", "--timeout", "30",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=os.path.join(VENDOR_DIR, "luraph_v15"),
                env=env,
            )
            await asyncio.wait_for(proc2.communicate(), timeout=45)
            if os.path.isfile(out_file) and os.path.getsize(out_file) > 10:
                with open(out_file, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                if content.strip():
                    return content
        except Exception as exc:
            print(f"[pipeline] luraph_v15 no-devirt fallback failed: {exc}")

    return None


async def deobfuscate_moonsec_v2(script_content: str) -> Optional[str]:
    """Deobfuscates MoonSec V2 / IronBrew scripts using SixZens devirtualizer + unluac."""
    node_bin = _find_node()
    moonsec_v2_index = os.path.join(VENDOR_DIR, "moonsec_v2", "index.js")
    if not node_bin or not os.path.isfile(moonsec_v2_index):
        return None

    with tempfile.TemporaryDirectory() as tmpdir:
        in_file = os.path.join(tmpdir, "in.lua")
        out_luac = os.path.join(tmpdir, "out.luac")
        with open(in_file, "w", encoding="utf-8", newline="\n") as f:
            f.write(script_content)

        try:
            proc = await asyncio.create_subprocess_exec(
                node_bin, moonsec_v2_index, "-i", in_file, "-o", out_luac,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=os.path.join(VENDOR_DIR, "moonsec_v2"),
            )
            await asyncio.wait_for(proc.communicate(), timeout=30)
            if os.path.isfile(out_luac) and os.path.getsize(out_luac) > 0:
                decompiled = await decompile_bytecode_unluac(out_luac)
                if decompiled:
                    return decompiled
        except Exception as exc:
            print(f"[pipeline] moonsec_v2 failed: {exc}")
    return None


async def deobfuscate_moonsec_v3_prometheus(script_content: str) -> Optional[str]:
    """Deobfuscates MoonSec V3 and Prometheus using MoonsecDeobfuscator + unluac."""
    dotnet_bin = _find_dotnet()
    moonsec_dir = _prepare_moonsec_dir()
    moonsec_dll = os.path.join(moonsec_dir, "MoonsecDeobfuscator.dll")
    if not dotnet_bin or not os.path.isfile(moonsec_dll):
        return None

    with tempfile.TemporaryDirectory() as tmpdir:
        in_file = os.path.join(tmpdir, "in.lua")
        out_luac = os.path.join(tmpdir, "out.luac")
        out_dis = os.path.join(tmpdir, "out.dis.lua")
        with open(in_file, "w", encoding="utf-8", newline="\n") as f:
            f.write(script_content)

        env = dict(os.environ)
        # Add liblua54 runtime search paths
        env["LD_LIBRARY_PATH"] = f"{moonsec_dir}:{env.get('LD_LIBRARY_PATH', '')}"

        # 1. Try bytecode extraction (-dev) and decompilation
        try:
            proc = await asyncio.create_subprocess_exec(
                dotnet_bin, moonsec_dll, "-dev", "-i", in_file, "-o", out_luac,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=moonsec_dir,
                env=env,
            )
            await asyncio.wait_for(proc.communicate(), timeout=25)
            if os.path.isfile(out_luac) and os.path.getsize(out_luac) > 0:
                decompiled = await decompile_bytecode_unluac(out_luac)
                if decompiled:
                    return decompiled
        except Exception as exc:
            print(f"[pipeline] moonsec_v3 bytecode extraction failed: {exc}")

        # 2. Fallback to disassembly (-dis)
        try:
            proc2 = await asyncio.create_subprocess_exec(
                dotnet_bin, moonsec_dll, "-dis", "-i", in_file, "-o", out_dis,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=moonsec_dir,
                env=env,
            )
            await asyncio.wait_for(proc2.communicate(), timeout=25)
            if os.path.isfile(out_dis) and os.path.getsize(out_dis) > 0:
                with open(out_dis, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                if content.strip():
                    return content
        except Exception as exc:
            print(f"[pipeline] moonsec_v3 disassembly failed: {exc}")
    return None


async def try_specialized_deobfuscator(
    script_content: str,
    rename: bool = False,
) -> Tuple[bool, Optional[str], List[str], Optional[str]]:
    """
    Attempts specialized deobfuscation based on detected obfuscator.
    Returns (success, formatted_reconstructed_code, webhooks, note)
    """
    detected_quick = fingerprint.detect_obfuscation(script_content)
    detected_ml = classifier.detect_full(script_content)

    quick_name = detected_quick.get("name", "")
    ml_name = (detected_ml.get("top", {}).get("name") or "").lower()

    recovered = None
    engine_note = ""

    # 1. Luraph V15 / Luarmor
    is_luraph = (
        quick_name == "Luraph / Luarmor"
        or ml_name == "luraph"
        or bool(re.search(r"LURAPH|Luraph Script|LuraphVM|lura\.ph", script_content, re.IGNORECASE))
    )
    if is_luraph:
        recovered = await deobfuscate_luraph_v15(script_content)
        if recovered:
            engine_note = "Deobfuscated and reconstructed via Hollow Logger Luraph V15 Engine."

    # 2. MoonSec V2 (check explicit V2 signature)
    is_moonsec_v2 = (
        "Protected_by_MoonSecV2" in script_content
        or quick_name == "MoonSec V2"
        or (ml_name == "moonsec" and "..:::MoonSec::.." in script_content and "MoonSec V3" not in script_content)
    )
    if not recovered and is_moonsec_v2:
        recovered = await deobfuscate_moonsec_v2(script_content)
        if recovered:
            engine_note = "Deobfuscated and reconstructed via Hollow Logger MoonSec V2 Engine."

    # 3. Prometheus / PSU / MoonSec V3 (tupsutumppu deobfuscator)
    is_prometheus_or_v3 = (
        quick_name in ("MoonSec V3", "Prometheus / PSU")
        or ml_name in ("prometheus", "wearedevs", "moonsec")
        or "MoonSec V3" in script_content
        or "PROMETHEUS" in script_content
        or "PSU Obfuscator" in script_content
    )
    if not recovered and is_prometheus_or_v3:
        target_name = "Prometheus" if ("PROMETHEUS" in script_content or ml_name in ("prometheus", "wearedevs")) else "MoonSec V3"
        recovered = await deobfuscate_moonsec_v3_prometheus(script_content)
        if recovered:
            engine_note = f"Deobfuscated and reconstructed via Hollow Logger {target_name} Engine."

    if not recovered or not recovered.strip():
        return False, None, [], None

    # Reconstruct and format to make it clean, readable, and structured
    final_code = await reconstruct_and_format_lua(recovered, rename=rename)
    webhooks = find_webhooks(final_code)
    return True, final_code, webhooks, engine_note
