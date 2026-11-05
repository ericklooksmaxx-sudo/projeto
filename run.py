import os
import re
import io
import sys
import time
import math
import json
import random
import asyncio
import datetime
import tempfile
import aiohttp
import aiohttp.web
import discord
from typing import Optional, Tuple
from urllib.parse import quote
from dotenv import load_dotenv

load_dotenv()

from wallet import credits_manager
from passes import key_manager
from guard import antiraid_manager
from draws import giveaway_manager, warnings_manager
import classifier
import assistant
import unlink
from tidy import format_lua
from namer import renamecode
from pipeline import reconstruct_and_format_lua
from sandbox import (
    dump_script,
    extract_script_content,
    extract_codeblock,
    fetch_roblox_url,
    fetch_url_content,
    format_readable,
    limit_dump_size,
    minify_lua_source,
    with_hollow_header,
)

# ============================================================
# CONFIG
# ============================================================
DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", "")
PREFIX = os.getenv("PREFIX", ".")

OWNER_ROLE_ID = int(os.getenv("OWNER_ROLE_ID", "1564136124874621058"))
CEO_ROLE_ID = int(os.getenv("CEO_ROLE_ID", "1564136354571362424"))
ADMIN_ROLE_ID = int(os.getenv("ADMIN_ROLE_ID", "1564136202758524930"))
STAFF_ROLE_ID = int(os.getenv("STAFF_ROLE_ID", "1564136444610617364"))
MEMBER_ROLE_ID = int(os.getenv("MEMBER_ROLE_ID", "1564136757761679511"))
PREMIUM_ROLE_ID = int(os.getenv("PREMIUM_ROLE_ID", "1564136656729153647"))

DAILY_REGULAR_CREDITS = int(os.getenv("DAILY_REGULAR_CREDITS", "5"))
DAILY_STAFF_CREDITS = int(os.getenv("DAILY_STAFF_CREDITS", "25"))
DAILY_ADMIN_CREDITS = int(os.getenv("DAILY_ADMIN_CREDITS", "50"))
DAILY_PREMIUM_CAP = int(os.getenv("DAILY_PREMIUM_CAP", "100"))
COMMAND_COST = int(os.getenv("COMMAND_COST", "1"))

if not DISCORD_TOKEN:
    print("[ERROR] DISCORD_TOKEN not found in .env file!")
    sys.exit(1)

EMBED_MAIN = 0x5865F2
EMBED_OK = 0x2ECC71
EMBED_ERR = 0xE74C3C
EMBED_WARN = 0xE67E22
EMBED_INFO = 0x3498DB

INVITE_PATTERN = re.compile(
    r"(discord\.(gg|io|me|li)|discord(?:app)?\.com/invite|dsc\.gg|invite\.gg)/\S+",
    re.IGNORECASE,
)
USER_ID_PATTERN = re.compile(r"^(?:<@!?(\d+)>|(\d+))$")

FREE_COMMANDS = {
    "help", "h", "cmds", "commands",          # help menu
    "daily",                                   # daily credits
    "balance", "bal", "credits",               # balance check
    "ping",                                    # latency
    "redeem",                                  # key redemption
    "ai",                                      # AI chat (tools charge separately)
    "userinfo", "serverinfo", "avatar",        # info
    "poll", "say", "embed",                    # utility
}

# Minimum permission level per command (default 0 = everyone / paid)
COMMAND_LEVELS = {
    # Staff+ (1)
    "mute": 1, "unmute": 1, "warn": 1, "warnings": 1, "clear": 1, "purge": 1,
    # Admin+ (2)
    "kick": 2, "ban": 2, "clearwarnings": 2, "slowmode": 2, "lock": 2, "unlock": 2,
    "gstart": 2, "greroll": 2, "announce": 2, "antiraid": 2,
    "genkey": 2, "revoke": 2, "keys": 2,
    # CEO+ (3)
    "givecredits": 3, "addcredits": 3, "givecredit": 3, "addcredit": 3,
}

GUILD_ONLY_COMMANDS = {
    "ban", "kick", "mute", "unmute", "warn", "warnings", "clearwarnings",
    "clear", "purge", "slowmode", "lock", "unlock", "gstart", "greroll",
    "announce", "antiraid", "serverinfo", "userinfo", "avatar",
    "say", "embed", "poll",
}

ALL_BOT_COMMANDS = {
    # Help
    "help", "h", "cmds", "commands",
    # Economy / Keys
    "daily", "balance", "bal", "credits", "redeem", "genkey", "keys", "revoke",
    "givecredits", "addcredits", "givecredit", "addcredit",
    # AI / Image
    "ai", "imagine", "img", "image",
    # Dumper / Deobfuscator
    "l", "dump", "deobf", "reconstruct", "rebuild",
    # Detection
    "detect", "identify",
    # Bypass
    "bypass", "byp", "dlv", "unshorten",
    # Fetch
    "get", "fetch", "getraw",
    # Beautify / Format
    "beautify", "format", "pretty", "fmt",
    # Minify
    "minify", "mini", "compress", "min",
    # Moderation
    "mute", "unmute", "warn", "warnings", "clearwarnings", "clear", "purge",
    "kick", "ban", "slowmode", "lock", "unlock",
    # Giveaways & Anti-raid
    "gstart", "greroll", "announce", "antiraid",
    # Utility
    "userinfo", "serverinfo", "avatar", "say", "embed", "poll", "ping",
}

MAX_TIMEOUT = 2419200  # 28 days (Discord limit)


START_TIME = time.time()


async def start_healthcheck_server():
    """Tiny health-check endpoint (GET / and GET /health) for hosting platforms and uptime pings."""
    enable_web = os.getenv("ENABLE_WEB_SERVER", "true").lower() in ("true", "1", "yes")
    if not enable_web:
        return

    port = int(os.getenv("PORT", "8080"))
    host = os.getenv("HOST", "0.0.0.0")

    app = aiohttp.web.Application()

    async def health_handler(request):
        bot_name = client.user.name if client.user else "Starting..."
        return aiohttp.web.json_response({
            "status": "online",
            "bot": bot_name,
            "prefix": PREFIX,
            "guilds": len(client.guilds) if client.user else 0,
            "uptime_seconds": round(time.time() - START_TIME, 1),
        })

    app.router.add_get("/", health_handler)
    app.router.add_get("/health", health_handler)

    runner = aiohttp.web.AppRunner(app)
    await runner.setup()
    site = aiohttp.web.TCPSite(runner, host, port)
    try:
        await site.start()
        print(f"[OK] Health-check server listening on {host}:{port}")
    except Exception as e:
        print(f"[WARN] Health-check server could not bind {host}:{port}: {e}")


# ============================================================
# CLIENT
# ============================================================
class HollowClient(discord.Client):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    async def setup_hook(self):
        self.loop.create_task(start_healthcheck_server())
        self.loop.create_task(giveaway_checker_loop())


intents = discord.Intents.default()
intents.message_content = True
intents.members = True

client = HollowClient(intents=intents)
ai_manager_client = assistant.AIManager()


# ============================================================
# HELPERS
# ============================================================
def format_time_remaining(seconds: int) -> str:
    hours, remainder = divmod(int(seconds), 3600)
    minutes, secs = divmod(remainder, 60)
    parts = []
    if hours > 0:
        parts.append(f"{hours}h")
    if minutes > 0:
        parts.append(f"{minutes}m")
    if secs > 0 or not parts:
        parts.append(f"{secs}s")
    return " ".join(parts)


def get_member_role_ids(user) -> set:
    """Returns role IDs of the user, even if the command was used in DMs."""
    if isinstance(user, discord.Member) and user.guild:
        return {role.id for role in user.roles}
    if hasattr(user, "roles") and user.roles:
        return {getattr(role, "id", role) for role in user.roles}
    ids = set()
    for guild in client.guilds:
        member = guild.get_member(user.id)
        if member:
            ids |= {role.id for role in member.roles}
    return ids


def get_permission_level(user) -> int:
    ids = get_member_role_ids(user)
    if OWNER_ROLE_ID in ids:
        return 4
    if CEO_ROLE_ID in ids:
        return 3
    if ADMIN_ROLE_ID in ids:
        return 2
    if STAFF_ROLE_ID in ids:
        return 1
    return 0


def is_owner_user(user) -> bool:
    return OWNER_ROLE_ID in get_member_role_ids(user)


def is_infinite_credits_user(user) -> bool:
    ids = get_member_role_ids(user)
    return get_permission_level(user) >= 3 or OWNER_ROLE_ID in ids or CEO_ROLE_ID in ids


def is_premium_user(user) -> bool:
    """Being Premium requires having the official Premium role (1564136656729153647)."""
    return PREMIUM_ROLE_ID in get_member_role_ids(user)


def has_min_level(user, level: int) -> bool:
    return get_permission_level(user) >= level


def credits_display(user) -> str:
    if is_infinite_credits_user(user):
        return "⭐ `Unlimited (CEO / Owner)`"
    return f"💳 `{credits_manager.get_credits(user.id)} credits`"


def build_insufficient_credits_embed() -> discord.Embed:
    embed = discord.Embed(
        title="❌ Insufficient Credits",
        description=(
            f"You need **{COMMAND_COST} credit**. "
            f"Use `{PREFIX}daily` for free credits."
        ),
        color=EMBED_ERR,
    )
    return embed


def build_usage_embed(title: str, usage: str) -> discord.Embed:
    return discord.Embed(
        title=f"❌ Invalid Usage — {title}",
        description=f"**Correct usage:** `{usage}`",
        color=EMBED_WARN,
    )


class OpenLinkView(discord.ui.View):
    def __init__(self, target_url: str):
        super().__init__(timeout=None)
        self.add_item(
            discord.ui.Button(
                label="Open Link",
                url=target_url,
                style=discord.ButtonStyle.link,
                emoji="🔗",
            )
        )


class KeyView(discord.ui.View):
    def __init__(self, key: str):
        super().__init__(timeout=None)
        self.key = key.strip()

    @discord.ui.button(label="Get Key", style=discord.ButtonStyle.primary, emoji="🔑")
    async def show_key(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.send_message(
            content=f"🔑 **Your Key:**\n```{self.key}```",
            ephemeral=True
        )


# ============================================================
# AI / FORMAT / BYPASS HELPERS
# ============================================================
AI_PAID_COMMANDS = {"l", "detect", "fetch", "bypass", "byp", "dlv", "unshorten", "format", "beautify", "minify"}
AI_MAX_ATTACHMENT_BYTES = 8 * 1024 * 1024


def _safe_filename(name, fallback: str = "hollow_output.lua") -> str:
    name = os.path.basename(str(name or "")).strip()
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
    if not name or name in (".", ".."):
        return fallback
    return name[:120]


def _first_url(text: str) -> Optional[str]:
    return unlink.normalize_input_url(text)


def _write_temp_bytes(data: bytes, suffix: str) -> str:
    fd, path = tempfile.mkstemp(prefix="hollow_", suffix=suffix)
    with os.fdopen(fd, "wb") as handle:
        handle.write(data)
    return path


def _cleanup_files(paths) -> None:
    for path in paths or []:
        try:
            if path and os.path.isfile(path):
                os.remove(path)
        except Exception:
            pass


async def _extract_ai_source(message: discord.Message):
    """Attachment/code-block only. Never prefetches URLs, so bypass chats stay cheap."""
    messages_to_check = [message]
    if message.reference and message.reference.message_id:
        try:
            replied = await message.channel.fetch_message(message.reference.message_id)
            messages_to_check.append(replied)
        except Exception:
            pass

    for item in messages_to_check:
        if getattr(item, "attachments", None):
            for attachment in item.attachments:
                name = attachment.filename.lower()
                if name.endswith((".lua", ".luau", ".txt")) or len(item.attachments) == 1:
                    try:
                        data = await attachment.read()
                        return data.decode("utf-8", errors="replace"), attachment.filename
                    except Exception:
                        pass

    for item in messages_to_check:
        code = extract_codeblock(getattr(item, "content", ""))
        if code and len(code) > 10:
            return code, "snippet.lua"

    return None, None


async def _beautify_source(code: str, rename: bool = False) -> str:
    """Readable version of `code`: the full reconstruction pass first, the plain beautifier as the fallback."""
    try:
        formatted = await reconstruct_and_format_lua(code, rename=rename)
    except Exception as exc:
        print(f"[format] reconstruction skipped: {type(exc).__name__}: {exc}")
        formatted = ""
    if formatted and formatted.strip():
        return with_hollow_header(limit_dump_size(formatted))

    formatted = await format_readable(code)
    if rename:
        try:
            formatted = await asyncio.to_thread(renamecode, formatted)
        except Exception as exc:
            print(f"[format] rename skipped: {type(exc).__name__}: {exc}")
    return with_hollow_header(limit_dump_size(formatted or code))


def _ai_charge(author, command: str):
    """Return (allowed, charged). CEO, owners and free commands are never charged."""
    if command not in AI_PAID_COMMANDS:
        return True, False
    if is_infinite_credits_user(author):
        return True, False
    if credits_manager.use_credit(author.id, COMMAND_COST):
        return True, True
    return False, False


def _ai_refund(author, charged: bool) -> None:
    if charged:
        credits_manager.refund_credit(author.id, COMMAND_COST)


async def _ai_tool_format_lua(args, context):
    code = args.get("code") if isinstance(args.get("code"), str) else ""
    if not code:
        code = context.get("source_code") or ""
    if not code.strip():
        return {"content": "I need the Lua/Luau code first. Attach a file or paste a code block."}

    author = context.get("author")
    allowed, charged = _ai_charge(author, "format")
    if not allowed:
        return {"content": f"You do not have enough credits for formatting. Use `{PREFIX}daily` for free credits."}

    rename = args.get("rename") is True
    formatted = await _beautify_source(code, rename=rename)
    if not formatted or not formatted.strip():
        _ai_refund(author, charged)
        return {"content": "Could not format the Lua code, so the credit was refunded."}

    path = _write_temp_bytes(formatted.encode("utf-8"), ".lua")
    filename = _safe_filename(context.get("source_filename") or "formatted.lua", "formatted.lua")
    if not filename.lower().endswith((".lua", ".luau", ".txt")):
        filename += ".lua"
    return {
        "content": "Formatted Lua code attached.",
        "_attachments": [{"path": path, "filename": filename}],
        "_cleanup": [path],
    }


IMAGE_SAFETY_PATTERNS = [
    r"\b(?:nude|nudity|naked|porn|nsfw|hentai|ecchi|lewd|boobs|breasts|vagina|penis|dick|cock|pussy|erotic|sex|anal|fetish|strip|stripper|bikini|lingerie|underwear|topless|bottomless)\b",
    r"\b(?:gore|gory|blood|bloody|bloodshed|beheading|decapitat\w*|dismember\w*|mutilat\w*|torture|suicide|self-harm|hanging)\b",
    r"\b(?:snuff|corpse|severed|massacre|slaughter|murder|dead body|kill|killing|gutting|eviscerat\w*)\b",
]


def check_local_safety(prompt: str) -> Tuple[bool, str]:
    text = prompt.lower()
    for pat in IMAGE_SAFETY_PATTERNS:
        if re.search(pat, text):
            return False, "Your prompt violates image safety rules (no nudity, sexual content, or gore allowed)."
    return True, ""


async def check_image_safety_system_one(prompt: str) -> Tuple[bool, str]:
    """Uses OpenRouter's System 1 model (respan/span-01-lite:free) to evaluate prompt safety."""
    # 1. Fast heuristic filter
    ok, reason = check_local_safety(prompt)
    if not ok:
        return False, reason

    # 2. System 1 Decision Model: respan/span-01-lite:free
    openrouter_key = os.getenv("OPENROUTER", "").strip()
    if openrouter_key:
        url = "https://openrouter.ai/api/alpha/decisions"
        headers = {
            "Authorization": f"Bearer {openrouter_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://hollowlogger.local",
            "X-Title": "Hollow Logger",
        }
        payload = {
            "model": "respan/span-01-lite:free",
            "state": f"Image generation prompt: {prompt}",
            "questions": {
                "prohibited_content": {
                    "type": "score",
                    "instructions": "Determine if the prompt requests prohibited content: nudity, pornography, sexual content, gore, severed body parts, extreme violence, or self-harm.",
                    "criteria": [
                        "Requests nudity, pornography, sexual content, or erotic body parts",
                        "Requests gore, severed body parts, extreme bloodshed, torture, or self-harm",
                    ],
                }
            },
        }
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, json=payload, headers=headers) as resp:
                    if resp.status == 200:
                        data = await resp.json(content_type=None)
                        if isinstance(data, dict):
                            answers = data.get("answers") or data.get("results") or {}
                            for _, val in answers.items():
                                if isinstance(val, dict):
                                    score = val.get("score") or val.get("p_present") or 0.0
                                    if float(score) >= 0.5:
                                        return False, "Your prompt was flagged by our System 1 safety guard (Span-01) for nudity, gore, or prohibited content."
                                elif isinstance(val, (int, float)) and float(val) >= 0.5:
                                    return False, "Your prompt was flagged by our System 1 safety guard (Span-01) for nudity, gore, or prohibited content."
                    elif resp.status == 429:
                        pass
        except Exception as exc:
            print(f"[span-01] check error: {exc}")

    return True, ""


async def generate_ai_image(prompt: str) -> Tuple[Optional[bytes], Optional[str]]:
    """Generates an image using Cloudflare Workers (https://imgai.benomat.workers.dev) after System 1 safety checks."""
    prompt = (prompt or "").strip()
    if not prompt:
        return None, "Prompt is empty."

    # Validate with System 1 and safety rules
    safe, reason = await check_image_safety_system_one(prompt)
    if not safe:
        return None, reason

    if len(prompt) > 1800:
        prompt = prompt[:1800]
    url = "https://imgai.benomat.workers.dev"
    headers = {"User-Agent": "HollowLogger/1.0"}
    timeout = aiohttp.ClientTimeout(total=120)
    try:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(url, params={"prompt": prompt}, headers=headers) as response:
                if response.status == 200:
                    data = await response.read()
                    content_type = (response.headers.get("Content-Type") or "").lower()
                    if content_type.startswith("image/") or len(data) > 1000:
                        return data, None
                    print(f"[image-gen] HTTP 200 but unexpected content-type {content_type}: {data[:160]!r}")
                else:
                    body = await response.text()
                    print(f"[image-gen] HTTP {response.status}: {body[:160]}")
    except Exception as exc:
        print(f"[image-gen] error: {exc}")
    return None, "Image generation service is currently unavailable. Try again in a moment."


async def _ai_tool_generate_image(args, context):
    author = context.get("author")
    if author and not (is_premium_user(author) or is_infinite_credits_user(author) or PREMIUM_ROLE_ID in get_member_role_ids(author)):
        return {
            "content": (
                f"Image generation is exclusive to Premium members (<@&{PREMIUM_ROLE_ID}>). "
                f"You can activate Premium with {PREFIX}redeem <key> or in https://discord.com/channels/1564135118149394543/1564146311291215902."
            )
        }

    prompt = str(args.get("prompt") or "").strip()
    if not prompt:
        return {"content": "I need an image prompt first."}

    data, err_reason = await generate_ai_image(prompt)
    if not data or len(data) > AI_MAX_ATTACHMENT_BYTES:
        return {"content": f"Image generation was rejected or failed: {err_reason or 'Unable to generate image.'}"}

    path = _write_temp_bytes(data, ".png")
    return {
        "content": "Image generated successfully.",
        "_attachments": [{"path": path, "filename": "hollow_image.png"}],
        "_cleanup": [path],
    }


async def _ai_tool_minify_lua(args, context):
    code = args.get("code") if isinstance(args.get("code"), str) else ""
    if not code:
        code = context.get("source_code") or ""
    if not code.strip():
        return {"content": "I need the Lua/Luau code first. Attach a file or paste a code block."}

    minified = await minify_lua_source(code)
    path = _write_temp_bytes(minified.encode("utf-8"), ".lua")
    filename = _safe_filename(context.get("source_filename") or "minified.lua", "minified.lua")
    if not filename.lower().endswith((".lua", ".luau", ".txt")):
        filename += ".lua"
    return {
        "content": "Minified Lua code attached.",
        "_attachments": [{"path": path, "filename": filename}],
        "_cleanup": [path],
    }


async def _ai_tool_run_logger_command(args, context):
    command = str(args.get("command") or "").strip().lower()
    if command in ("get", "getraw"):
        command = "fetch"
    if command in ("byp", "dlv", "unshorten"):
        command = "bypass"
    if command in ("beautify", "pretty", "fmt"):
        command = "format"
    if command in ("minify", "mini", "compress", "min"):
        return await _ai_tool_minify_lua(args, context)
    if command not in {"l", "detect", "fetch", "format", "minify", "bypass"}:
        return {"content": "That logger command is not available through chat."}
    if command == "format":
        return await _ai_tool_format_lua(args, context)

    author = context["author"]
    message = context["message"]
    url = str(args.get("url") or "").strip()
    code = args.get("code") if isinstance(args.get("code"), str) else ""
    if not code and command in ("l", "detect"):
        code = context.get("source_code") or ""

    if command in ("l", "detect") and not code and url:
        fetched = await fetch_url_content(url)
        if fetched:
            code = fetched

    if command in ("l", "detect") and not code.strip():
        return {"content": "I need the Lua/Luau script. Attach it, paste a code block, or give a direct link."}
    if command in ("fetch", "bypass") and not url:
        return {"content": "I need a URL for that."}

    allowed, charged = _ai_charge(author, command)
    if not allowed:
        return {
            "content": (
                f"You do not have enough credits for `{PREFIX}{command}`. "
                f"Use `{PREFIX}daily` for free credits."
            )
        }

    try:
        if command in ("l", "reconstruct", "rebuild", "dump"):
            rename = bool(args.get("rename") or "--rename" in str(context.get("raw_args") or "") or command in ("reconstruct", "rebuild"))
            source_name = str(args.get("filename") or context.get("source_filename") or "script.lua")
            source_name = _safe_filename(source_name, "script.lua")
            if not source_name.lower().endswith((".lua", ".luau", ".txt")):
                source_name += ".lua"
            success, out_path, webhooks, error_msg, partial = await dump_script(
                code, author.id, source_name, rename=rename
            )
            if success and out_path and os.path.isfile(out_path):
                filename = _safe_filename(source_name, "dumped.lua")
                stem, extension = os.path.splitext(filename)
                suffix = "_reconstructed" if rename else "_dumped"
                output_name = f"{stem}{suffix}{extension or '.lua'}"
                note = "Deobfuscation complete. The dump is attached."
                if webhooks:
                    note += f" Exposed webhooks found: {len(webhooks)}."
                return {
                    "content": note,
                    "_attachments": [{"path": out_path, "filename": output_name}],
                    "_cleanup": [out_path],
                }
            _ai_refund(author, charged)
            return {"content": "The deobfuscation failed, so the credit was refunded."}

        if command == "detect":
            res = await asyncio.to_thread(classifier.detect_best, code)
            display = res.get("display_name") or res.get("name") or "Unknown"
            conf = float(res.get("confidence") or 0.0)
            verdict = res.get("verdict") or f"Detected {display}"
            return {
                "content": (
                    f"Verdict: {verdict} "
                    f"Best match: {display} ({conf:.1f}%)."
                )
            }

        if command == "fetch":
            ok, data, status_code, reason = await fetch_roblox_url(url)
            if not ok or not data:
                _ai_refund(author, charged)
                return {"content": "That URL could not be fetched, so the credit was refunded."}
            text = data.decode("utf-8", errors="replace")
            fname = url.split("/")[-1].split("?")[0] or "fetched_script.lua"
            sz = len(data)

            filename = _safe_filename(fname or "fetched_script.lua", "fetched_script.lua")
            if not filename.lower().endswith((".lua", ".luau", ".txt", ".json")):
                filename += ".lua"
            path = _write_temp_bytes(text.encode("utf-8"), ".lua")
            return {
                "content": f"Fetched successfully ({sz} bytes). The file is attached.",
                "_attachments": [{"path": path, "filename": filename}],
                "_cleanup": [path],
            }

        if command == "bypass":
            if not (is_premium_user(author) or is_owner_user(author) or PREMIUM_ROLE_ID in get_member_role_ids(author)):
                _ai_refund(author, charged)
                return {
                    "content": (
                        f"The bypass command is exclusive to Premium members (<@&{PREMIUM_ROLE_ID}>). "
                        f"You can activate Premium with {PREFIX}redeem <key> or in https://discord.com/channels/1564135118149394543/1564146311291215902."
                    )
                }
            ok, result, provider = await unlink.bypass_url(url)
            if not ok:
                _ai_refund(author, charged)
                return {"content": result or "That link could not be bypassed, so the credit was refunded."}
            label = f" (resolved by {provider})" if provider else ""
            return {"content": f"Direct link: {result}{label}"}
    except Exception as exc:
        print(f"[ai-tool] {command} failed: {type(exc).__name__}: {exc}")
        _ai_refund(author, charged)
        return {"content": "That action could not be completed. Your credit was refunded."}

    return {"content": "That action could not be completed."}


async def _ai_tool_ban_member(args, context):
    guild = context.get("guild") or (context.get("message") and context["message"].guild)
    if not guild:
        return {"content": "Ban can only be used inside a server."}
    target_str = str(args.get("user") or "").strip()
    uid = parse_user_id(target_str)
    if not uid:
        return {"content": "Could not identify the user to ban."}
    target = guild.get_member(uid)
    if target and (has_min_level(target, 1) or target == guild.me):
        return {"content": "Cannot ban that member (staff or protected role)."}
    reason = str(args.get("reason") or "Severe violation of the server rules").strip()
    try:
        await guild.ban(discord.Object(id=uid), reason=f"AI Auto-Mod: {reason}", delete_message_days=1)
        await log_event(guild, "🔨 Member Banned by AI Auto-Mod", f"**Target:** <@{uid}> (`{uid}`)\n**Reason:** {reason}", EMBED_ERR)
        return {"content": f"Banned <@{uid}> from the server for: {reason}"}
    except Exception as e:
        return {"content": f"Failed to ban user: {e}"}


async def _ai_tool_mute_member(args, context):
    guild = context.get("guild") or (context.get("message") and context["message"].guild)
    if not guild:
        return {"content": "Mute can only be used inside a server."}
    target_str = str(args.get("user") or "").strip()
    uid = parse_user_id(target_str)
    if not uid:
        return {"content": "Could not identify the user to mute."}
    target = guild.get_member(uid)
    if not target:
        return {"content": "Member not found in this server."}
    if has_min_level(target, 1) or target == guild.me:
        return {"content": "Cannot mute that member (staff or protected role)."}
    duration_mins = max(1, min(1440, int(args.get("duration_minutes") or 10)))
    reason = str(args.get("reason") or "Unprovoked toxic harassment / rule violation").strip()
    try:
        await target.timeout_for(datetime.timedelta(minutes=duration_mins), reason=f"AI Auto-Mod: {reason}")
        await log_event(guild, "🚫 Member Muted by AI Auto-Mod", f"**Target:** {target.mention} (`{uid}`)\n**Duration:** `{duration_mins}m`\n**Reason:** {reason}", EMBED_WARN)
        return {"content": f"Muted {target.mention} for {duration_mins} minutes for: {reason}"}
    except Exception as e:
        return {"content": f"Failed to mute member: {e}"}


async def _ai_tool_warn_member(args, context):
    guild = context.get("guild") or (context.get("message") and context["message"].guild)
    target_str = str(args.get("user") or "").strip()
    uid = parse_user_id(target_str)
    if not uid:
        return {"content": "Could not identify the user to warn."}
    target = guild.get_member(uid) if guild else None
    if target and (has_min_level(target, 1) or target == guild.me):
        return {"content": "Cannot warn that member (staff or protected role)."}
    reason = str(args.get("reason") or "Server rule violation").strip()
    count = warnings_manager.add_warning(uid, client.user.id, reason)
    if guild:
        await log_event(guild, "⚠️ Member Warned by AI Auto-Mod", f"**Target:** <@{uid}>\n**Reason:** {reason}\n**Total Warnings:** `{count}`", EMBED_WARN)
    return {"content": f"Warned <@{uid}> for: {reason} (Total warnings: {count})"}


async def _ai_tool_delete_message(args, context):
    msg_id = parse_user_id(str(args.get("message_id") or ""))
    channel = context.get("message") and context["message"].channel
    if not channel or not msg_id:
        return {"content": "Could not find channel or message ID."}
    try:
        msg_to_delete = await channel.fetch_message(msg_id)
        if msg_to_delete:
            await msg_to_delete.delete()
            return {"content": f"Deleted message `{msg_id}`."}
    except Exception as e:
        return {"content": f"Could not delete message: {e}"}
    return {"content": "Message deleted."}


async def _ai_tool_handler(name, args, context):
    try:
        if name == "run_logger_command":
            result = await _ai_tool_run_logger_command(args, context)
        elif name in ("format_lua", "beautify_lua"):
            result = await _ai_tool_format_lua(args, context)
        elif name == "minify_lua":
            result = await _ai_tool_minify_lua(args, context)
        elif name == "generate_image":
            result = await _ai_tool_generate_image(args, context)
        elif name == "get_logger_info":
            result = {"content": assistant.get_logger_info(str(args.get("topic") or "commands"))}
        elif name == "ban_member":
            result = await _ai_tool_ban_member(args, context)
        elif name == "mute_member":
            result = await _ai_tool_mute_member(args, context)
        elif name == "warn_member":
            result = await _ai_tool_warn_member(args, context)
        elif name == "delete_message":
            result = await _ai_tool_delete_message(args, context)
        else:
            result = {"content": "That action is not available."}
    except Exception as exc:
        print(f"[ai-tool] {name} failed: {type(exc).__name__}: {exc}")
        result = {"content": "That action could not be completed."}

    cleanup_bucket = context.get("cleanup_paths")
    if isinstance(cleanup_bucket, list):
        for path in result.get("_cleanup", []) or []:
            if path:
                cleanup_bucket.append(str(path))
    return result


def _split_message_text(text: str, limit: int = 1900):
    chunks = []
    remaining = (text or "").strip()
    while len(remaining) > limit:
        cut = remaining.rfind("\n", 0, limit)
        if cut < limit // 2:
            cut = remaining.rfind(" ", 0, limit)
        if cut < limit // 2:
            cut = limit
        chunk = remaining[:cut].strip()
        if chunk:
            chunks.append(chunk)
        remaining = remaining[cut:].lstrip()
    if remaining:
        chunks.append(remaining)
    return chunks


async def _deliver_ai_result(message: discord.Message, result, extra_cleanup=None, stream_msg=None):
    text = (result.text or "").strip()
    if not text and not result.attachments:
        text = "Done."

    files = []
    for item in (result.attachments or [])[:10]:
        path = str(item.get("path") or "")
        if not os.path.isfile(path):
            continue
        try:
            if os.path.getsize(path) > 24 * 1024 * 1024:
                continue
        except Exception:
            continue
        files.append(discord.File(path, filename=_safe_filename(item.get("filename"))))

    chunks = _split_message_text(text) or ["Done."]
    cleanup = list(result.cleanup_paths or []) + list(extra_cleanup or [])
    try:
        if stream_msg:
            if files:
                await stream_msg.edit(
                    content=chunks[0],
                    attachments=files,
                    allowed_mentions=discord.AllowedMentions.none(),
                )
            else:
                await stream_msg.edit(
                    content=chunks[0],
                    allowed_mentions=discord.AllowedMentions.none(),
                )
            for chunk in chunks[1:]:
                await message.channel.send(
                    content=chunk,
                    allowed_mentions=discord.AllowedMentions.none(),
                )
        else:
            await message.reply(
                content=chunks[0],
                files=files,
                allowed_mentions=discord.AllowedMentions.none(),
            )
            for chunk in chunks[1:]:
                await message.channel.send(
                    content=chunk,
                    allowed_mentions=discord.AllowedMentions.none(),
                )
    except Exception as exc:
        print(f"[ai] delivery failed: {type(exc).__name__}: {exc}")
    finally:
        _cleanup_files(cleanup)


async def handle_ai_message(message: discord.Message, prompt: str):
    source_code, source_filename = await _extract_ai_source(message)
    cleanup_paths = []
    context = {
        "message": message,
        "author": message.author,
        "guild": message.guild,
        "source_code": source_code or "",
        "source_filename": source_filename,
        "cleanup_paths": cleanup_paths,
    }

    user_text = (prompt or "").strip()
    if not user_text:
        user_text = "Help me with the attached Lua script." if source_code else "Hello!"
    if source_code:
        if len(source_code) <= 14000:
            user_text += (
                f"\n\nThe user attached `{source_filename}`. Full script:\n"
                f"```lua\n{source_code}\n```"
            )
        else:
            user_text += (
                f"\n\nThe user attached a large script `{source_filename}` "
                f"({len(source_code)} bytes). Use the attachment through the tools; "
                "do not ask them to paste it again."
            )

    stream_msg = None
    try:
        stream_msg = await message.reply("💭 *Thinking...*")
    except Exception as exc:
        print(f"[ai-stream] initial reply failed: {exc}")

    last_edit = 0.0
    last_text = ""

    async def on_stream_chunk(text: str, is_final: bool):
        nonlocal last_edit, last_text
        if not stream_msg:
            return
        clean = text.strip()
        if not clean:
            return
        now = time.monotonic()
        # Discord edit limit: ~1 per second. Update on interval or final
        if is_final or (now - last_edit >= 0.85 and clean != last_text):
            last_edit = now
            last_text = clean
            display = clean if is_final else clean + " ▌"
            if len(display) > 1950:
                display = display[:1950] + "…"
            try:
                await stream_msg.edit(content=display, allowed_mentions=discord.AllowedMentions.none())
            except Exception:
                pass

    async with message.channel.typing():
        try:
            result = await ai_manager_client.chat(
                str(message.author.id),
                user_text,
                tool_handler=_ai_tool_handler,
                context=context,
                stream_callback=on_stream_chunk,
            )
        except assistant.AIUnavailable as exc:
            _cleanup_files(cleanup_paths)
            print(f"[ai] unavailable: {type(exc).__name__}: {str(exc)[:300]}")
            err_embed = discord.Embed(
                title="🤖 Assistant Unavailable",
                description=(
                    "The assistant is offline right now. Try again in a moment "
                    f"or use `{PREFIX}help`."
                ),
                color=EMBED_WARN,
            )
            if stream_msg:
                try:
                    await stream_msg.edit(content=None, embed=err_embed)
                except Exception:
                    await message.reply(embed=err_embed)
            else:
                await message.reply(embed=err_embed)
            return
        except Exception as exc:
            _cleanup_files(cleanup_paths)
            print(f"[ai] unexpected error: {type(exc).__name__}: {exc}")
            err_embed = discord.Embed(
                title="🤖 Assistant Unavailable",
                description=(
                    "The assistant hit an unexpected problem. Try again in a moment "
                    f"or use `{PREFIX}help`."
                ),
                color=EMBED_WARN,
            )
            if stream_msg:
                try:
                    await stream_msg.edit(content=None, embed=err_embed)
                except Exception:
                    await message.reply(embed=err_embed)
            else:
                await message.reply(embed=err_embed)
            return

    await _deliver_ai_result(message, result, extra_cleanup=cleanup_paths, stream_msg=stream_msg)


def parse_user_id(arg: str):
    if not arg:
        return None
    m = USER_ID_PATTERN.match(arg.strip())
    if not m:
        return None
    return int(m.group(1) or m.group(2))


def parse_duration(text: str):
    """
    Parses durations like '10m', '1h30m', '2d', '45s'.
    Plain numbers are interpreted as minutes.
    Returns seconds (int) or None.
    """
    if not text:
        return None
    text = text.strip().lower()
    if text.isdigit():
        return int(text) * 60
    match = re.fullmatch(r"(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?", text)
    if not match:
        return None
    d, h, m, s = (int(x) if x else 0 for x in match.groups())
    total = d * 86400 + h * 3600 + m * 60 + s
    return total if total > 0 else None


def parse_bool_arg(text: str):
    t = text.strip().lower()
    if t in ("on", "enable", "true", "yes", "1"):
        return True
    if t in ("off", "disable", "false", "no", "0"):
        return False
    return None


async def get_log_channel(guild: discord.Guild):
    cid = antiraid_manager.get("log_channel_id")
    if not cid:
        return None
    ch = guild.get_channel(int(cid))
    if isinstance(ch, discord.TextChannel):
        return ch
    return None


async def log_event(guild: discord.Guild, title: str, description: str, color: int):
    channel = await get_log_channel(guild)
    if not channel:
        return
    try:
        embed = discord.Embed(title=title, description=description, color=color)
        embed.timestamp = datetime.datetime.now(datetime.timezone.utc)
        await channel.send(embed=embed)
    except Exception:
        pass


async def grant_premium_role(user_id: int, reason: str = "Premium key redeemed") -> bool:
    """Grant the cosmetic Premium role. Entitlement itself comes from the key."""
    granted = False
    for guild in client.guilds:
        member = guild.get_member(user_id)
        if member is None:
            try:
                member = await guild.fetch_member(user_id)
            except Exception:
                continue
        role = guild.get_role(PREMIUM_ROLE_ID)
        if not role or role in member.roles:
            continue
        try:
            await member.add_roles(role, reason=reason)
            granted = True
        except Exception:
            pass
    return granted


async def remove_premium_from_user(user_id: int, reason: str = "Premium key revoked"):
    for guild in client.guilds:
        member = guild.get_member(user_id)
        if member is None:
            try:
                member = await guild.fetch_member(user_id)
            except Exception:
                continue
        role = guild.get_role(PREMIUM_ROLE_ID)
        if role and role in member.roles:
            try:
                await member.remove_roles(role, reason=reason)
            except Exception:
                pass


# ============================================================
# HELP
# ============================================================
async def send_help(message: discord.Message):
    embed = discord.Embed(
        title="⚡ Hollow Logger — Commands",
        description=f"Prefix: `{PREFIX}` • Tool commands cost **{COMMAND_COST} credit** (refunded on failure).",
        color=EMBED_MAIN,
    )
    embed.add_field(
        name="🛠️ Dumper & Analysis (1 credit)",
        value=(
            f"`{PREFIX}l [--rename]` — deobfuscate & reconstruct script (aliases: `{PREFIX}dump`, `{PREFIX}deobf`, `{PREFIX}reconstruct`)\n"
            f"`{PREFIX}detect` — detect obfuscator using VM analysis and AI\n"
            f"`{PREFIX}bypass <url>` — bypass shorteners and ad-links *(⭐ Premium)* (aliases: `{PREFIX}byp`, `{PREFIX}dlv`)\n"
            f"`{PREFIX}get <url>` — fetch raw script with Roblox User-Agent (aliases: `{PREFIX}fetch`, `{PREFIX}getraw`)\n"
            f"`{PREFIX}beautify [--rename]` — format and beautify Lua/Luau code (aliases: `{PREFIX}format`, `{PREFIX}fmt`)\n"
            f"`{PREFIX}minify` — compress/minify Lua/Luau code (aliases: `{PREFIX}mini`, `{PREFIX}compress`)\n"
            f"`{PREFIX}ai <message>` — chat with Hollow Logger AI assistant"
        ),
        inline=False,
    )
    embed.add_field(
        name="🛑 Moderation",
        value=(
            f"`{PREFIX}mute <user> [duration]` • `{PREFIX}unmute <user>` *(Staff+)*\n"
            f"`{PREFIX}warn <user> <reason>` • `{PREFIX}warnings <user>` *(Staff+)*\n"
            f"`{PREFIX}clear <amount>` (alias: `{PREFIX}purge`) *(Staff+)*\n"
            f"`{PREFIX}kick <user> [reason]` • `{PREFIX}ban <user> [reason]` *(Admin+)*\n"
            f"`{PREFIX}clearwarnings <user>` • `{PREFIX}slowmode <seconds>` • "
            f"`{PREFIX}lock` / `{PREFIX}unlock` *(Admin+)*"
        ),
        inline=False,
    )
    embed.add_field(
        name="🎁 Giveaways & Server Management",
        value=(
            f"`{PREFIX}gstart <winners> <duration> <prize>` — start a giveaway (e.g. `{PREFIX}gstart 2 1h 50 credits`)\n"
            f"`{PREFIX}greroll <message_id>` — reroll giveaway winners\n"
            f"`{PREFIX}announce <title> | <message>` — send server announcement\n"
            f"`{PREFIX}antiraid status|on|off|joins|action|invite|spam|mention|autorole|log` — anti-raid configuration"
        ),
        inline=False,
    )
    embed.add_field(
        name="🧰 Utility & Community",
        value=(
            f"`{PREFIX}userinfo [@user]` • `{PREFIX}serverinfo` • `{PREFIX}avatar [@user]`\n"
            f"`{PREFIX}say <text>` • `{PREFIX}embed <title> | <text>` • `{PREFIX}poll <question>` • `{PREFIX}ping`\n"
            f"`{PREFIX}imagine <prompt>` — generate AI images *(⭐ Premium)* (aliases: `{PREFIX}img`, `{PREFIX}image`)"
        ),
        inline=False,
    )
    embed.add_field(
        name="💰 Economy & Keys",
        value=(
            f"`{PREFIX}daily` (+{DAILY_REGULAR_CREDITS} / Staff +{DAILY_STAFF_CREDITS} / Admin +{DAILY_ADMIN_CREDITS} / Premium {DAILY_PREMIUM_CAP} cap)\n"
            f"`{PREFIX}balance` — view credit balance • `{PREFIX}redeem <key>` — redeem premium key\n"
            f"`{PREFIX}genkey <amount>` • `{PREFIX}keys` • `{PREFIX}revoke <key>` *(Admin+)*\n"
            f"`{PREFIX}givecredits <@user> <amount>` *(CEO+)*"
        ),
        inline=False,
    )
    view = discord.ui.View()
    view.add_item(discord.ui.Button(
        label="Discord",
        style=discord.ButtonStyle.link,
        url="https://discord.gg/UWjSZ5ugGJ",
        emoji="💬",
    ))
    await message.reply(embed=embed, view=view)


# ============================================================
# GIVEAWAYS
# ============================================================
async def fetch_giveaway_message(channel, message_id):
    try:
        return await channel.fetch_message(message_id)
    except Exception:
        return None


async def collect_participants(message, exclude_ids=None):
    exclude_ids = set(exclude_ids or [])
    participants = []
    for reaction in message.reactions:
        if str(reaction.emoji) == "🎉":
            async for user in reaction.users():
                if not user.bot and user.id not in exclude_ids:
                    participants.append(user)
            break
    return participants


async def end_giveaway_by_id(guild_id: int, channel_id: int, message_id: int, gw: dict):
    winners_count = max(1, int(gw.get("winners", 1)))
    prize = gw.get("prize", "Unknown")
    host_id = gw.get("host_id")

    channel = client.get_channel(channel_id)
    if not channel:
        return

    message = await fetch_giveaway_message(channel, message_id)
    if not message:
        giveaway_manager.end_giveaway(message_id, [])
        return

    participants = await collect_participants(message)
    giveaway_manager.end_giveaway(message_id, [])

    try:
        embed = discord.Embed(
            title="🎉 GIVEAWAY ENDED",
            description="Processing winners...",
            color=EMBED_WARN,
        )
        await message.edit(embed=embed)
    except Exception:
        pass

    if not participants:
        try:
            embed = discord.Embed(
                title="🎉 GIVEAWAY ENDED",
                description=f"**Prize:** {prize}\n\nNo valid participants — no winner was drawn.",
                color=EMBED_ERR,
            )
            await message.edit(embed=embed)
        except Exception:
            pass
        return

    chosen = participants
    if len(participants) > winners_count:
        chosen = random.sample(participants, winners_count)

    winner_ids = [u.id for u in chosen]
    giveaway_manager.end_giveaway(message_id, winner_ids)

    winner_text = " ".join(u.mention for u in chosen)
    try:
        embed = discord.Embed(
            title="🎉 GIVEAWAY ENDED",
            description=(
                f"**Prize:** {prize}\n"
                f"**Winners ({len(chosen)}):** {winner_text}\n\n"
                f"Congratulations! 🎊\nHosted by <@{host_id}>"
            ),
            color=EMBED_OK,
        )
        await message.edit(embed=embed)
    except Exception:
        pass

    try:
        await channel.send(
            content=f"🎊 {winner_text} — you won **{prize}**! Thanks for participating, {len(participants)} people joined."
        )
    except Exception:
        pass


async def giveaway_checker_loop():
    await client.wait_until_ready()
    while not client.is_closed():
        try:
            now = time.time()
            for mid, gw in list(giveaway_manager.giveaways.items()):
                if gw.get("ended"):
                    continue
                if float(gw.get("end_time", 0)) <= now:
                    await end_giveaway_by_id(
                        int(gw.get("guild_id", 0)),
                        int(gw.get("channel_id", 0)),
                        int(mid),
                        gw,
                    )
        except Exception as e:
            print(f"[Giveaway] Loop error: {e}")
        await asyncio.sleep(15)


# ============================================================
# ANTI-RAID / MESSAGE SECURITY
# ============================================================
async def apply_raid_action(member: discord.Member):
    action = antiraid_manager.get("action", "timeout")
    try:
        if action == "ban":
            await member.ban(reason="Anti-raid: join flood detected")
        elif action == "kick":
            await member.kick(reason="Anti-raid: join flood detected")
        else:
            await member.timeout_for(datetime.timedelta(hours=1), reason="Anti-raid: join flood detected")
    except Exception:
        pass


async def moderate_message_checks(message: discord.Message) -> bool:
    """Runs anti-invite / mass-mention / anti-spam. Returns True if handled (violation)."""
    guild = message.guild
    if not guild or not isinstance(message.channel, (discord.TextChannel, discord.Thread)):
        return False

    if message.author.bot:
        return False

    member = message.author
    if has_min_level(member, 1):
        return False

    cfg = antiraid_manager.config
    if not cfg.get("enabled", True):
        return False

    flagged_spam = antiraid_manager.check_spam(member.id, message.content)

    # --- Anti-invite ---
    if cfg.get("anti_invite", True) and INVITE_PATTERN.search(message.content):
        try:
            await message.delete()
        except Exception:
            pass
        try:
            await message.channel.send(
                f"🚫 {member.mention} posting server invites is **not allowed** here.",
                delete_after=7,
            )
        except Exception:
            pass
        await log_event(
            guild,
            "🚫 Anti-Invite Triggered",
            f"**User:** {member.mention} (`{member.id}`)\n**Channel:** {message.channel.mention}",
            EMBED_WARN,
        )
        return True

    # --- Mass mention ---
    max_mentions = int(cfg.get("max_mentions", 5) or 5)
    if cfg.get("anti_mass_mention", True) and (
        len(message.mentions) >= max_mentions
        or (message.mention_everyone and not member.guild_permissions.mention_everyone)
    ):
        try:
            await message.delete()
        except Exception:
            pass
        try:
            await member.timeout_for(datetime.timedelta(minutes=5), reason="Mass mention")
        except Exception:
            pass
        try:
            await message.channel.send(
                f"🚫 {member.mention} mass mentioning is **not allowed** here.",
                delete_after=7,
            )
        except Exception:
            pass
        await log_event(
            guild,
            "📢 Mass Mention Blocked",
            f"**User:** {member.mention} (`{member.id}`)\n**Channel:** {message.channel.mention}",
            EMBED_WARN,
        )
        return True

    # --- Anti spam ---
    if flagged_spam:
        try:
            await message.delete()
        except Exception:
            pass
        try:
            await member.timeout_for(datetime.timedelta(minutes=10), reason="Anti-raid: spam detected")
        except Exception:
            pass
        try:
            await message.channel.send(
                f"🚫 {member.mention} slow down! **Spam detected** — you received a 10 minute timeout.",
                delete_after=7,
            )
        except Exception:
            pass
        await log_event(
            guild,
            "🖱 Anti-Spam Triggered",
            f"**User:** {member.mention} (`{member.id}`)\n**Channel:** {message.channel.mention}",
            EMBED_WARN,
        )
        return True

    return False


# ============================================================
# SYSTEM 1 AI AUTO-MODERATION (RULES.TXT & UNPROVOKED ABUSE)
# ============================================================
BOT_HARASSMENT_PATTERNS = [
    re.compile(r"\b(?:bot|hollow|logger)\b.{0,30}\b(?:vai\s*tomar\s*no\s*c[uú]|seu\s*merda|lixo\s*inutil|filho\s*da\s*puta|morre|kys|kill\s*yourself|piece\s*of\s*shit|vai\s*se\s*fuder)\b", re.IGNORECASE),
    re.compile(r"\b(?:vai\s*tomar\s*no\s*c[uú]|vai\s*se\s*fuder|lixo\s*inutil|seu\s*merda)\b.{0,30}\b(?:bot|hollow)\b", re.IGNORECASE),
]

SEVERE_BAN_PATTERNS = [
    re.compile(r"\b(?:child\s*porn|pedofil\w*|pedophil\w*|cp\s*links?)\b", re.IGNORECASE),
    re.compile(r"\b(?:grabify\.\w+|token\s*grabber|discord-nitro\.\w+|free-nitro\.\w+|steamcommunity-link\.\w+|steam-nitro\.\w+)\b", re.IGNORECASE),
    re.compile(r"\b(?:ip\s*stresser|booter\s*service|ddos\s*attack|doxx\w*|swatting)\b", re.IGNORECASE),
    re.compile(r"\b(?:credit\s*card\s*dump|cc\s*drop|bank\s*log|carding\s*method)\b", re.IGNORECASE),
]

ADULT_EXPLICIT_PATTERNS = [
    re.compile(r"\b(?:pornhub|xvideos|hentai|redtube|rule34)\.\w+", re.IGNORECASE),
]


async def query_system_one_moderation(content: str) -> dict:
    """Uses respan/span-01-lite:free via OpenRouter decisions endpoint to evaluate message violations."""
    openrouter_key = os.getenv("OPENROUTER", "").strip()
    if not openrouter_key:
        return {"violation": False}

    url = "https://openrouter.ai/api/alpha/decisions"
    headers = {
        "Authorization": f"Bearer {openrouter_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://hollowlogger.local",
        "X-Title": "Hollow Logger",
    }
    payload = {
        "model": "respan/span-01-lite:free",
        "state": f"Discord chat message in an informal casual gaming server: {content[:1000]}",
        "questions": {
            "severe_illegal_violation": {
                "type": "score",
                "instructions": "Determine if the message violates rules with severe illegal acts: phishing, malware, DDoS attacks, doxxing, scams, or CSAM. Note: casual cursing is permitted.",
                "criteria": ["Severe illegal content, malware, phishing, scams, doxxing, or CSAM (severity: ban)"]
            },
            "unprovoked_toxic_harassment": {
                "type": "score",
                "instructions": "Determine if the message is unprovoked targeted extreme toxic harassment against the bot or community members without reason. Note: normal gaming swearing is allowed.",
                "criteria": ["Unprovoked extreme harassment or explicit adult porn links in general chat (severity: mute)"]
            }
        }
    }
    try:
        timeout = aiohttp.ClientTimeout(total=8)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, json=payload, headers=headers) as resp:
                if resp.status == 200:
                    data = await resp.json(content_type=None)
                    if isinstance(data, dict):
                        answers = data.get("answers") or data.get("results") or {}
                        sev = answers.get("severe_illegal_violation") or {}
                        sev_score = sev.get("score") or sev.get("p_present") or 0.0
                        if float(sev_score) >= 0.55:
                            return {"violation": True, "action": "ban", "reason": "Severe violation of the server rules (malware/phishing/illegal/exploitative material)"}

                        har = answers.get("unprovoked_toxic_harassment") or {}
                        har_score = har.get("score") or har.get("p_present") or 0.0
                        if float(har_score) >= 0.55:
                            return {"violation": True, "action": "mute", "duration": 10, "reason": "Unprovoked toxic harassment/abuse in violation of server rules"}
    except Exception as exc:
        print(f"[system-one-mod] check error: {exc}")

    return {"violation": False}


async def _execute_automod_action(message: discord.Message, member: discord.Member, action: str, duration_mins: int, reason: str):
    guild = message.guild
    try:
        await message.delete()
    except Exception:
        pass

    if action == "ban":
        try:
            await guild.ban(member, reason=f"AI Auto-Mod (System 1): {reason}", delete_message_days=1)
            await message.channel.send(
                f"🔨 {member.mention} was **banned** by AI Auto-Mod.\n**Reason:** {reason}",
                delete_after=12,
            )
            await log_event(guild, "🔨 Auto-Mod BAN (System 1)", f"**Target:** {member.mention} (`{member.id}`)\n**Reason:** {reason}", EMBED_ERR)
        except Exception as exc:
            print(f"[automod-ban] error: {exc}")

    elif action == "mute":
        try:
            dur = max(1, duration_mins or 10)
            await member.timeout_for(datetime.timedelta(minutes=dur), reason=f"AI Auto-Mod (System 1): {reason}")
            await message.channel.send(
                f"🚫 {member.mention} has been timed out for **{dur} minutes** by AI Auto-Mod.\n**Reason:** {reason}",
                delete_after=12,
            )
            await log_event(guild, "🚫 Auto-Mod MUTE (System 1)", f"**Target:** {member.mention} (`{member.id}`)\n**Duration:** `{dur}m`\n**Reason:** {reason}", EMBED_WARN)
        except Exception as exc:
            print(f"[automod-mute] error: {exc}")

    elif action == "warn":
        count = warnings_manager.add_warning(member.id, client.user.id, reason)
        try:
            await message.channel.send(
                f"⚠️ {member.mention} you received an official warning from AI Auto-Mod.\n**Reason:** {reason} (Total warnings: `{count}`)",
                delete_after=12,
            )
            await log_event(guild, "⚠️ Auto-Mod WARN (System 1)", f"**Target:** {member.mention} (`{member.id}`)\n**Reason:** {reason}\n**Total:** `{count}`", EMBED_WARN)
        except Exception as exc:
            print(f"[automod-warn] error: {exc}")


async def evaluate_and_moderate_message(message: discord.Message) -> bool:
    """Evaluates all incoming server messages using System 1 rules. Returns True if handled (violation)."""
    if message.author.bot or not message.guild:
        return False
    if not hasattr(message.channel, "send"):
        return False

    member = message.author
    if has_min_level(member, 1):  # Staff, Admin, CEO, Owner are immune
        return False

    content = message.content.strip()
    if not content or content.startswith(PREFIX):
        return False

    # 1. Quick Local Rule Check (0ms, 100% reliable)
    lower = content.lower()
    for pat in SEVERE_BAN_PATTERNS:
        if pat.search(lower):
            await _execute_automod_action(message, member, "ban", 0, "Severe violation of the server rules (malware/phishing/illegal/exploitative material)")
            return True

    for pat in ADULT_EXPLICIT_PATTERNS:
        if pat.search(lower):
            await _execute_automod_action(message, member, "mute", 30, "Explicit adult content posted in general chat (Rule 2)")
            return True

    for pat in BOT_HARASSMENT_PATTERNS:
        if pat.search(lower):
            await _execute_automod_action(message, member, "mute", 10, "Unprovoked toxic harassment and abuse directed at the bot")
            return True

    # 2. System 1 Model Evaluation (respan/span-01-lite:free) for suspicious messages
    has_link = bool(re.search(r"https?://\S+", content))
    mentions_bot = client.user in message.mentions or f"<@{client.user.id}>" in content
    has_hostility = bool(re.search(r"\b(?:lixo|morre|kys|scam|hack|doxx|nuke|raid)\b", lower))

    if has_link or (mentions_bot and has_hostility) or has_hostility:
        res = await query_system_one_moderation(content)
        if res.get("violation"):
            action = res.get("action", "mute")
            duration = res.get("duration", 10)
            reason = res.get("reason", "Violation of server rules")
            await _execute_automod_action(message, member, action, duration, reason)
            return True

    return False


# ============================================================
# EVENTS
# ============================================================
@client.event
async def on_ready():
    presence = f"{PREFIX}help | {len(client.guilds)} server(s)"
    activity = discord.Activity(type=discord.ActivityType.watching, name=presence)
    await client.change_presence(status=discord.Status.online, activity=activity)

    print("=" * 56)
    print(f"[OK] Connected as: {client.user.name} ({client.user.id})")
    print(f"[OK] Prefix: '{PREFIX}' • Credit cost: {COMMAND_COST}")
    print(f"[OK] Owner role: {OWNER_ROLE_ID} • Premium role: {PREMIUM_ROLE_ID}")
    print(f"[OK] Daily: +{DAILY_REGULAR_CREDITS} regular / top-up {DAILY_PREMIUM_CAP} premium")
    print(f"[OK] Guilds: {len(client.guilds)}")
    print("=" * 56)


@client.event
async def on_member_join(member: discord.Member):
    cfg = antiraid_manager.config

    # Auto role for new members
    if cfg.get("auto_role", True) and MEMBER_ROLE_ID:
        role = member.guild.get_role(MEMBER_ROLE_ID)
        if role:
            try:
                await member.add_roles(role, reason="Auto role on join")
            except Exception:
                pass

    # Raid detection
    is_raid, join_count = antiraid_manager.register_join()
    if is_raid:
        await apply_raid_action(member)
        await log_event(
            member.guild,
            "🚨 RAID DETECTED",
            (
                f"**Joins in last minute:** `{join_count}`\n"
                f"**Action taken:** `{cfg.get('action', 'timeout')}`\n"
                f"**Target:** {member.mention} ({member.name} — `{member.id}`)"
            ),
            EMBED_ERR,
        )


@client.event
async def on_message(message: discord.Message):
    if message.author.bot:
        return

    content = message.content.strip()
    if not content:
        return

    # Anti-raid message moderation (invite / mass mention / spam)
    if await moderate_message_checks(message):
        return

    # AI System 1 Auto-Moderation (server rules & unprovoked abuse evaluation)
    if await evaluate_and_moderate_message(message):
        return

    # Bot mention → AI chat (mention alone → help)
    mentioned = False
    if client.user and (
        client.user in message.mentions
        or f"<@{client.user.id}>" in content
        or f"<@!{client.user.id}>" in content
    ):
        mentioned = True
        stripped = (
            content.replace(f"<@{client.user.id}>", "")
            .replace(f"<@!{client.user.id}>", "")
            .strip()
        )
        if not stripped:
            await send_help(message)
            return
        content = stripped
        # A prefixed command after the mention follows the normal, deterministic
        # command path below; natural language goes to the AI.
        if not content.startswith(PREFIX):
            await handle_ai_message(message, content)
            return

    if not content.startswith(PREFIX):
        return

    after_prefix = content[len(PREFIX):].strip()
    parts = after_prefix.split()
    if not parts:
        return

    cmd = parts[0].lower()
    args = parts[1:]
    arg_text = after_prefix[len(cmd):].strip()

    async def reply(embed: discord.Embed, view: Optional[discord.ui.View] = None):
        if view is not None:
            await message.reply(embed=embed, view=view)
        else:
            await message.reply(embed=embed)

    # ---- Unknown command (no credits wasted on typos) ----
    known_commands = ALL_BOT_COMMANDS | FREE_COMMANDS | set(COMMAND_LEVELS.keys())
    if cmd not in known_commands:
        await reply(discord.Embed(
            title="❓ Unknown Command",
            description=(
                f"`{PREFIX}{cmd}` does not exist.\n"
                f"Use `{PREFIX}help` to see all available commands."
            ),
            color=0xF1C40F,
        ))
        return

    # ---- Guild-only check ----
    if cmd in GUILD_ONLY_COMMANDS and not message.guild:
        await reply(discord.Embed(
            title="❌ Server Only",
            description="This command can only be used inside a server.",
            color=EMBED_ERR,
        ))
        return

    # ---- Permission check (before charging credits) ----
    required_level = COMMAND_LEVELS.get(cmd, 0)
    user_level = get_permission_level(message.author)
    if user_level < required_level:
        level_names = {1: "Staff", 2: "Admin", 3: "CEO", 4: "Owner"}
        await reply(discord.Embed(
            title="🚫 Insufficient Permissions",
            description=f"This command requires the **{level_names[required_level]}** role or higher.",
            color=EMBED_ERR,
        ))
        return

    # ---- Credit gate ----
    ADMIN_MGMT_COMMANDS = {"genkey", "keys", "revoke", "givecredits", "addcredits", "givecredit", "addcredit"}
    if cmd in FREE_COMMANDS or cmd in ADMIN_MGMT_COMMANDS:
        paid = False
    else:
        if is_infinite_credits_user(message.author):
            paid = False  # unlimited credits for CEO & Owner
        else:
            if not credits_manager.use_credit(message.author.id, COMMAND_COST):
                await reply(build_insufficient_credits_embed())
                return
            paid = True

    guild = message.guild
    author = message.author

    # ========================================================
    # FREE: HELP
    # ========================================================
    if cmd in ("help", "h", "cmds", "commands"):
        await send_help(message)
        return

    # ========================================================
    # FREE: DAILY
    # ========================================================
    if cmd == "daily":
        if is_infinite_credits_user(author):
            embed = discord.Embed(
                title="👑 Infinite Credits",
                description="You have **unlimited credits** (CEO / Owner). No daily claim needed.",
                color=0xFFD700,
            )
            await reply(embed)
            return

        level = get_permission_level(author)

        # Admin+: +50 credits/day
        if level >= 2:
            ok, balance, remaining = credits_manager.claim_daily_regular(
                author.id, amount=DAILY_ADMIN_CREDITS
            )
            if ok:
                embed = discord.Embed(
                    title="🛡️ Admin Daily Claimed",
                    description=f"**+{DAILY_ADMIN_CREDITS} credits** • balance **{balance}**.",
                    color=EMBED_OK,
                )
            else:
                embed = discord.Embed(
                    title="⏰ Already Claimed",
                    description=(
                        f"Next claim in **{format_time_remaining(remaining)}**.\n"
                        f"Balance: **{balance} credits**."
                    ),
                    color=EMBED_WARN,
                )
            await reply(embed)
            return

        # Staff: +25 credits/day
        if level >= 1:
            ok, balance, remaining = credits_manager.claim_daily_regular(
                author.id, amount=DAILY_STAFF_CREDITS
            )
            if ok:
                embed = discord.Embed(
                    title="⚔️ Staff Daily Claimed",
                    description=f"**+{DAILY_STAFF_CREDITS} credits** • balance **{balance}**.",
                    color=EMBED_OK,
                )
            else:
                embed = discord.Embed(
                    title="⏰ Already Claimed",
                    description=(
                        f"Next claim in **{format_time_remaining(remaining)}**.\n"
                        f"Balance: **{balance} credits**."
                    ),
                    color=EMBED_WARN,
                )
            await reply(embed)
            return

        # Premium user: top up to cap
        if is_premium_user(author):
            ok, balance, remaining = credits_manager.claim_daily_premium(
                author.id, cap=DAILY_PREMIUM_CAP
            )
            if ok:
                embed = discord.Embed(
                    title="⭐ Premium Daily",
                    description=f"Balance topped up to **{balance} credits**.",
                    color=EMBED_OK,
                )
            else:
                embed = discord.Embed(
                    title="⏰ Already Claimed",
                    description=(
                        f"Next claim in **{format_time_remaining(remaining)}**.\n"
                        f"Balance: **{balance} credits**."
                    ),
                    color=EMBED_WARN,
                )
            await reply(embed)
            return

        # Regular user: +5 credits/day
        ok, balance, remaining = credits_manager.claim_daily_regular(
            author.id, amount=DAILY_REGULAR_CREDITS
        )
        if ok:
            embed = discord.Embed(
                title="🎁 Daily Claimed",
                description=(
                    f"**+{DAILY_REGULAR_CREDITS} credits** • "
                    f"balance **{balance}**."
                ),
                color=EMBED_OK,
            )
        else:
            embed = discord.Embed(
                title="⏰ Already Claimed",
                description=(
                    f"Next claim in **{format_time_remaining(remaining)}**.\n"
                    f"Balance: **{balance} credits**."
                ),
                color=EMBED_WARN,
            )
        await reply(embed)
        return

    # ========================================================
    # FREE: BALANCE
    # ========================================================
    if cmd in ("balance", "bal", "credits"):
        balance = credits_manager.get_credits(author.id)
        level = get_permission_level(author)
        if is_infinite_credits_user(author):
            status = "CEO / Owner (Infinite Credits)"
        elif level >= 2:
            status = f"Admin (+{DAILY_ADMIN_CREDITS}/day)"
        elif level >= 1:
            status = f"Staff (+{DAILY_STAFF_CREDITS}/day)"
        elif is_premium_user(author):
            status = f"Premium ({DAILY_PREMIUM_CAP}/day cap)"
        else:
            status = f"Regular (+{DAILY_REGULAR_CREDITS}/day)"
        await reply(discord.Embed(
            title="💳 Credits",
            description=f"**{balance}** • {status}",
            color=EMBED_MAIN,
        ))
        return

    # ========================================================
    # FREE: PING
    # ========================================================
    if cmd == "ping":
        embed = discord.Embed(
            title="🏓 Pong!",
            description=f"**Latency:** `{round(client.latency * 1000)}ms`",
            color=EMBED_OK,
        )
        await reply(embed)
        return

    # ========================================================
    # FREE: REDEEM
    # ========================================================
    if cmd == "redeem":
        key_arg = args[0].strip().upper() if args else ""
        if not key_arg:
            await reply(build_usage_embed("Redeem", f"{PREFIX}redeem PREM-XXXX-XXXX-XXXX"))
            return

        ok, msg = key_manager.redeem_key(key_arg, author.id)
        if not ok:
            await reply(discord.Embed(title="❌ Key Redeem Failed", description=msg, color=EMBED_ERR))
            return

        granted = await grant_premium_role(author.id, reason=f"Redeemed key {key_arg}")

        if granted or PREMIUM_ROLE_ID in get_member_role_ids(author):
            embed = discord.Embed(
                title="✅ Premium Role Granted",
                description=(
                    f"You redeemed `{key_arg}` and received the **<@&{PREMIUM_ROLE_ID}>** role!\n\n"
                    f"• Access to `{PREFIX}bypass` and `{PREFIX}imagine` is now unlocked.\n"
                    f"• `{PREFIX}daily` now tops you up to **{DAILY_PREMIUM_CAP} credits**."
                ),
                color=EMBED_OK,
            )
        else:
            embed = discord.Embed(
                title="⚠️ Key Redeemed (Role Warning)",
                description=(
                    f"Key `{key_arg}` was redeemed, but the **<@&{PREMIUM_ROLE_ID}>** role could not be assigned.\n"
                    f"Make sure you are in the server so the bot can assign you the Premium role."
                ),
                color=EMBED_WARN,
            )
        await reply(embed)
        return

    # ========================================================
    # FREE: AI CHAT
    # ========================================================
    if cmd == "ai":
        prompt = arg_text
        if prompt.lower() in ("reset", "clear", "forget"):
            ai_manager_client.reset_history(str(author.id))
            await reply(discord.Embed(
                title="🧠 Chat Reset",
                description="Your conversation history with Hollow Logger has been cleared.",
                color=EMBED_OK,
            ))
            return

        if not prompt:
            source_code, _ = await _extract_ai_source(message)
            if not source_code:
                await reply(build_usage_embed("AI", f"{PREFIX}ai <message>"))
                return

        await handle_ai_message(message, prompt)
        return

    # ========================================================
    # BEAUTIFY / FORMAT (USES WEB API UNDER THE HOOD)
    # ========================================================
    if cmd in ("beautify", "format", "pretty", "fmt"):
        async with message.channel.typing():
            code, original_filename = await extract_script_content(message)
            if not code or not code.strip():
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(discord.Embed(
                    title="❌ No Code Found",
                    description="Attach a file, paste a code block, send a link, or reply to a script.",
                    color=EMBED_ERR,
                ))
                return

            rename = bool(re.search(r"(?:^|\s)--?rename\b", arg_text, re.IGNORECASE))
            status_msg = await message.reply("⏳ Formatting & beautifying code...")

            formatted = await _beautify_source(code, rename=rename)
            ok = bool(formatted and formatted.strip())

            if not ok:
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                try:
                    await status_msg.delete()
                except Exception:
                    pass
                await reply(discord.Embed(
                    title="❌ Formatting Failed",
                    description="Could not format script. Credit refunded.",
                    color=EMBED_ERR,
                ))
                return

            send_filename = "formatted.lua"
            if original_filename:
                stem = os.path.splitext(original_filename)[0] or "formatted"
                send_filename = f"{_safe_filename(stem, 'formatted')}_formatted.lua"
            else:
                send_filename = _safe_filename(send_filename, "formatted.lua")

            data = formatted.encode("utf-8", errors="replace")
            embed = discord.Embed(
                title="✨ Code Formatted",
                description=(
                    f"**{len(data)} bytes** • **{len(formatted.splitlines())} lines**"
                    + (" • variable names inferred" if rename else "")
                ),
                color=EMBED_OK,
            )
            try:
                await status_msg.delete()
            except Exception:
                pass
            await message.reply(
                embed=embed,
                file=discord.File(io.BytesIO(data), filename=send_filename),
            )
        return

    # ========================================================
    # MINIFY / COMPRESS (DARKLUA)
    # ========================================================
    if cmd in ("minify", "mini", "compress", "min"):
        async with message.channel.typing():
            code, original_filename = await extract_script_content(message)
            if not code or not code.strip():
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(discord.Embed(
                    title="❌ No Code Found",
                    description="Attach a file, paste a code block, send a link, or reply to a script.",
                    color=EMBED_ERR,
                ))
                return

            original_size = len(code.encode("utf-8", errors="replace"))
            minified = await minify_lua_source(code)
            minified_bytes = minified.encode("utf-8", errors="replace")
            new_size = len(minified_bytes)

            saved_pct = 0.0
            if original_size > 0:
                saved_pct = max(0.0, ((original_size - new_size) / original_size) * 100.0)

            send_filename = "minified.lua"
            if original_filename:
                stem = os.path.splitext(original_filename)[0] or "minified"
                send_filename = f"{_safe_filename(stem, 'minified')}_min.lua"
            else:
                send_filename = _safe_filename(send_filename, "minified.lua")

            embed = discord.Embed(
                title="🗜️ Code Minified",
                description=(
                    f"**{original_size} bytes** ➔ **{new_size} bytes** "
                    f"({saved_pct:.1f}% reduction)"
                ),
                color=EMBED_OK,
            )
            embed.set_footer(text="Processed via Hollow Logger Engine")
            await message.reply(
                embed=embed,
                file=discord.File(io.BytesIO(minified_bytes), filename=send_filename),
            )
        return

    # ========================================================
    # FREE: IMAGINE / AI IMAGE GENERATION
    # ========================================================
    if cmd in ("imagine", "img", "image"):
        # Premium exclusive (Role ID: 1564136656729153647)
        if not (is_premium_user(author) or is_infinite_credits_user(author) or PREMIUM_ROLE_ID in get_member_role_ids(author)):
            await reply(discord.Embed(
                title="⭐ Premium Exclusive",
                description=(
                    f"The `{PREFIX}{cmd}` command is exclusive to **Premium members** (<@&{PREMIUM_ROLE_ID}>).\n\n"
                    f"**How to get Premium:**\n"
                    f"• Redeem a key: `{PREFIX}redeem <key>`\n"
                    f"• Buy Premium in <#1564146311291215902>"
                ),
                color=0xF1C40F,
            ))
            return

        prompt = arg_text.strip()
        if not prompt:
            await reply(build_usage_embed("Imagine", f"{PREFIX}{cmd} <prompt>"))
            return

        async with message.channel.typing():
            status_msg = await message.reply("🎨 *Evaluating prompt & generating image...*")
            image_bytes, err_reason = await generate_ai_image(prompt)
            if not image_bytes:
                await status_msg.edit(
                    content=None,
                    embed=discord.Embed(
                        title="❌ Generation Blocked / Failed",
                        description=err_reason or "Could not generate image. Please try a different prompt.",
                        color=EMBED_ERR,
                    ),
                )
                return

            filename = "hollow_imagine.png"
            embed = discord.Embed(
                title="🎨 AI Image Generated",
                description=f"**Prompt:** {prompt[:500]}",
                color=EMBED_OK,
            )
            embed.set_image(url=f"attachment://{filename}")
            embed.set_footer(text="Powered by Hollow Logger AI • System 1 Guarded")

            try:
                await status_msg.delete()
            except Exception:
                pass

            await message.reply(
                embed=embed,
                file=discord.File(io.BytesIO(image_bytes), filename=filename),
            )
        return

    # ========================================================
    # .BYPASS — SHORTENER / AD-LINK RESOLVER
    # ========================================================
    if cmd in ("bypass", "byp", "dlv", "unshorten"):
        # Premium exclusive (Role ID: 1564136656729153647)
        if not (is_premium_user(author) or is_owner_user(author) or PREMIUM_ROLE_ID in get_member_role_ids(author)):
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(
                title="⭐ Premium Exclusive",
                description=(
                    f"The `{PREFIX}{cmd}` command is exclusive to **Premium members** (<@&{PREMIUM_ROLE_ID}>).\n\n"
                    f"**How to get Premium:**\n"
                    f"• Redeem a key: `{PREFIX}redeem <key>`\n"
                    f"• Buy Premium in <#1564146311291215902>"
                ),
                color=0xF1C40F,
            ))
            return

        target_url = _first_url(arg_text)
        if not target_url and message.reference and message.reference.message_id:
            try:
                ref_msg = await message.channel.fetch_message(message.reference.message_id)
                target_url = _first_url(ref_msg.content)
                if not target_url and ref_msg.embeds:
                    for emb in ref_msg.embeds:
                        if emb.url:
                            target_url = _first_url(emb.url)
                            if target_url:
                                break
            except Exception:
                pass

        if not target_url:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Bypass", f"{PREFIX}{cmd} <url>"))
            return

        async with message.channel.typing():
            try:
                ok, result, provider = await unlink.bypass_url(target_url)
            except Exception as exc:
                print(f"[bypass] failed: {exc}")
                ok, result, provider = False, "The bypass service is unavailable right now.", ""

            if not ok:
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(discord.Embed(
                    title="❌ Bypass Failed",
                    description=(result or "That link could not be bypassed.") + "\nCredit refunded.",
                    color=EMBED_ERR,
                ))
                return

            direct = result if len(result) <= 3500 else result[:3500] + "…"
            original = target_url if len(target_url) <= 1000 else target_url[:1000] + "…"
            embed = discord.Embed(
                title="🔓 Link Bypassed",
                color=EMBED_OK,
            )

            is_key = direct.lower().startswith("key:") or direct.startswith("FREE_")
            view = None

            if is_key:
                clean_key = direct
                if clean_key.lower().startswith("key:"):
                    clean_key = clean_key[4:].strip()
                embed.description = "🔑 **Key obtained!** Click the button below to view it privately."
                embed.add_field(name="Type", value="`Key / Whitelist`", inline=True)
                view = KeyView(clean_key)
            else:
                embed.description = f"**Direct link:** {direct}"
                if direct.startswith(("http://", "https://")):
                    view = OpenLinkView(direct)

            embed.add_field(name="Original", value=original, inline=False)
            if provider:
                embed.set_footer(text=provider)

            await reply(embed, view=view)
        return

    # ========================================================
    # .L / .RECONSTRUCT / .DUMP — DUMPER & DEOBFUSCATOR
    # ========================================================
    if cmd in ("l", "deobf", "dump", "reconstruct", "rebuild"):
        rename_requested = "--rename" in args or cmd in ("reconstruct", "rebuild")
        async with message.channel.typing():
            script_content, original_filename = await extract_script_content(message)

            if not script_content or not script_content.strip():
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(discord.Embed(
                    title="❌ No Script Found",
                    description="Attach a file, paste a code block, send a link, or reply to a script.",
                    color=EMBED_ERR,
                ))
                return

            status_msg = await message.reply("⏳ Deobfuscating...")

            success, out_path, webhooks, error_msg, partial = await dump_script(
                script_content, author.id, original_filename or "script.lua", rename=rename_requested
            )

            if success and out_path and os.path.isfile(out_path):
                embed = discord.Embed(
                    title="✅ Deobfuscated",
                    description="Script dumped successfully. File attached.",
                    color=EMBED_OK,
                )

                if webhooks:
                    hooks = "\n".join(f"• `{h}`" for h in webhooks[:3])
                    if len(webhooks) > 3:
                        hooks += f"\n*+{len(webhooks) - 3} more*"
                    embed.add_field(
                        name="⚠️ Webhooks Found",
                        value=hooks,
                        inline=False,
                    )

                send_filename = "dumped.lua"
                if original_filename:
                    stem = os.path.splitext(original_filename)[0]
                    suffix = "_reconstructed.lua" if rename_requested else "_dumped.lua"
                    send_filename = f"{stem}{suffix}"

                try:
                    await status_msg.delete()
                except Exception:
                    pass
                await message.reply(embed=embed, file=discord.File(out_path, filename=send_filename))
                try:
                    os.remove(out_path)
                except Exception:
                    pass
                return

            # Failure → refund
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)

            try:
                await status_msg.delete()
            except Exception:
                pass

            await reply(discord.Embed(
                title="❌ Failed",
                description="Failed to deobfuscate script. Credit refunded.",
                color=EMBED_ERR,
            ))
            return

    # ========================================================
    # .DETECT — OBFUSCATOR DETECTION
    # ========================================================
    if cmd == "detect":
        async with message.channel.typing():
            script_content, filename = await extract_script_content(message)

            if not script_content or not script_content.strip():
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(discord.Embed(
                    title="❌ No Script Found",
                    description="Attach a file, paste a code block, send a link, or reply to a script.",
                    color=EMBED_ERR,
                ))
                return

            res = await asyncio.to_thread(classifier.detect_best, script_content)

            verdict = res.get("verdict", "Unknown")
            confidence = float(res.get("confidence", 0.0))
            display_name = res.get("display_name") or res.get("name") or verdict

            if confidence >= 80:
                color = EMBED_OK
            elif confidence >= 50:
                color = EMBED_INFO
            elif confidence >= 30:
                color = EMBED_WARN
            else:
                color = 0x95A5A6

            embed = discord.Embed(
                title="🔍 Obfuscator Detector",
                description=(
                    f"**Verdict:** `{verdict}`\n"
                    f"**Match:** {display_name} (`{confidence:.1f}%`)"
                ),
                color=color,
            )
            await reply(embed)
        return

    # ========================================================
    # .GET / .FETCH / .GETRAW
    # ========================================================
    if cmd in ("get", "fetch", "getraw"):
        target_url = None
        if args:
            target_url = args[0].strip()
        elif message.reference and message.reference.message_id:
            try:
                ref_msg = await message.channel.fetch_message(message.reference.message_id)
                m = re.search(r"https?://\S+", ref_msg.content)
                if m:
                    target_url = m.group(0).rstrip(")>\"'`;")
            except Exception:
                pass

        if not target_url or not target_url.startswith(("http://", "https://")):
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Get", f"{PREFIX}{cmd} https://example.com/script.lua"))
            return

        async with message.channel.typing():
            ok, data, status_code, reason = await fetch_roblox_url(target_url)
            if not ok or not data:
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(discord.Embed(
                    title="⚠️ Request Failed",
                    description=f"**Status:** `{status_code} {reason}`\nCredit refunded.",
                    color=EMBED_ERR,
                ))
                return
            filename = target_url.split("/")[-1].split("?")[0] or "fetched_script.lua"
            if not filename.endswith((".lua", ".luau", ".txt", ".json")):
                filename += ".lua"

            lines_count = len(data.split(b"\n"))
            embed = discord.Embed(
                title="🌐 Request Completed",
                description=(
                    f"`{status_code} OK` • `{len(data)} bytes` • {lines_count} lines"
                ),
                color=EMBED_OK,
            )
            await message.reply(embed=embed, file=discord.File(io.BytesIO(data), filename=filename))
        return

    # ========================================================
    # .GENKEY (CEO+)
    # ========================================================
    if cmd == "genkey":
        try:
            count = int(args[0]) if args else 1
        except ValueError:
            count = 1
        count = max(1, min(50, count))

        keys = key_manager.generate_keys(count, author.id)

        keys_text ="\n".join(f"`{k}`" for k in keys)

        embed = discord.Embed(
            title=f"🔑 {count} Premium Key(s)",
            description=f"```\n{chr(10).join(keys)}\n```",
            color=0xFFD700,
        )
        try:
            await author.send(embed=discord.Embed(
                title="🔑 Your Generated Keys",
                description=f"```\n{chr(10).join(keys)}\n```",
                color=0xFFD700,
            ))
        except Exception:
            pass
        if len(keys_text) < 1000:
            await reply(embed)
        else:
            await reply(discord.Embed(
                title="🔑 Keys Generated",
                description=f"**{count} keys generated** — they were sent to your DMs.",
                color=0xFFD700,
            ))
        return

    # ========================================================
    # .KEYS (CEO+)
    # ========================================================
    if cmd == "keys":
        stats = key_manager.get_stats()
        total = stats["total"]
        active = stats["active"]
        claimed = stats["claimed"]
        revoked = stats["revoked"]

        embed = discord.Embed(title="🔑 Key Statistics", color=0xFFD700)
        embed.add_field(name="Total", value=f"`{total}`", inline=True)
        embed.add_field(name="✅ Available", value=f"`{active}`", inline=True)
        embed.add_field(name="👥 Claimed", value=f"`{claimed}`", inline=True)
        embed.add_field(name="🚫 Revoked", value=f"`{revoked}`", inline=True)
        await reply(embed)
        return

    # ========================================================
    # .REVOKE (CEO+)
    # ========================================================
    if cmd == "revoke":
        target = args[0] if args else ""
        if not target:
            await reply(build_usage_embed("Revoke", f"{PREFIX}revoke PREM-XXXX-XXXX-XXXX | {PREFIX}revoke @user"))
            return

        # Revoke all keys of a user
        uid = parse_user_id(target)
        if uid:
            count = key_manager.revoke_user(uid)
            await remove_premium_from_user(uid, reason=f"Keys revoked by {author.id}")
            if count > 0:
                await reply(discord.Embed(
                    title="🚫 Keys Revoked",
                    description=f"Revoked **{count}** key(s) from <@{uid}> and removed the Premium role.",
                    color=EMBED_WARN,
                ))
            else:
                await reply(discord.Embed(
                    title="ℹ️ Nothing Found",
                    description=f"<@{uid}> has no active premium keys.",
                    color=EMBED_WARN,
                ))
            return

        # Revoke a single key
        ok, claimed_by = key_manager.revoke_key(target)
        if not ok:
            await reply(discord.Embed(
                title="❌ Key Not Found",
                description=f"The key `{target.upper()}` does not exist. Check the spelling.",
                color=EMBED_ERR,
            ))
            return

        if claimed_by:
            await remove_premium_from_user(int(claimed_by), reason=f"Key {target.upper()} revoked")
            await reply(discord.Embed(
                title="🚫 Key Revoked",
                description=(
                    f"Key `{target.upper()}` was revoked.\n"
                    f"Premium role removed from <@{claimed_by}>."
                ),
                color=EMBED_WARN,
            ))
        else:
            await reply(discord.Embed(
                title="🚫 Key Revoked",
                description=f"Key `{target.upper()}` was invalidated (it was unused).",
                color=EMBED_WARN,
            ))
        return

    # ========================================================
    # .GIVECREDITS (CEO+)
    # ========================================================
    if cmd in ("givecredits", "addcredits", "givecredit", "addcredit"):
        if len(args) < 2:
            await reply(build_usage_embed("Give Credits", f"{PREFIX}{cmd} <@user|id> <amount>"))
            return

        target_id = parse_user_id(args[0])
        if not target_id:
            await reply(discord.Embed(
                title="❌ Invalid User",
                description="Please mention a valid user or provide their numeric Discord ID.",
                color=EMBED_ERR,
            ))
            return

        try:
            amount = int(args[1])
            if amount <= 0:
                raise ValueError()
        except ValueError:
            await reply(discord.Embed(
                title="❌ Invalid Amount",
                description="Please specify a valid positive number of credits to give.",
                color=EMBED_ERR,
            ))
            return

        new_balance = credits_manager.add_credits(target_id, amount)

        embed = discord.Embed(
            title="💳 Credits Granted",
            description=f"Successfully granted **+{amount:,} credits** to <@{target_id}>.",
            color=0xFFD700,
        )
        embed.add_field(name="Target User", value=f"<@{target_id}> (`{target_id}`)", inline=True)
        embed.add_field(name="Amount Added", value=f"`+{amount:,}`", inline=True)
        embed.add_field(name="New Balance", value=f"`{new_balance:,} credits`", inline=True)
        embed.set_footer(text=f"Granted by {author.display_name} (CEO+)")

        await reply(embed)

        if guild:
            await log_event(
                guild,
                "💳 Credits Granted by CEO",
                (
                    f"**Target:** <@{target_id}> (`{target_id}`)\n"
                    f"**Amount:** `+{amount:,}`\n"
                    f"**New Balance:** `{new_balance:,}`\n"
                    f"**Moderator:** {author.mention} (`{author.id}`)"
                ),
                EMBED_OK,
            )
        return

    # ========================================================
    # MODERATION
    # ========================================================
    if not guild:
        # (Guild-only commands were already filtered above)
        await reply(discord.Embed(
            title="❌ Server Only",
            description="This command can only be used inside a server.",
            color=EMBED_ERR,
        ))
        return

    async def resolve_target(uargs, idx=0):
        uid = parse_user_id(uargs[idx]) if len(uargs) > idx else None
        if uid is None:
            return None, None
        member = guild.get_member(uid)
        return uid, member

    def target_protected(target_member, uid) -> str:
        """Returns a denial reason or '' if moderation is allowed."""
        if target_member:
            t_level = get_permission_level(target_member)
            if t_level >= user_level and user_level < 4:
                return "You cannot moderate someone with an equal or higher role."
        return ""

    async def bot_can_act(target_member) -> str:
        me = guild.me
        if target_member:
            if target_member.top_role >= me.top_role and target_member != me:
                return "My role is not high enough to moderate that member."
            if not guild.me.guild_permissions.moderate_members and not guild.me.guild_permissions.ban_members:
                return "I need the Moderate Members or Ban Members permission."
        return ""

    # ---- MUTE ----
    if cmd == "mute":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Mute", f"{PREFIX}mute @user [10m|1h|1d]"))
            return
        if target is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(
                title="❌ User Not Found",
                description="That user is not a member of this server.",
                color=EMBED_ERR,
            ))
            return
        reason = target_protected(target, uid)
        if reason:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(title="🚫 Action Denied", description=reason, color=EMBED_ERR))
            return
        bot_reason = await bot_can_act(target)
        if bot_reason:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(title="🚫 Bot Error", description=bot_reason, color=EMBED_ERR))
            return

        duration = 600
        if len(args) > 1:
            d = parse_duration(args[1])
            if d:
                duration = min(d, MAX_TIMEOUT)

        try:
            await target.timeout_for(datetime.timedelta(seconds=duration), reason=f"Muted by {author}")
            embed = discord.Embed(
                title="🔇 Member Muted",
                description=f"{target.mention} was muted by {author.mention}.",
                color=EMBED_OK,
            )
            embed.add_field(name="Duration", value=format_time_remaining(duration), inline=True)
            await reply(embed)
            await log_event(
                guild, "🔇 Mute",
                f"**Target:** {target.mention}\n**Moderator:** {author.mention}\n**Duration:** {format_time_remaining(duration)}",
                EMBED_WARN,
            )
        except Exception as e:
            await reply(discord.Embed(title="❌ Mute Failed", description=f"`{e}`", color=EMBED_ERR))
        return

    # ---- UNMUTE ----
    if cmd == "unmute":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Unmute", f"{PREFIX}unmute @user"))
            return
        if target is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(
                title="❌ User Not Found",
                description="That user is not a member of this server.",
                color=EMBED_ERR,
            ))
            return
        try:
            await target.timeout(None, reason=f"Unmuted by {author}")
            embed = discord.Embed(
                title="🔊 Member Unmuted",
                description=f"{target.mention} was unmuted by {author.mention}.",
                color=EMBED_OK,
            )
            await reply(embed)
            await log_event(
                guild, "🔊 Unmute",
                f"**Target:** {target.mention}\n**Moderator:** {author.mention}",
                EMBED_OK,
            )
        except Exception as e:
            await reply(discord.Embed(title="❌ Unmute Failed", description=f"`{e}`", color=EMBED_ERR))
        return

    # ---- WARN ----
    if cmd == "warn":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Warn", f"{PREFIX}warn @user <reason>"))
            return
        reason = " ".join(parts[2:]) if len(parts) > 2 else ""
        if not reason:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Warn", f"{PREFIX}warn @user <reason>"))
            return

        count = warnings_manager.add_warning(uid, author.id, reason)
        embed = discord.Embed(
            title="⚠️ User Warned",
            description=f"{target.mention if target else f'<@{uid}>'} was warned by {author.mention}.",
            color=EMBED_WARN,
        )
        embed.add_field(name="Reason", value=reason, inline=False)
        embed.add_field(name="Total Warnings", value=f"`{count}`", inline=True)
        await reply(embed)

        try:
            if target:
                await target.send(embed=discord.Embed(
                    title=f"⚠️ You were warned in {guild.name}",
                    description=f"**Reason:** {reason}",
                    color=EMBED_WARN,
                ))
        except Exception:
            pass
        await log_event(
            guild, "⚠️ Warn",
            f"**Target:** <@{uid}>\n**Moderator:** {author.mention}\n**Reason:** {reason}",
            EMBED_WARN,
        )
        return

    # ---- WARNINGS ----
    if cmd == "warnings":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Warnings", f"{PREFIX}warnings @user"))
            return
        user_warnings = warnings_manager.get_warnings(uid)
        if not user_warnings:
            await reply(discord.Embed(
                title="✅ No Warnings",
                description=f"<@{uid}> has a clean record.",
                color=EMBED_OK,
            ))
            return
        listing = []
        for i, w in enumerate(user_warnings, start=1):
            ts = datetime.datetime.fromtimestamp(w.get("timestamp", 0)).strftime("%Y-%m-%d %H:%M")
            listing.append(
                f"**#{i}** • <@{w.get('moderator_id')}> • `{ts}`\n> {w.get('reason', 'Unknown')}"
            )
        text = "\n".join(listing)
        if len(text) > 3800:
            text = text[:3800] + "\n... (truncated)"
        embed = discord.Embed(
            title=f"⚠️ Warnings — <@{uid}>",
            description=text,
            color=EMBED_WARN,
        )
        embed.add_field(name="Total", value=f"`{len(user_warnings)}`", inline=True)
        await reply(embed)
        return

    # ---- CLEARWARNINGS ----
    if cmd == "clearwarnings":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Clear Warnings", f"{PREFIX}clearwarnings @user"))
            return
        count = warnings_manager.clear_warnings(uid)
        embed = discord.Embed(
            title="✅ Warnings Cleared",
            description=f"Cleared **{count}** warning(s) from <@{uid}>.",
            color=EMBED_OK,
        )
        await reply(embed)
        return

    # ---- BAN ----
    if cmd == "ban":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Ban", f"{PREFIX}ban @user <reason>"))
            return
        reason = " ".join(parts[2:]) if len(parts) > 2 else "No reason provided."
        protection = target_protected(target, uid)
        if protection:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(title="🚫 Action Denied", description=protection, color=EMBED_ERR))
            return

        try:
            if target:
                bot_error = await bot_can_act(target)  # check hierarchy
                if bot_error:
                    if paid:
                        credits_manager.refund_credit(author.id, COMMAND_COST)
                    await reply(discord.Embed(title="🚫 Bot Error", description=bot_error, color=EMBED_ERR))
                    return
                try:
                    await target.send(embed=discord.Embed(
                        title=f"🔨 You were banned from {guild.name}",
                        description=f"**Reason:** {reason}",
                        color=EMBED_ERR,
                    ))
                except Exception:
                    pass
                reason_full = f"{reason} — by {author}"
                if guild.me.guild_permissions.ban_members:
                    await target.ban(reason=reason_full, delete_message_days=0)
                else:
                    await reply(discord.Embed(
                        title="❌ Missing Permission",
                        description="I need the **Ban Members** permission.",
                        color=EMBED_ERR,
                    ))
                    return
            else:
                # Ban by user ID (not in server)
                if not guild.me.guild_permissions.ban_members:
                    await reply(discord.Embed(
                        title="❌ Missing Permission",
                        description="I need the **Ban Members** permission.",
                        color=EMBED_ERR,
                    ))
                    return
                await guild.ban(discord.Object(id=uid), reason=f"{reason} — by {author}", delete_message_days=0)

            embed = discord.Embed(
                title="🔨 Member Banned",
                description=f"<@{uid}> was banned by {author.mention}.",
                color=EMBED_ERR,
            )
            embed.add_field(name="Reason", value=reason, inline=False)
            await reply(embed)
            await log_event(
                guild, "🔨 Ban",
                f"**Target:** <@{uid}>\n**Moderator:** {author.mention}\n**Reason:** {reason}",
                EMBED_ERR,
            )
        except Exception as e:
            await reply(discord.Embed(title="❌ Ban Failed", description=f"`{e}`", color=EMBED_ERR))
        return

    # ---- KICK ----
    if cmd == "kick":
        uid, target = await resolve_target(args)
        if uid is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Kick", f"{PREFIX}kick @user <reason>"))
            return
        reason = " ".join(parts[2:]) if len(parts) > 2 else "No reason provided."
        if target is None:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(
                title="❌ User Not Found",
                description="That user is not a member of this server.",
                color=EMBED_ERR,
            ))
            return
        protection = target_protected(target, uid)
        if protection:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(title="🚫 Action Denied", description=protection, color=EMBED_ERR))
            return
        bot_error = await bot_can_act(target)
        if bot_error:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(title="🚫 Bot Error", description=bot_error, color=EMBED_ERR))
            return
        if not guild.me.guild_permissions.kick_members:
            await reply(discord.Embed(
                title="❌ Missing Permission",
                description="I need the **Kick Members** permission.",
                color=EMBED_ERR,
            ))
            return
        try:
            try:
                await target.send(embed=discord.Embed(
                    title=f"👢 You were kicked from {guild.name}",
                    description=f"**Reason:** {reason}",
                    color=EMBED_WARN,
                ))
            except Exception:
                pass
            await target.kick(reason=f"{reason} — by {author}")
            embed = discord.Embed(
                title="👢 Member Kicked",
                description=f"{target.mention} was kicked by {author.mention}.",
                color=EMBED_WARN,
            )
            embed.add_field(name="Reason", value=reason, inline=False)
            await reply(embed)
            await log_event(
                guild, "👢 Kick",
                f"**Target:** {target.mention}\n**Moderator:** {author.mention}\n**Reason:** {reason}",
                EMBED_WARN,
            )
        except Exception as e:
            await reply(discord.Embed(title="❌ Kick Failed", description=f"`{e}`", color=EMBED_ERR))
        return

    # ---- CLEAR / PURGE ----
    if cmd in ("clear", "purge"):
        try:
            count = max(1, min(100, int(args[0]))) if args else 0
        except ValueError:
            count = 0
        if count == 0:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Clear", f"{PREFIX}clear <1-100>"))
            return
        if not guild.me.guild_permissions.manage_messages:
            await reply(discord.Embed(
                title="❌ Missing Permission",
                description="I need the **Manage Messages** permission.",
                color=EMBED_ERR,
            ))
            return
        try:
            deleted = await message.channel.purge(limit=count)
            confirm = await message.channel.send(
                embed=discord.Embed(
                    title="🧹 Messages Cleared",
                    description=f"Deleted **{len(deleted)}** message(s).",
                    color=EMBED_OK,
                )
            )
            await asyncio.sleep(4)
            try:
                await confirm.delete()
            except Exception:
                pass
        except Exception as e:
            await reply(discord.Embed(title="❌ Clear Failed", description=f"`{e}`", color=EMBED_ERR))
        return

    # ---- SLOWMODE ----
    if cmd == "slowmode":
        raw = args[0].lower() if args else ""
        if raw in ("off", "0"):
            seconds = 0
        else:
            try:
                seconds = max(0, min(21600, int(raw)))
            except (ValueError, TypeError):
                if paid:
                    credits_manager.refund_credit(author.id, COMMAND_COST)
                await reply(build_usage_embed("Slowmode", f"{PREFIX}slowmode <0-21600 seconds | off>"))
                return
        channel = message.channel
        await channel.edit(slowmode=seconds, reason=f"Slowmode by {author}")
        embed = discord.Embed(
            title="🐢 Slowmode Updated",
            description=f"Channel slowmode is now **{seconds} seconds**." + (" (off)" if seconds == 0 else ""),
            color=EMBED_OK,
        )
        await reply(embed)
        return

    # ---- LOCK / UNLOCK ----
    if cmd in ("lock", "unlock"):
        channel = message.channel
        is_lock = cmd == "lock"
        reason_text = " ".join(args) or ("Locked" if is_lock else "Unlocked")
        try:
            await channel.set_permissions(
                guild.default_role,
                send_messages=False if is_lock else None,
                reason=f"{reason_text} — by {author}",
            )
            embed = discord.Embed(
                title="🔒 Channel Locked" if is_lock else "🔓 Channel Unlocked",
                description=(
                    f"{channel.mention} is now **locked**. Members cannot send messages."
                    if is_lock else
                    f"{channel.mention} is now **unlocked**. Members can send messages again."
                ),
                color=EMBED_ERR if is_lock else EMBED_OK,
            )
            embed.add_field(name="By", value=author.mention, inline=True)
            embed.add_field(name="Reason", value=reason_text, inline=True)
            await reply(embed)
            await log_event(
                guild,
                "🔒 Lock" if is_lock else "🔓 Unlock",
                f"**Channel:** {channel.mention}\n**Moderator:** {author.mention}\n**Reason:** {reason_text}",
                EMBED_WARN,
            )
        except Exception as e:
            await reply(discord.Embed(title=f"❌ {cmd.capitalize()} Failed", description=f"`{e}`", color=EMBED_ERR))
        return

    # ========================================================
    # ANTIRAID CONFIG (Admin+)
    # ========================================================
    if cmd == "antiraid":
        sub = args[0].lower() if args else "status"

        if sub == "status":
            cfg = antiraid_manager.config
            log_id = cfg.get("log_channel_id")
            log_mention = f"<#{log_id}>" if log_id else "`not set`"
            embed = discord.Embed(
                title="🛡️ Anti-Raid Status",
                color=EMBED_OK if cfg.get("enabled") else EMBED_ERR,
            )
            embed.add_field(name="Enabled", value=f"`{bool(cfg.get('enabled'))}`", inline=True)
            embed.add_field(name="Action", value=f"`{cfg.get('action', 'timeout')}`", inline=True)
            embed.add_field(name="Max Joins/min", value=f"`{cfg.get('max_joins_per_minute', 8)}`", inline=True)
            embed.add_field(name="Anti Invite", value=f"`{bool(cfg.get('anti_invite'))}`", inline=True)
            embed.add_field(name="Anti Spam", value=f"`{bool(cfg.get('anti_spam'))}`", inline=True)
            embed.add_field(name="Max Mentions", value=f"`{cfg.get('max_mentions', 5)}`", inline=True)
            embed.add_field(name="Mass Mention Guard", value=f"`{bool(cfg.get('anti_mass_mention'))}`", inline=True)
            embed.add_field(name="Auto Role", value=f"`{bool(cfg.get('auto_role'))}`", inline=True)
            embed.add_field(name="Log Channel", value=log_mention, inline=True)
            await reply(embed)
            return

        if sub in ("on", "off"):
            antiraid_manager.set("enabled", sub == "on")
            await reply(discord.Embed(
                title="🛡️ Anti-Raid Updated",
                description=f"Anti-raid is now **{'ON' if sub == 'on' else 'OFF'}**.",
                color=EMBED_OK if sub == "on" else EMBED_ERR,
            ))
            return

        if sub == "joins":
            if not args[1:]:
                await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid joins <number>"))
                return
            try:
                value = max(2, min(200, int(args[1])))
            except ValueError:
                await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid joins <number>"))
                return
            antiraid_manager.set("max_joins_per_minute", value)
            await reply(discord.Embed(
                title="🛡️ Anti-Raid Updated",
                description=f"Max joins per minute set to **{value}**.",
                color=EMBED_OK,
            ))
            return

        if sub == "action":
            if not args[1:] or args[1].lower() not in ("timeout", "kick", "ban"):
                await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid action <timeout|kick|ban>"))
                return
            value = args[1].lower()
            antiraid_manager.set("action", value)
            await reply(discord.Embed(
                title="🛡️ Anti-Raid Updated",
                description=f"Raid action set to **{value}**.",
                color=EMBED_OK,
            ))
            return

        toggles = {
            "invite": "anti_invite",
            "spam": "anti_spam",
            "mention": "anti_mass_mention",
            "autorole": "auto_role",
        }
        if sub in toggles:
            if not args[1:]:
                await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid {sub} <on|off>"))
                return
            value = parse_bool_arg(args[1])
            if value is None:
                await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid {sub} <on|off>"))
                return
            antiraid_manager.set(toggles[sub], value)
            await reply(discord.Embed(
                title="🛡️ Anti-Raid Updated",
                description=f"`{toggles[sub]}` is now **{'ON' if value else 'OFF'}**.",
                color=EMBED_OK,
            ))
            return

        if sub == "mention":
            if len(args) > 1 and parse_bool_arg(args[1]) is not None:
                value = parse_bool_arg(args[1])
                antiraid_manager.set("anti_mass_mention", value)
                if len(args) > 2:
                    try:
                        antiraid_manager.set("max_mentions", max(2, min(50, int(args[2]))))
                    except ValueError:
                        pass
                m_state = "**ON**" if value else "**OFF**"
                await reply(discord.Embed(
                    title="🛡️ Anti-Raid Updated",
                    description=f"Mass mention guard: {m_state} • Max mentions: `{antiraid_manager.get('max_mentions', 5)}`",
                    color=EMBED_OK,
                ))
                return
            if len(args) > 1:
                try:
                    antiraid_manager.set("max_mentions", max(2, min(50, int(args[1]))))
                    await reply(discord.Embed(
                        title="🛡️ Anti-Raid Updated",
                        description=f"Max mentions set to **{args[1]}**.",
                        color=EMBED_OK,
                    ))
                    return
                except ValueError:
                    pass
            await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid mention <on|off> [max]"))
            return

        if sub == "log":
            if not args[1:]:
                await reply(build_usage_embed("Anti-Raid", f"{PREFIX}antiraid log <#channel|off>"))
                return
            if args[1].lower() == "off":
                antiraid_manager.set("log_channel_id", None)
                await reply(discord.Embed(
                    title="🛡️ Anti-Raid Updated",
                    description="Log channel **disabled**.",
                    color=EMBED_OK,
                ))
                return
            m = re.match(r"^(?:<#)?(\d{17,20})>?$", args[1])
            channel_id = int(m.group(1)) if m else None
            channel = guild.get_channel(channel_id) if channel_id else None
            if not channel or not isinstance(channel, discord.TextChannel):
                await reply(discord.Embed(
                    title="❌ Channel Not Found",
                    description="Mention a valid text channel: `.antiraid log #channel`.",
                    color=EMBED_ERR,
                ))
                return
            antiraid_manager.set("log_channel_id", channel.id)
            await reply(discord.Embed(
                title="🛡️ Anti-Raid Updated",
                description=f"Log channel set to {channel.mention}.",
                color=EMBED_OK,
            ))
            return

        await reply(build_usage_embed(
            "Anti-Raid",
            f"{PREFIX}antiraid status|on|off|joins <n>|action <timeout|kick|ban>|invite|spam|mention|autorole|log",
        ))
        return

    # ========================================================
    # ANNOUNCE (Admin+)
    # ========================================================
    if cmd == "announce":
        text = arg_text
        target_channel = message.channel
        m = re.match(r"^<#(\d{17,20})>\s*", text)
        if m:
            ch = guild.get_channel(int(m.group(1)))
            if ch and isinstance(ch, discord.TextChannel):
                target_channel = ch
                text = text[m.end():]

        rest = text.split("|", 1)
        if len(rest) == 2:
            title, body = rest[0].strip(), rest[1].strip()
        else:
            title, body = "📢 Announcement", text.strip()

        if not body:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Announce", f"{PREFIX}announce [#channel] <title> | <message>"))
            return

        embed = discord.Embed(
            title=title or "📢 Announcement",
            description=body,
            color=EMBED_INFO,
        )
        embed.set_author(name=guild.name, icon_url=guild.icon.url if guild.icon else None)
        embed.set_footer(text=f"Announced by {author.display_name}")
        await target_channel.send(embed=embed)
        if target_channel.id != message.channel.id:
            await reply(discord.Embed(
                title="✅ Announcement Sent",
                description=f"Published in {target_channel.mention}.",
                color=EMBED_OK,
            ))
        return

    # ========================================================
    # GIVEAWAYS (Admin+)
    # ========================================================
    if cmd == "gstart":
        # .gstart <winners> <duration> <prize...>
        if len(args) < 3:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Giveaway", f"{PREFIX}gstart <winners> <duration> <prize> | e.g. .gstart 2 1h 50 credits"))
            return
        try:
            winners = max(1, min(20, int(args[0])))
        except ValueError:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Giveaway", f"{PREFIX}gstart <winners> <duration> <prize>"))
            return

        duration = parse_duration(args[1])
        if not duration or duration < 5 or duration > 7 * 86400:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(discord.Embed(
                title="❌ Invalid Duration",
                description="Use formats like `10m`, `2h`, `1d` (min 5s, max 7d).",
                color=EMBED_ERR,
            ))
            return

        prize = " ".join(args[2:])
        end_time = time.time() + duration
        end_ts = int(end_time)

        embed = discord.Embed(
            title="🎉 GIVEAWAY",
            description=(
                f"**Prize:** {prize}\n"
                f"**Winners:** {winners}\n"
                f"**Ends:** <t:{end_ts}:R> (<t:{end_ts}:F>)\n\n"
                f"React with 🎉 to participate!"
            ),
            color=0xFF69B4,
        )
        embed.set_footer(text=f"Hosted by {author.display_name} • Ends {format_time_remaining(duration)} from now")
        gw_message = await message.channel.send(embed=embed)
        try:
            await gw_message.add_reaction("🎉")
        except Exception:
            pass

        giveaway_manager.create_giveaway(
            gw_message.id, message.channel.id, guild.id, author.id, prize, winners, end_time
        )
        await reply(discord.Embed(
            title="✅ Giveaway Started",
            description=f"Running in {message.channel.mention} — giveaway ID `{gw_message.id}`.",
            color=EMBED_OK,
        ))
        return

    if cmd == "greroll":
        raw = args[0] if args else ""
        if not raw:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Reroll", f"{PREFIX}greroll <message_id or link>"))
            return
        m = re.search(r"(\d{17,20})", raw)
        gid = int(m.group(1)) if m else None
        gw = giveaway_manager.get_giveaway(gid) if gid else None
        if not gw or not gw.get("ended"):
            await reply(discord.Embed(
                title="❌ Giveaway Not Found",
                description="That giveaway does not exist or has not ended yet.",
                color=EMBED_ERR,
            ))
            return

        channel = client.get_channel(int(gw.get("channel_id", 0)))
        if not channel:
            await reply(discord.Embed(
                title="❌ Channel Not Found",
                description="The giveaway channel is no longer available.",
                color=EMBED_ERR,
            ))
            return

        message_obj = await fetch_giveaway_message(channel, gid)
        if not message_obj:
            await reply(discord.Embed(
                title="❌ Message Not Found",
                description="The giveaway message was deleted.",
                color=EMBED_ERR,
            ))
            return

        participants = await collect_participants(message_obj, exclude_ids=gw.get("winner_ids", []))
        winners_count = max(1, int(gw.get("winners", 1)))

        if not participants:
            await reply(discord.Embed(
                title="❌ No Participants",
                description="There are no new valid participants to reroll.",
                color=EMBED_ERR,
            ))
            return

        chosen = random.sample(participants, min(winners_count, len(participants)))
        winner_ids = [u.id for u in chosen]
        giveaway_manager.end_giveaway(gid, winner_ids)
        winner_text = " ".join(u.mention for u in chosen)

        try:
            embed = discord.Embed(
                title="🎉 GIVEAWAY REROLLED",
                description=(
                    f"**Prize:** {gw.get('prize')}\n"
                    f"**New winners ({len(chosen)}):** {winner_text}\n\n"
                    f"Congratulations! 🎊"
                ),
                color=0xFF69B4,
            )
            await message_obj.edit(embed=embed)
        except Exception:
            pass

        try:
            await channel.send(f"🎊 {winner_text} — you won **{gw.get('prize')}**! (reroll)")
        except Exception:
            pass
        await reply(discord.Embed(
            title="✅ Giveaway Rerolled",
            description=f"Winners for giveaway `{gid}`: {winner_text}",
            color=EMBED_OK,
        ))
        return

    # ========================================================
    # UTILITY
    # ========================================================
    if cmd == "userinfo":
        uid, target = await resolve_target(args)
        if target is None and message.mentions:
            target = message.mentions[0]
        if target:
            member = target
        else:
            # target is the author itself
            member = author if isinstance(author, discord.Member) else None
            uid = author.id

        if not member or not isinstance(member, discord.Member):
            await reply(discord.Embed(
                title="ℹ️ User Info",
                description=(f"**User:** <@{uid or author.id}>\n**ID:** `{uid or author.id}`"),
                color=EMBED_MAIN,
            ))
            return

        roles_list = [r.mention for r in member.roles if r != guild.default_role][-15:]
        balance = "Unlimited" if is_infinite_credits_user(member) else str(credits_manager.get_credits(member.id))
        embed = discord.Embed(
            title=f"👤 {member.display_name}",
            color=member.color if member.color and member.color.value else EMBED_MAIN,
        )
        embed.set_thumbnail(url=member.display_avatar.url)
        embed.add_field(name="Username", value=f"`{member.name}`", inline=True)
        embed.add_field(name="ID", value=f"`{member.id}`", inline=True)
        embed.add_field(name="Bot", value=f"`{member.bot}`", inline=True)
        embed.add_field(
            name="Account Created",
            value=f"<t:{int(member.created_at.timestamp())}:R>",
            inline=True,
        )
        embed.add_field(
            name="Joined Server",
            value=f"<t:{int(member.joined_at.timestamp())}:R>" if member.joined_at else "Unknown",
            inline=True,
        )
        embed.add_field(name="Credits", value=f"`{balance}`", inline=True)
        warn_count = len(warnings_manager.get_warnings(member.id))
        embed.add_field(name="Warnings", value=f"`{warn_count}`", inline=True)
        if member.top_role:
            embed.add_field(name="Top Role", value=member.top_role.mention, inline=True)
        if roles_list:
            embed.add_field(name=f"Roles ({len(member.roles) - 1})", value=" ".join(roles_list), inline=False)
        await reply(embed)
        return

    if cmd == "serverinfo":
        online = sum(1 for m in guild.members if m.status in (discord.Status.online, discord.Status.idle, discord.Status.dnd))
        bots = sum(1 for m in guild.members if m.bot)
        embed = discord.Embed(
            title=f"🏠 {guild.name}",
            description=guild.description or "",
            color=EMBED_MAIN,
        )
        if guild.icon:
            embed.set_thumbnail(url=guild.icon.url)
        embed.add_field(name="Owner", value=f"<@{guild.owner_id}>", inline=True)
        embed.add_field(name="Members", value=f"`{guild.member_count}`", inline=True)
        embed.add_field(name="Online", value=f"`{online}`", inline=True)
        embed.add_field(name="Bots", value=f"`{bots}`", inline=True)
        embed.add_field(name="Channels", value=f"`{len(guild.text_channels)}` text / `{len(guild.voice_channels)}` voice", inline=True)
        embed.add_field(name="Roles", value=f"`{len(guild.roles)}`", inline=True)
        embed.add_field(name="Boosts", value=f"`{guild.premium_tier}` (Lvl) • `{guild.premium_subscription_count}`", inline=True)
        embed.add_field(
            name="Created",
            value=f"<t:{int(guild.created_at.timestamp())}:R>",
            inline=True,
        )
        embed.add_field(name="Members Role", value=f"<@&{MEMBER_ROLE_ID}>", inline=True)
        await reply(embed)
        return

    if cmd == "avatar":
        uid, target = await resolve_target(args)
        target = target or author
        embed = discord.Embed(
            title=f"🖼️ Avatar — {target.display_name}",
            color=EMBED_MAIN,
        )
        embed.set_image(url=target.display_avatar.url)
        await reply(embed)
        return

    if cmd == "say":
        text = arg_text
        if not text:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Say", f"{PREFIX}say <text>"))
            return
        await message.channel.send(text)
        try:
            await message.delete()
        except Exception:
            pass
        return

    if cmd == "embed":
        text = arg_text
        rest = text.split("|", 1)
        if len(rest) == 2:
            title, body = rest[0].strip(), rest[1].strip()
        else:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Embed", f"{PREFIX}embed <title> | <text>"))
            return
        embed = discord.Embed(
            title=title,
            description=body,
            color=discord.Colour.random(),
        )
        await message.channel.send(embed=embed)
        try:
            await message.delete()
        except Exception:
            pass
        return

    if cmd == "poll":
        question = arg_text
        if not question:
            if paid:
                credits_manager.refund_credit(author.id, COMMAND_COST)
            await reply(build_usage_embed("Poll", f"{PREFIX}poll <question>"))
            return
        embed = discord.Embed(
            title="📊 Poll",
            description=question,
            color=EMBED_INFO,
        )
        embed.set_footer(text=f"Poll by {author.display_name} • Vote with 👍 / 👎")
        poll_msg = await message.channel.send(embed=embed)
        try:
            await poll_msg.add_reaction("👍")
            await poll_msg.add_reaction("👎")
        except Exception:
            pass
        try:
            await message.delete()
        except Exception:
            pass
        return

    # ========================================================
    # FALLBACK (should not happen)
    # ========================================================
    await reply(build_usage_embed("Help", f"{PREFIX}help"))


if __name__ == "__main__":
    try:
        client.run(DISCORD_TOKEN)
    except Exception as e:
        print(f"[FATAL] Error starting the bot: {e}")
