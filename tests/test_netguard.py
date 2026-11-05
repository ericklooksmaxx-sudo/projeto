"""Links that users give the bot must never lead it to private or internal addresses."""
import asyncio
import unittest
from unittest import mock

import aiohttp
from aiohttp import web

import netguard


class CheckUrlTests(unittest.TestCase):
    def test_blocks_non_http_schemes(self):
        for url in ("ftp://example.com/a.lua", "file:///etc/passwd", "gopher://example.com", "javascript:alert(1)"):
            with self.subTest(url=url):
                self.assertFalse(netguard.check_url(url)[0])

    def test_blocks_internal_names(self):
        for url in (
            "http://localhost/",
            "http://localhost:8080/admin",
            "http://metadata.google.internal/computeMetadata/v1/",
            "http://printer.local/",
            "http://db.internal/",
            "http://app.localhost/",
        ):
            with self.subTest(url=url):
                self.assertFalse(netguard.check_url(url)[0])

    def test_blocks_private_and_special_ip_literals(self):
        for url in (
            "http://127.0.0.1/",
            "http://127.1.2.3:9000/",
            "http://10.0.0.5/",
            "http://172.16.0.1/",
            "http://192.168.1.1/",
            "http://169.254.169.254/latest/meta-data/",
            "http://0.0.0.0/",
            "http://100.64.0.1/",
            "http://[::1]/",
            "http://[::ffff:127.0.0.1]/",
            "http://[fe80::1]/",
            "http://[fd00::1]/",
            "http://224.0.0.1/",
        ):
            with self.subTest(url=url):
                self.assertFalse(netguard.check_url(url)[0])

    def test_blocks_missing_host(self):
        self.assertFalse(netguard.check_url("http:///path")[0])
        self.assertFalse(netguard.check_url("")[0])

    def test_allows_public_links(self):
        for url in (
            "https://example.com/script.lua",
            "http://example.com:8080/x?y=1",
            "https://raw.githubusercontent.com/user/repo/main/a.lua",
            "http://93.184.216.34/a.lua",
            "https://[2606:2800:220:1:248:1893:25c8:1946]/",
        ):
            with self.subTest(url=url):
                ok, why = netguard.check_url(url)
                self.assertTrue(ok, why)


class PublicOnlyResolverTests(unittest.IsolatedAsyncioTestCase):
    async def test_refuses_a_name_that_resolves_to_a_private_address(self):
        resolver = netguard.PublicOnlyResolver()
        answer = [{"hostname": "evil.example", "host": "10.1.2.3", "port": 80, "family": 2, "proto": 0, "flags": 0}]
        with mock.patch.object(resolver._inner, "resolve", mock.AsyncMock(return_value=answer)):
            with self.assertRaises(OSError):
                await resolver.resolve("evil.example", 80)
        await resolver.close()

    async def test_refuses_when_any_answer_is_private(self):
        resolver = netguard.PublicOnlyResolver()
        answer = [
            {"hostname": "mixed.example", "host": "93.184.216.34", "port": 80, "family": 2, "proto": 0, "flags": 0},
            {"hostname": "mixed.example", "host": "127.0.0.1", "port": 80, "family": 2, "proto": 0, "flags": 0},
        ]
        with mock.patch.object(resolver._inner, "resolve", mock.AsyncMock(return_value=answer)):
            with self.assertRaises(OSError):
                await resolver.resolve("mixed.example", 80)
        await resolver.close()

    async def test_passes_public_answers_through(self):
        resolver = netguard.PublicOnlyResolver()
        answer = [{"hostname": "ok.example", "host": "93.184.216.34", "port": 443, "family": 2, "proto": 0, "flags": 0}]
        with mock.patch.object(resolver._inner, "resolve", mock.AsyncMock(return_value=answer)):
            self.assertEqual(await resolver.resolve("ok.example", 443), answer)
        await resolver.close()


class SafeGetTests(unittest.IsolatedAsyncioTestCase):
    """Runs against a real local server. 127.0.0.1 is only 'public' inside these tests (patched),
    every other private address stays blocked."""

    async def asyncSetUp(self):
        async def ok(request):
            return web.Response(text="hello script", headers={"X-Seen-UA": request.headers.get("User-Agent", "")})

        async def to_private(request):
            raise web.HTTPFound("http://10.0.0.1/secret")

        async def to_ok(request):
            raise web.HTTPFound("/ok")

        async def loop(request):
            raise web.HTTPFound("/loop")

        async def missing(request):
            return web.Response(status=404, text="nope")

        app = web.Application()
        app.router.add_get("/ok", ok)
        app.router.add_get("/to-private", to_private)
        app.router.add_get("/to-ok", to_ok)
        app.router.add_get("/loop", loop)
        app.router.add_get("/missing", missing)
        self.runner = web.AppRunner(app)
        await self.runner.setup()
        site = web.TCPSite(self.runner, "127.0.0.1", 0)
        await site.start()
        self.port = site._server.sockets[0].getsockname()[1]
        real = netguard.is_public_ip
        patcher = mock.patch.object(netguard, "is_public_ip", lambda value: value == "127.0.0.1" or real(value))
        patcher.start()
        self.addCleanup(patcher.stop)

    async def asyncTearDown(self):
        await self.runner.cleanup()

    def url(self, path):
        return f"http://127.0.0.1:{self.port}{path}"

    async def test_returns_status_reason_and_body(self):
        status, reason, body = await netguard.safe_get(self.url("/ok"), headers={"User-Agent": "unit-test"})
        self.assertEqual((status, reason, body), (200, "OK", b"hello script"))

    async def test_follows_a_redirect_to_a_public_address(self):
        status, _, body = await netguard.safe_get(self.url("/to-ok"))
        self.assertEqual((status, body), (200, b"hello script"))

    async def test_reports_error_statuses_without_raising(self):
        status, reason, body = await netguard.safe_get(self.url("/missing"))
        self.assertEqual((status, reason, body), (404, "Not Found", b"nope"))

    async def test_refuses_a_redirect_to_a_private_address(self):
        with self.assertRaises(netguard.FetchBlocked):
            await netguard.safe_get(self.url("/to-private"))

    async def test_gives_up_on_redirect_loops(self):
        with self.assertRaises(netguard.FetchBlocked):
            await netguard.safe_get(self.url("/loop"))

    async def test_refuses_a_blocked_first_url_without_connecting(self):
        with self.assertRaises(netguard.FetchBlocked):
            await netguard.safe_get("http://192.168.0.10/admin")


class DisguisedLoopbackTests(unittest.IsolatedAsyncioTestCase):
    """No patching here: a real server listens on 127.0.0.1 and the guard must not let a request through
    even when the address is spelled in ways that urlsplit/ipaddress do not recognise as an IP."""

    async def asyncSetUp(self):
        self.hits = 0

        async def hit(request):
            self.hits += 1
            return web.Response(text="internal secret")

        app = web.Application()
        app.router.add_get("/ok", hit)
        self.runner = web.AppRunner(app)
        await self.runner.setup()
        site = web.TCPSite(self.runner, "127.0.0.1", 0)
        await site.start()
        self.port = site._server.sockets[0].getsockname()[1]

    async def asyncTearDown(self):
        await self.runner.cleanup()

    async def test_plain_loopback_literal_is_blocked(self):
        with self.assertRaises(netguard.FetchBlocked):
            await netguard.safe_get(f"http://127.0.0.1:{self.port}/ok")
        self.assertEqual(self.hits, 0)

    async def test_disguised_loopback_never_reaches_the_server(self):
        for host in ("2130706433", "0x7f000001", "127.1", "0177.0.0.1", "localhost."):
            with self.subTest(host=host):
                try:
                    await netguard.safe_get(f"http://{host}:{self.port}/ok", timeout=5)
                except (netguard.FetchBlocked, aiohttp.ClientError, OSError):
                    pass
                self.assertEqual(self.hits, 0, f"{host} reached the internal server")


class BotFetchersUseTheGuardTests(unittest.IsolatedAsyncioTestCase):
    """`.get` (fetch_roblox_url) and links given to `.l`/`.detect`/`.format` (fetch_url_content) go through safe_get."""

    async def asyncSetUp(self):
        import sandbox

        self.sandbox = sandbox
        self.hits = 0

        async def echo_agent(request):
            self.hits += 1
            return web.Response(text=request.headers.get("User-Agent", ""))

        app = web.Application()
        app.router.add_get("/ua", echo_agent)
        self.runner = web.AppRunner(app)
        await self.runner.setup()
        site = web.TCPSite(self.runner, "127.0.0.1", 0)
        await site.start()
        self.url = f"http://127.0.0.1:{site._server.sockets[0].getsockname()[1]}/ua"

    async def asyncTearDown(self):
        await self.runner.cleanup()

    async def test_get_refuses_private_links(self):
        ok, data, status, reason = await self.sandbox.fetch_roblox_url(self.url)
        self.assertEqual((ok, data, status), (False, None, 0))
        self.assertIn("not allowed", reason)
        self.assertEqual(self.hits, 0)

    async def test_script_links_refuse_private_links(self):
        self.assertIsNone(await self.sandbox.fetch_url_content(self.url))
        self.assertEqual(self.hits, 0)

    async def test_allowed_links_still_download_with_the_roblox_user_agent(self):
        real = netguard.is_public_ip
        with mock.patch.object(netguard, "is_public_ip", lambda value: value == "127.0.0.1" or real(value)):
            ok, data, status, reason = await self.sandbox.fetch_roblox_url(self.url)
            text = await self.sandbox.fetch_url_content(self.url)
        self.assertEqual((ok, status, reason), (True, 200, "OK"))
        self.assertEqual(data.decode(), self.sandbox.ROBLOX_USER_AGENT)
        self.assertTrue(text.startswith("Mozilla/5.0"))


if __name__ == "__main__":
    unittest.main()
