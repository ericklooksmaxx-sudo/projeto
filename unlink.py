"""Bypass resolver using Galaxy Resolver and dedicated PlatoRelay provider.

Footer: "Powered by Galatic & Hollow Bypasser"
"""

from __future__ import annotations

import base64
import json
import os
import re
import time
from typing import Optional, Tuple
from urllib.parse import parse_qs, unquote, urlparse

import aiohttp

FOOTER_LABEL = "Powered by Galatic & Hollow Bypasser"
GALACTIC_ENDPOINT = "https://galactic-bypass.vercel.app/api/bypass"

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"
)

LINKVERTISE_HOSTS = {
    "linkvertise.com",
    "www.linkvertise.com",
    "linkvertise.net",
    "www.linkvertise.net",
    "link-to.net",
    "link-target.net",
    "link-center.net",
    "link-hub.net",
    "direct-link.net",
    "file-link.net",
    "linkvertise.download",
    "up-to-down.net",
}


def _valid_http_url(value: str) -> bool:
    try:
        parsed = urlparse(value)
        return parsed.scheme in ("http", "https") and bool(parsed.netloc)
    except Exception:
        return False


def normalize_input_url(text: str) -> Optional[str]:
    """Extract and normalize URL from user message, handling markdown, brackets, or missing protocol."""
    if not text:
        return None
    text = text.strip()
    match = re.search(r"https?://[^\s<>\"'`]+", text)
    if match:
        return match.group(0).rstrip(")>\"'`;,.")

    clean = text.strip(" <>\"'`").rstrip(")>\"'`;,.")
    match2 = re.search(r"\b((?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:/[^\s<>\"'`]*)?)", clean)
    if match2:
        candidate = match2.group(1).rstrip(")>\"'`;,.")
        return "https://" + candidate

    return None


def _local_decode(url: str) -> Optional[str]:
    """Local parameter decoding for links that embed their destination."""
    try:
        parsed = urlparse(url)
        host = parsed.netloc.lower()
        query = parse_qs(parsed.query)

        # Linkvertise ?r=
        if any(h in host for h in ("linkvertise", "link-to", "link-target", "direct-link")):
            raw = (query.get("r") or [None])[0]
            if raw:
                try:
                    raw = unquote(raw)
                    padding = "=" * (-len(raw) % 4)
                    decoded = base64.b64decode(raw + padding, validate=False).decode("utf-8", "replace")
                    decoded = unquote(decoded).strip()
                    if _valid_http_url(decoded):
                        return decoded
                except Exception:
                    pass

        # Delta ?URL= / ?url=
        if "delta" in host or "platoboost" in host:
            raw = (query.get("URL") or query.get("url") or [None])[0]
            if raw:
                raw = unquote(raw)
                if _valid_http_url(raw):
                    return raw

        # Short Jambo ?url=
        if "short-jambo.com" in host:
            raw = (query.get("url") or [None])[0]
            if raw and _valid_http_url(raw):
                return raw

        # Pastebin direct raw
        if host == "pastebin.com":
            m = re.match(r"^/([A-Za-z0-9]{4,})$", parsed.path)
            if m and m.group(1).lower() != "raw":
                return f"https://pastebin.com/raw/{m.group(1)}"

        # Rentry direct raw
        if host in ("rentry.co", "rentry.org"):
            m = re.match(r"^/([A-Za-z0-9_-]{2,})$", parsed.path)
            if m and not m.group(1).endswith("/raw"):
                return f"https://rentry.co/{m.group(1)}/raw"

    except Exception:
        pass
    return None


async def _resolve_platorelay(session: aiohttp.ClientSession, url: str) -> Tuple[bool, str]:
    """Dedicated solver specifically for auth.platorelay.com and auth.platoboost.app."""
    parsed = urlparse(url)
    q = parse_qs(parsed.query)
    ticket = q.get("d", [None])[0]
    if not ticket:
        parts = [part for part in parsed.path.split("/") if part and part != "a"]
        if parts:
            ticket = parts[0]
    if not ticket:
        return False, "Could not extract a valid ticket from the PlatoRelay link."

    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Client-Name": "platoboost webclient",
        "X-Client-Version": "5.3.2",
        "Referer": f"https://auth.platorelay.com/{ticket}/",
    }

    # 1. Query status
    for host in ("https://auth.platorelay.com", "https://auth.platoboost.app"):
        status_url = f"{host}/api/session/status?ticket={ticket}"
        try:
            async with session.get(status_url, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json(content_type=None)
                    if isinstance(data, dict):
                        key = data.get("data", {}).get("key") if isinstance(data.get("data"), dict) else None
                        if key and key != "KEY_NOT_FOUND":
                            return True, f"Key: {key}"
                        redir = data.get("data", {}).get("url") or data.get("redirect")
                        if redir and str(redir).startswith("http"):
                            return True, str(redir).strip()
        except Exception as e:
            print(f"[platorelay-status] {host} err: {e}")

    # 2. Query session step
    for svc in (1, 2):
        step_url = f"https://auth.platorelay.com/api/session/step?ticket={ticket}&service={svc}"
        payload = {"captcha": None, "reference": "empty", "payload": "empty", "meta": "empty"}
        try:
            async with session.put(step_url, json=payload, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json(content_type=None)
                    if isinstance(data, dict):
                        key = data.get("data", {}).get("key") if isinstance(data.get("data"), dict) else None
                        if key and key != "KEY_NOT_FOUND":
                            return True, f"Key: {key}"
                        dest = data.get("data", {}).get("url") or data.get("redirect")
                        if dest and str(dest).startswith("http"):
                            return True, str(dest).strip()
        except Exception as e:
            print(f"[platorelay-step] svc={svc} err: {e}")

    return False, "This PlatoRelay link could not be bypassed or has expired."


async def _resolve_galactic(session: aiohttp.ClientSession, url: str) -> Tuple[bool, str]:
    """Galaxy Resolver (Galactic Bypass API)."""
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    timeout = aiohttp.ClientTimeout(total=30)
    try:
        async with session.post(
            GALACTIC_ENDPOINT,
            json={"url": url},
            headers=headers,
            timeout=timeout,
        ) as resp:
            if resp.status == 200:
                data = await resp.json(content_type=None)
                if isinstance(data, dict):
                    dest = data.get("bypassedUrl")
                    if isinstance(dest, str) and _valid_http_url(dest) and dest != url:
                        return True, dest.strip()
            else:
                body = await resp.text()
                print(f"[galactic] HTTP {resp.status}: {body[:160]}")
    except Exception as exc:
        print(f"[galactic] error: {type(exc).__name__}: {exc}")
    return False, "That link could not be bypassed. It may be expired, private, or unsupported."


async def bypass_url(raw_url: str) -> Tuple[bool, str, str]:
    """Resolve a shortener/ad-link URL.

    Returns (success: bool, result_or_error: str, provider_label: str).
    """
    url = normalize_input_url(raw_url)
    if not url or not _valid_http_url(url):
        return False, "That does not look like a valid URL. Please include the full link.", ""

    # 1. Fast local parameter decoding
    local_res = _local_decode(url)
    if local_res:
        return True, local_res, FOOTER_LABEL

    parsed = urlparse(url)
    host = parsed.netloc.lower()

    # 2. For auth.platorelay.com specifically: dedicated PlatoRelay provider
    if "auth.platorelay.com" in host or "auth.platoboost.app" in host:
        async with aiohttp.ClientSession(cookie_jar=aiohttp.CookieJar()) as session:
            ok, res = await _resolve_platorelay(session, url)
            if ok:
                return True, res, FOOTER_LABEL
            return False, res, ""

    # 3. For all other URLs: Galaxy Resolver only
    async with aiohttp.ClientSession(cookie_jar=aiohttp.CookieJar()) as session:
        ok, res = await _resolve_galactic(session, url)
        if ok:
            return True, res, FOOTER_LABEL
        return False, res, ""
