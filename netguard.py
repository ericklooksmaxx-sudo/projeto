"""Safe downloads for links that users hand to the bot (`.get`, links given to `.l`, `.detect`, `.format`...).

Without this a user could point the bot at http://127.0.0.1:..., a host on the private network or a cloud
metadata address and read the answer back as a "script" attachment. Three layers:

* ``check_url``          - static checks on the text of the URL (scheme, internal names, IP literals);
* ``PublicOnlyResolver`` - refuses any name that resolves to a non-public address, at connect time (so a DNS
                           answer cannot be swapped after the check) and also catches odd spellings such as
                           ``http://2130706433/``;
* ``safe_get``           - follows redirects by hand so every hop goes through both checks again.
"""
import ipaddress
import socket
from typing import Dict, Optional, Tuple
from urllib.parse import urljoin, urlsplit

import aiohttp
from aiohttp import abc as aiohttp_abc

MAX_REDIRECTS = 5
_REDIRECT_STATUSES = (301, 302, 303, 307, 308)
_BLOCKED_HOSTS = ("localhost", "metadata.google.internal")
_BLOCKED_SUFFIXES = (".local", ".internal", ".localhost")


class FetchBlocked(Exception):
    """The link (or one of its redirects) is not allowed to be fetched."""


def is_public_ip(value: str) -> bool:
    """True only for globally routable unicast addresses."""
    try:
        ip = ipaddress.ip_address(value)
    except ValueError:
        return False
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped  # ::ffff:127.0.0.1 is still loopback
    return ip.is_global and not ip.is_multicast


def check_url(url: str) -> Tuple[bool, str]:
    """(allowed, reason). Looks only at the text of the URL; names are checked when they are resolved."""
    try:
        parts = urlsplit((url or "").strip())
        host = (parts.hostname or "").strip().lower().rstrip(".")
    except ValueError:
        return False, "That link is not a valid URL."
    if parts.scheme not in ("http", "https"):
        return False, "Only http and https links are allowed."
    if not host:
        return False, "That link has no host."
    if host in _BLOCKED_HOSTS or host.endswith(_BLOCKED_SUFFIXES):
        return False, "Links to internal hosts are not allowed."
    try:
        ipaddress.ip_address(host)
    except ValueError:
        return True, ""  # a name: its addresses are checked by PublicOnlyResolver when connecting
    if not is_public_ip(host):
        return False, "Links to private or internal addresses are not allowed."
    return True, ""


class PublicOnlyResolver(aiohttp_abc.AbstractResolver):
    """aiohttp resolver that refuses names resolving to non-public addresses."""

    def __init__(self) -> None:
        self._inner = aiohttp.ThreadedResolver()

    async def resolve(self, host: str, port: int = 0, family: int = socket.AF_INET):
        answers = await self._inner.resolve(host, port, family)
        if not answers:
            raise OSError(f"{host} did not resolve to any address")
        for answer in answers:
            if not is_public_ip(answer["host"]):
                raise OSError(f"{host} resolves to a non-public address")
        return answers

    async def close(self) -> None:
        await self._inner.close()


async def safe_get(
    url: str,
    headers: Optional[Dict[str, str]] = None,
    timeout: float = 25.0,
) -> Tuple[int, str, bytes]:
    """GET `url` and return (status, reason, body).

    Raises FetchBlocked when the link, or any redirect on the way, points somewhere that is not allowed.
    Network errors (timeouts, refused connections...) propagate as the usual aiohttp/OS exceptions.
    """
    connector = aiohttp.TCPConnector(resolver=PublicOnlyResolver())
    async with aiohttp.ClientSession(connector=connector, timeout=aiohttp.ClientTimeout(total=timeout)) as session:
        current = url
        for _ in range(MAX_REDIRECTS + 1):
            allowed, reason = check_url(current)
            if not allowed:
                raise FetchBlocked(reason)
            try:
                async with session.get(current, headers=headers, allow_redirects=False) as resp:
                    location = resp.headers.get("Location")
                    if resp.status in _REDIRECT_STATUSES and location:
                        current = urljoin(current, location)
                        continue
                    return resp.status, resp.reason or "", await resp.read()
            except aiohttp.ClientConnectorError as exc:
                if isinstance(exc.os_error, OSError) and "non-public address" in str(exc.os_error):
                    raise FetchBlocked("Links to private or internal addresses are not allowed.") from exc
                raise
        raise FetchBlocked("That link redirects too many times.")
