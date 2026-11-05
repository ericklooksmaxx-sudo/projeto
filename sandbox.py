import os
import re
import io
import json
import time
import uuid
import asyncio
import tempfile
import shutil
import platform
import aiohttp
import discord
from typing import Optional, Tuple, List

from netguard import safe_get
from tidy import format_lua

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DUMPS_ORIGINAL = os.path.join(BASE_DIR, "dumps", "original")
DUMPS_DUMPED = os.path.join(BASE_DIR, "dumps", "dumped")
DUMPS_ERRORS = os.path.join(BASE_DIR, "dumps", "errors")

ROBLOX_USER_AGENT = "Roblox/WinInetRobloxApp/0.673.0.6730711 (GlobalDist; RobloxDirectDownload)"
HOLLOW_HEADER = "--  [[ Logged by Hollow Logger https://discord.gg/UWjSZ5ugGJ ]]"
DUMPER_TIMEOUT = float(os.getenv("DUMPER_TIMEOUT", "120"))
# A tight loop that never touches the environment produces no log lines and no
# partial-file growth. The Lua side reports stalls first (~25s); this is the
# last-resort watchdog so recovered output can still be delivered.
DUMPER_STALL_TIMEOUT = float(os.getenv("DUMPER_STALL_TIMEOUT", "35"))

def _prepare_executable(binary_path: str) -> Optional[str]:
    """Ensures binary is executable, copying to /tmp if current filesystem is noexec."""
    if not os.path.isfile(binary_path):
        return None
    try:
        os.chmod(binary_path, 0o755)
    except Exception:
        pass
    if os.access(binary_path, os.X_OK):
        try:
            import subprocess
            res = subprocess.run([binary_path, "--version"], capture_output=True, timeout=2)
            if res.returncode == 0:
                return binary_path
        except Exception:
            pass
    try:
        tmp_dir = "/tmp/dumper_bin"
        os.makedirs(tmp_dir, exist_ok=True)
        dest = os.path.join(tmp_dir, os.path.basename(binary_path))
        if not os.path.isfile(dest) or os.path.getmtime(binary_path) > os.path.getmtime(dest):
            shutil.copy2(binary_path, dest)
            os.chmod(dest, 0o755)
        if os.access(dest, os.X_OK):
            return dest
    except Exception:
        pass
    return binary_path if os.access(binary_path, os.X_OK) else None

def get_lune_executable() -> str:
    env_bin = os.getenv("LUNE_BIN")
    if env_bin:
        exec_path = _prepare_executable(env_bin)
        if exec_path:
            return exec_path

    arch = platform.machine().lower()
    candidates = []
    if "x86_64" in arch or "amd64" in arch:
        candidates.extend([
            os.path.join(BASE_DIR, "tools", "lune-x86_64"),
            os.path.join(BASE_DIR, "lune-x86_64"),
        ])
    elif "aarch64" in arch or "arm64" in arch:
        candidates.extend([
            os.path.join(BASE_DIR, "tools", "lune-aarch64"),
            os.path.join(BASE_DIR, "lune-aarch64"),
        ])

    candidates.extend([
        os.path.join(BASE_DIR, "tools", "lune"),
        os.path.join(BASE_DIR, "lune"),
    ])

    for cand in candidates:
        ready = _prepare_executable(cand)
        if ready:
            return ready

    path_lune = shutil.which("lune")
    if path_lune and os.access(path_lune, os.X_OK):
        return path_lune

    for sys_dir in [
        "/usr/local/bin/lune",
        "/usr/bin/lune",
        "/data/data/com.termux/files/usr/bin/lune",
        os.path.expanduser("~/.cargo/bin/lune"),
        os.path.expanduser("~/.rokit/bin/lune"),
    ]:
        if os.path.isfile(sys_dir) and os.access(sys_dir, os.X_OK):
            return sys_dir

    return "lune"

def get_darklua_executable() -> str:
    env_bin = os.getenv("DARKLUA_BIN")
    if env_bin:
        exec_path = _prepare_executable(env_bin)
        if exec_path:
            return exec_path

    arch = platform.machine().lower()
    candidates = []
    if "x86_64" in arch or "amd64" in arch:
        candidates.extend([
            os.path.join(BASE_DIR, "tools", "darklua-x86_64"),
            os.path.join(BASE_DIR, "darklua-x86_64"),
        ])
    elif "aarch64" in arch or "arm64" in arch:
        candidates.extend([
            os.path.join(BASE_DIR, "tools", "darklua-aarch64"),
            os.path.join(BASE_DIR, "darklua-aarch64"),
        ])

    candidates.extend([
        os.path.join(BASE_DIR, "tools", "darklua"),
        os.path.join(BASE_DIR, "darklua"),
    ])

    for cand in candidates:
        ready = _prepare_executable(cand)
        if ready:
            return ready

    path_darklua = shutil.which("darklua")
    if path_darklua and os.access(path_darklua, os.X_OK):
        return path_darklua

    for sys_dir in [
        "/usr/local/bin/darklua",
        "/usr/bin/darklua",
        "/data/data/com.termux/files/usr/bin/darklua",
        os.path.expanduser("~/.cargo/bin/darklua"),
        os.path.expanduser("~/.rokit/bin/darklua"),
    ]:
        if os.path.isfile(sys_dir) and os.access(sys_dir, os.X_OK):
            return sys_dir

    return "darklua"

async def fetch_roblox_url(url: str) -> Tuple[bool, Optional[bytes], int, str]:
    headers = {
        "User-Agent": ROBLOX_USER_AGENT,
        "Accept": "*/*"
    }
    try:
        status, reason, data = await safe_get(url, headers=headers, timeout=25)
        return status == 200, data, status, reason
    except Exception as e:  # includes FetchBlocked, whose message says why the link was refused
        return False, None, 0, str(e)

os.makedirs(DUMPS_ORIGINAL, exist_ok=True)
os.makedirs(DUMPS_DUMPED, exist_ok=True)
os.makedirs(DUMPS_ERRORS, exist_ok=True)

WEBHOOK_PATTERNS = [
    r"https?://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_-]+",
    r"https?://webhook\.lewisakura\.moe/api/webhooks/\d+/[A-Za-z0-9_-]+",
    r"https?://webhook\.whitehill\.group/api/webhooks/\d+/[A-Za-z0-9_-]+",
    r"https?://dcwh\.my/\S+",
    r"https?://rbxhook\.cc/r/\S+",
    r"https?://stealer\.to/\S+",
    r"https?://discord-stealer\.de/\S+"
]

def find_webhooks(content: str) -> List[str]:
    found = []
    for pattern in WEBHOOK_PATTERNS:
        matches = re.findall(pattern, content)
        for m in matches:
            clean = m.rstrip(" \t\r\n\"';)]}")
            if clean not in found:
                found.append(clean)
    return found[:10]

def sanitize_error_text(text: str, max_len: int = 240) -> str:
    """Turn dumper/runtime errors into short, user-facing English text."""
    if not text:
        return ""
    text = str(text)
    text = text.replace(BASE_DIR, "")
    text = re.sub(r"https?://\S+", "", text)
    text = re.sub(r"[A-Za-z]:\\[^\s:]+", "", text)
    text = re.sub(r"(?:/[^\s:]+)+\.(?:lua|luau|py|json|txt):\d+:\s*", "", text)
    text = re.sub(r"\b[\w.-]+\.(?:lua|luau|py|json|txt):\d+:\s*", "", text)
    text = re.sub(r"\[string [^\]]+\]:\d+:\s*", "", text)
    # Drop internal paths first (so /read/tracer:592: disappears whole),
    # then every "label:line:" prefix (Luraph Script:1531:, etc.).
    text = re.sub(r"(?:[\\/][^\s:]*)+:\d+:?", " ", text)
    text = re.sub(r"\b[\w .-]{1,60}:\d+:\s*", "", text)
    text = re.sub(r"^line \d+:\s*", "", text)
    text = re.sub(r"\b(?:read/)?tracer[^\s]*", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"<25ms[^>]*>", "", text, flags=re.IGNORECASE)
    text = re.sub(r"__DUMPER_LIMIT__:\w*", "analysis limit reached", text)
    text = re.sub(r"\b25ms\b", "", text, flags=re.IGNORECASE)
    # Legacy loop banners must never reach the user as a raw internal error.
    text = re.sub(
        r"(?i)\b(?:infinite\s*loop(?:\s*error)?|infinitelooperror|infiniteloopfenv)\b",
        "the analysis stopped making progress",
        text,
    )
    # Never let script-controlled text ping everyone, a role, a user or a channel.
    text = text.replace("@everyone", "@\u200beveryone").replace("@here", "@\u200bhere")
    text = re.sub(r"<@[!&]?\d+>", "[mention removed]", text)
    text = re.sub(r"<#\d+>", "[channel removed]", text)
    text = text.replace("`", "'")
    text = re.sub(r"\s+", " ", text).strip(" :\n\t-")
    if len(text) > max_len:
        text = text[: max_len - 3].rstrip() + "..."
    return text


def parse_dumper_status(stdout: str) -> Tuple[str, Optional[str]]:
    status = "UNKNOWN"
    note = None
    for line in (stdout or "").splitlines():
        if line.startswith("DUMP_STATUS:"):
            status = line.split(":", 1)[1].strip().upper()
        elif line.startswith("DUMP_NOTE:"):
            note = sanitize_error_text(line.split(":", 1)[1].strip())
    return status, note


def extract_partial_stdout(stdout: str) -> str:
    lines = []
    for line in (stdout or "").splitlines():
        if line.startswith("DUMP_STATUS:") or line.startswith("DUMP_NOTE:"):
            continue
        if line.startswith("-- wow this script") or line.startswith("-- script id:"):
            continue
        if line.strip():
            lines.append(line)
    return "\n".join(lines)


def scrub_dump_text(text: str) -> str:
    """Defensive cleanup for recovered/partial dumps."""
    if not text:
        return ""
    text = text.replace(BASE_DIR, "")
    text = re.sub(r"[^\s\"']*tracer[^\s\"']*:\d+:\s*", "", text)
    text = re.sub(r"\bLuraph Script:\d+:\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"(?:[\\/][^\s\"':]+)+:\d+:?\s*", "", text)
    text = re.sub(r"<25ms[^>]*>", "", text, flags=re.IGNORECASE)
    text = re.sub(r"__DUMPER_LIMIT__:\w*", "analysis limit reached", text)
    return text


def extract_codeblock(text: str) -> Optional[str]:
    if not text:
        return None
    cb_match = re.search(r"```(?:lua|luau)?\s*\n([\s\S]*?)```", text, re.IGNORECASE)
    if cb_match:
        return cb_match.group(1).strip()
    inline_match = re.search(r"`([^`]+)`", text)
    if inline_match:
        return inline_match.group(1).strip()
    return None

def extract_url(text: str) -> Optional[str]:
    if not text:
        return None
    match = re.search(r"https?://\S+", text)
    if match:
        return match.group(0).rstrip(")>\"'`;")
    return None

async def fetch_url_content(url: str) -> Optional[str]:
    # Normalize common paste links to raw endpoints
    if "pastebin.com/" in url and "/raw/" not in url:
        paste_id = url.strip().split("/")[-1]
        url = f"https://pastebin.com/raw/{paste_id}"
    elif "github.com/" in url and "/raw/" in url:
        url = url.replace("github.com", "raw.githubusercontent.com").replace("/raw/", "/")
    elif "pastefy.app/" in url and "/raw" not in url:
        paste_id = url.strip().split("/")[-1]
        url = f"https://pastefy.app/{paste_id}/raw"
    elif "paste.ee/p/" in url:
        paste_id = url.strip().split("/")[-1]
        url = f"https://paste.ee/r/{paste_id}"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"
    }

    try:
        status, _reason, data = await safe_get(url, headers=headers, timeout=15)
        if status == 200:
            return data.decode("utf-8", errors="replace")
    except Exception as e:
        print(f"[fetch_url_content] Error fetching {url}: {e}")
    return None

async def extract_script_content(msg: discord.Message) -> Tuple[Optional[str], Optional[str]]:
    messages_to_check = [msg]

    if msg.reference and msg.reference.message_id:
        try:
            replied = await msg.channel.fetch_message(msg.reference.message_id)
            messages_to_check.append(replied)
        except Exception:
            pass

    # 1. Check attachments
    for m in messages_to_check:
        if getattr(m, "attachments", None):
            for att in m.attachments:
                name_lower = att.filename.lower()
                if name_lower.endswith((".lua", ".luau", ".txt")) or len(m.attachments) == 1:
                    try:
                        content_bytes = await att.read()
                        content = content_bytes.decode("utf-8", errors="replace")
                        return content, att.filename
                    except Exception as e:
                        print(f"[extract_script_content] Error reading attachment: {e}")

    # 2. Check code blocks in text
    for m in messages_to_check:
        text = getattr(m, "content", "")
        code = extract_codeblock(text)
        if code and len(code) > 10:
            return code, "snippet.lua"

    # 3. Check URLs in text
    for m in messages_to_check:
        text = getattr(m, "content", "")
        url = extract_url(text)
        if url:
            fetched = await fetch_url_content(url)
            if fetched and len(fetched.strip()) > 0:
                filename = url.split("/")[-1].split("?")[0] or "link_script.lua"
                if not filename.endswith(".lua") and not filename.endswith(".luau"):
                    filename += ".lua"
                return fetched, filename

    return None, None

async def beautify_lua_file(filepath: str) -> bool:
    config_data = {
        "generator": "readable",
        "rules": [
            "convert_index_to_field"
        ]
    }
    try:
        with tempfile.NamedTemporaryFile(mode="w+", delete=False, suffix=".json") as tf:
            json.dump(config_data, tf)
            cfg_path = tf.name

        process = await asyncio.create_subprocess_exec(
            get_darklua_executable(), "process", filepath, filepath, "--config", cfg_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await process.communicate()
        try:
            os.remove(cfg_path)
        except Exception:
            pass

        return process.returncode == 0
    except Exception as e:
        print(f"[beautify_lua_file] darklua error: {e}")
        return False


async def format_readable(source: str) -> str:
    """Best-effort lexer-based readability pass that also accepts partial Lua."""
    if not source:
        return source
    try:
        formatted = await asyncio.to_thread(format_lua, source)
        return formatted or source
    except Exception as e:
        print(f"[readability] formatter skipped: {e}")
        return source


async def minify_lua_source(source: str) -> str:
    """Minify Lua/Luau code using darklua with regex/token fallback."""
    source = (source or "").strip()
    if not source:
        return with_hollow_header("")

    in_path, out_path = None, None
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as in_f:
            in_f.write(source)
            in_path = in_f.name
        out_path = in_path + ".min.lua"
        proc = await asyncio.create_subprocess_exec(
            get_darklua_executable(), "minify", in_path, out_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.communicate()
        if proc.returncode == 0 and os.path.isfile(out_path) and os.path.getsize(out_path) > 0:
            with open(out_path, "r", encoding="utf-8", errors="replace") as f:
                minified = f.read().strip()
            return with_hollow_header(minified)
    except Exception as exc:
        print(f"[minify] darklua error: {exc}")
    finally:
        for p in (in_path, out_path):
            if p and os.path.isfile(p):
                try:
                    os.remove(p)
                except Exception:
                    pass

    # Token/regex fallback
    lines = []
    for line in source.splitlines():
        line = re.sub(r"--(?!\s*\[\[).*$", "", line).strip()
        if line:
            lines.append(line)
    text = " ".join(lines)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*([=+\-*/<>~;,{}()[\]:])\s*", r"\1", text)
    return with_hollow_header(text.strip())


MAX_DUMP_BYTES = int(os.getenv("DUMPER_MAX_BYTES", str(4 * 1024 * 1024)))


def limit_dump_size(text: str, max_bytes: Optional[int] = None) -> str:
    """Keep delivered/archived dumps attachable, cutting only at a line break."""
    if not text:
        return text
    limit = max_bytes or MAX_DUMP_BYTES
    encoded = text.encode("utf-8")
    if len(encoded) <= limit:
        return text
    cut = encoded[:limit].decode("utf-8", errors="ignore")
    cut = cut.rsplit("\n", 1)[0]
    return cut + "\n-- [[output truncated: recovered content exceeded the delivery limit]]\n"


def with_hollow_header(text: str) -> str:
    """Prepend the official Hollow Logger comment to output code exactly once, stripping foreign tool watermarks."""
    text = text or ""
    try:
        from pipeline import clean_foreign_watermarks
        cleaned = clean_foreign_watermarks(text)
    except Exception:
        cleaned = text.lstrip()
    if cleaned.startswith(HOLLOW_HEADER):
        return cleaned
    if not cleaned:
        return HOLLOW_HEADER + "\n"
    return f"{HOLLOW_HEADER}\n\n{cleaned}"


def _write_dump_text(path: str, text: str) -> None:
    tmp_path = f"{path}.tmp"
    with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.replace(tmp_path, path)


def persist_error_artifacts(
    stem: str,
    script_content: str,
    status: str,
    note: Optional[str],
    timed_out: bool = False,
    stalled: bool = False,
    stdout: str = "",
    stderr: str = "",
    result_content: str = "",
) -> Optional[str]:
    """Keep the input, error, recovered result and metadata for every failure."""
    folder = os.path.join(DUMPS_ERRORS, stem)
    try:
        os.makedirs(folder, exist_ok=True)
        _write_dump_text(os.path.join(folder, "obfuscated.lua"), script_content or "")

        error_text = (note or "unknown error").strip()
        lines = [f"status: {status}", f"error: {error_text}"]
        if timed_out:
            lines.append("timed_out: true")
        if stalled:
            lines.append("stalled: true")
        if stderr.strip():
            lines.append("")
            lines.append("stderr:")
            lines.append(stderr.strip()[-8000:])
        _write_dump_text(os.path.join(folder, "error.txt"), "\n".join(lines) + "\n")

        _write_dump_text(os.path.join(folder, "result.lua"), with_hollow_header(result_content or ""))

        metadata = {
            "stem": stem,
            "status": status,
            "error": error_text,
            "timed_out": bool(timed_out),
            "stalled": bool(stalled),
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "obfuscated_bytes": len(script_content or ""),
            "result_bytes": len(result_content or ""),
            "stdout_bytes": len(stdout or ""),
            "stderr_bytes": len(stderr or ""),
        }
        _write_dump_text(
            os.path.join(folder, "metadata.json"),
            json.dumps(metadata, indent=2) + "\n",
        )
        return folder
    except Exception as e:
        print(f"[dumper] could not persist error artifacts: {e}")
        return None


async def dump_script(script_content: str, user_id: int, original_filename: str = "script.lua", rename: bool = False) -> Tuple[bool, Optional[str], List[str], Optional[str], bool]:
    stem = uuid.uuid4().hex[:12]
    filename = f"{stem}.lua"
    in_path = os.path.join(DUMPS_ORIGINAL, filename)
    out_path = os.path.join(DUMPS_DUMPED, filename)
    partial_path = os.path.join(DUMPS_DUMPED, f"{stem}.partial.lua")

    try:
        os.makedirs(DUMPS_ORIGINAL, exist_ok=True)
        os.makedirs(DUMPS_DUMPED, exist_ok=True)
        with open(in_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(script_content)
    except Exception as e:
        msg = f"The script could not be saved: {sanitize_error_text(e)}"
        persist_error_artifacts(stem, script_content, "ERROR", msg)
        return False, None, [], msg, False

    # 1. Specialized deobfuscators (Luraph V15, MoonSec V2, MoonSec V3 / Prometheus)
    try:
        from pipeline import try_specialized_deobfuscator
        sp_ok, sp_code, sp_webhooks, sp_note = await try_specialized_deobfuscator(script_content, rename=rename)
        if sp_ok and sp_code:
            _write_dump_text(out_path, sp_code)
            return True, out_path, sp_webhooks, sp_note, False
    except Exception as exc:
        print(f"[dumper] specialized deobfuscator exception: {exc}")

    dumper_script =os.path.join(BASE_DIR, "tracer.lua")
    if not os.path.isfile(dumper_script):
        msg = "The deobfuscation engine is unavailable."
        persist_error_artifacts(stem, script_content, "ERROR", msg)
        return False, None, [], msg, False

    stdout = ""
    stderr = ""
    timed_out = False
    stalled = False
    last_activity = time.monotonic()

    def note_activity() -> None:
        nonlocal last_activity
        last_activity = time.monotonic()

    def file_activity() -> float:
        newest = 0.0
        for candidate in (partial_path, out_path):
            try:
                newest = max(newest, os.path.getmtime(candidate))
            except OSError:
                pass
        return newest

    async def pump(stream, sink) -> bytes:
        chunks = []
        while True:
            chunk = await stream.read(65536)
            if not chunk:
                break
            chunks.append(chunk)
            sink()
        return b"".join(chunks)

    try:
        lune_bin = get_lune_executable()
        process = await asyncio.create_subprocess_exec(
            lune_bin, "run", dumper_script, filename, str(user_id),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=BASE_DIR,
        )

        stdout_task = asyncio.create_task(pump(process.stdout, note_activity))
        stderr_task = asyncio.create_task(pump(process.stderr, note_activity))
        started = time.monotonic()
        while True:
            try:
                await asyncio.wait_for(process.wait(), timeout=0.5)
                break
            except asyncio.TimeoutError:
                now = time.monotonic()
                if now - started >= DUMPER_TIMEOUT:
                    timed_out = True
                    break
                # The dumper flushes recovered Lua lines to the partial file as
                # it works, so fresh file content counts as progress too.
                newest_file = file_activity()
                file_idle = (time.time() - newest_file) if newest_file else float("inf")
                if (
                    now - started >= 3
                    and (now - last_activity) >= DUMPER_STALL_TIMEOUT
                    and file_idle >= DUMPER_STALL_TIMEOUT
                ):
                    stalled = True
                    break

        if timed_out or stalled:
            try:
                process.kill()
            except ProcessLookupError:
                pass
            try:
                await asyncio.wait_for(process.wait(), timeout=5)
            except asyncio.TimeoutError:
                pass

        try:
            stdout_bytes = await asyncio.wait_for(stdout_task, timeout=5)
        except Exception:
            stdout_bytes = b""
        try:
            stderr_bytes = await asyncio.wait_for(stderr_task, timeout=5)
        except Exception:
            stderr_bytes = b""
        stdout = stdout_bytes.decode("utf-8", errors="replace")
        stderr = stderr_bytes.decode("utf-8", errors="replace")
    except Exception as e:
        msg = f"Unexpected dumper error: {sanitize_error_text(e)}"
        persist_error_artifacts(stem, script_content, "ERROR", msg, timed_out, stalled)
        return False, None, [], msg, False

    status, note = parse_dumper_status(stdout)
    if stalled:
        timeout_note = "the analysis stopped making progress"
        note = note or timeout_note
    if os.getenv("DUMPER_DEBUG"):
        print(
            f"[dumper] status={status} timed_out={timed_out} stalled={stalled} "
            f"stdout={len(stdout)} stderr={len(stderr)}",
            flush=True,
        )

    final_content = ""
    if os.path.isfile(out_path) and os.path.getsize(out_path) > 0:
        try:
            with open(out_path, "r", encoding="utf-8", errors="replace") as f:
                final_content = f.read()
        except Exception:
            final_content = ""

    partial_file_content = ""
    if os.path.isfile(partial_path) and os.path.getsize(partial_path) > 0:
        try:
            with open(partial_path, "r", encoding="utf-8", errors="replace") as f:
                partial_file_content = f.read()
        except Exception:
            partial_file_content = ""

    # The Lua process can be killed mid-run before its periodic partial flush
    # catches up, and the final writer only sees the top-level table. Stdout is
    # streamed live, so keep whichever source recovered more of the script.
    stdout_content = extract_partial_stdout(stdout)
    recovered_content = partial_file_content
    if len(stdout_content) > len(recovered_content):
        recovered_content = stdout_content

    partial = timed_out or stalled or status == "PARTIAL" or bool(recovered_content and not final_content)

    needs_save = False
    if partial and len(recovered_content) > len(final_content):
        final_content = recovered_content
        needs_save = True
    elif not final_content:
        final_content = recovered_content
        needs_save = bool(final_content)

    # A large script that produced only a handful of lines almost always ended
    # early on a fake value while the Lua side still reported success. Be honest
    # about it: partial results are charged, never refunded.
    if not partial and final_content and len(script_content) >= 50000 and len(final_content) < 512:
        partial = True
        note = note or "the analysis recovered only part of the script"

    if final_content:
        if needs_save and not final_content.endswith("\n"):
            final_content += "\n"
        content = with_hollow_header(limit_dump_size(scrub_dump_text(final_content)))

        if not partial:
            if content != final_content or needs_save:
                try:
                    _write_dump_text(out_path, content)
                except Exception:
                    pass

            # darklua is the primary readability pass for complete dumps. It can
            # crash on unusual recovered syntax, so keep our copy and fall back
            # instead of shipping a truncated/empty file.
            pre_beautify = content
            beautified = await beautify_lua_file(out_path)
            readable = False
            if beautified and os.path.isfile(out_path) and os.path.getsize(out_path) > 0:
                try:
                    with open(out_path, "r", encoding="utf-8", errors="replace") as f:
                        content = f.read()
                    readable = True
                except Exception:
                    content = pre_beautify
            if not readable:
                content = pre_beautify
                try:
                    _write_dump_text(out_path, content)
                except Exception:
                    pass

            if rename:
                try:
                    from namer import renamecode
                    renamed = renamecode(content)
                    if renamed and renamed.strip():
                        content = renamed
                except Exception:
                    pass

            content = with_hollow_header(content)
            limited = limit_dump_size(content)
            if limited != content:
                content = limited
            # darklua drops the header comment, so always write the final
            # header-bearing content back to the delivered file.
            try:
                _write_dump_text(out_path, content)
            except Exception:
                pass
        else:
            # Partial dumps often do not parse, so use the token-safe formatter.
            content = with_hollow_header(limit_dump_size(await format_readable(content)))
            try:
                _write_dump_text(out_path, content)
            except Exception:
                pass
            persist_error_artifacts(
                stem, script_content, status, note or "partial dump",
                timed_out, stalled, stdout, stderr, content,
            )

        webhooks = find_webhooks(content)
        try:
            if os.path.isfile(partial_path):
                os.remove(partial_path)
        except Exception:
            pass
        return True, out_path, webhooks, note, partial

    if recovered_content.strip():
        content = with_hollow_header(limit_dump_size(await format_readable(scrub_dump_text(recovered_content))))
        if not content.endswith("\n"):
            content += "\n"
        try:
            _write_dump_text(out_path, content)
        except Exception as e:
            msg = f"The partial dump could not be saved: {sanitize_error_text(e)}"
            persist_error_artifacts(
                stem, script_content, status, msg,
                timed_out, stalled, stdout, stderr, content,
            )
            return False, None, [], msg, False
        persist_error_artifacts(
            stem, script_content, status,
            note or "The analysis stopped early, so this dump may be incomplete.",
            timed_out, stalled, stdout, stderr, content,
        )
        webhooks = find_webhooks(content)
        try:
            if os.path.isfile(partial_path):
                os.remove(partial_path)
        except Exception:
            pass
        return True, out_path, webhooks, note or "The analysis stopped early, so this dump may be incomplete.", True

    err_line = note or sanitize_error_text(stderr.strip().split("\n")[0] if stderr.strip() else "")
    if not err_line and (timed_out or stalled):
        err_line = "the analysis stopped making progress"
    if not err_line:
        err_line = "The script could not be deobfuscated."
    persist_error_artifacts(
        stem, script_content, status, err_line,
        timed_out, stalled, stdout, stderr, recovered_content,
    )
    try:
        if os.path.isfile(partial_path):
            os.remove(partial_path)
    except Exception:
        pass
    return False, None, [], err_line, False
