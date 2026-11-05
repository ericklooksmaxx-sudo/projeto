"""Drives the real `on_message` with fake Discord messages: every command that used to depend on a remote site
must now work on its own. Runs without a Discord connection; every network call is local or replaced."""
import os
import tempfile
import types
import unittest
from unittest import mock

# run.py exits without a token and loads .env; keep tests away from real credentials and AI providers.
os.environ["DISCORD_TOKEN"] = "test-token"
os.environ["PREFIX"] = "."
os.environ["OPENROUTER"] = ""
os.environ["NVIDIA_NIM"] = ""

import discord
from aiohttp import web

import netguard
import passes
import run
import wallet
from sandbox import HOLLOW_HEADER

MOONSEC_V3 = "--[[ This file was protected with MoonSec V3 ]]\nlocal a = 1\n"
CLEAN = "local function add(a, b)\n    if a then\n        return a + b\n    end\n    return b\nend\nprint(add(1, 2))\n"


class _Typing:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class FakeSent:
    def __init__(self):
        self.deleted = False
        self.edits = []

    async def delete(self):
        self.deleted = True

    async def edit(self, **kwargs):
        self.edits.append(kwargs)


class FakeChannel:
    def typing(self):
        return _Typing()

    async def send(self, *args, **kwargs):
        return FakeSent()

    async def fetch_message(self, _message_id):
        raise LookupError("no such message")


class FakeMessage:
    """Just enough of discord.Message for a command typed in a DM (no guild, so no moderation hooks)."""

    def __init__(self, content, user_id=1, roles=()):
        self.content = content
        self.author = types.SimpleNamespace(
            id=user_id, bot=False, display_name="tester", mention=f"<@{user_id}>",
            roles=[types.SimpleNamespace(id=role) for role in roles], send=mock.AsyncMock(),
        )
        self.guild = None
        self.channel = FakeChannel()
        self.mentions = []
        self.attachments = []
        self.reference = None
        self.replies = []

    async def reply(self, content=None, **kwargs):
        self.replies.append(types.SimpleNamespace(content=content, embed=kwargs.get("embed"), file=kwargs.get("file"), view=kwargs.get("view")))
        return FakeSent()

    async def delete(self):
        pass

    @property
    def embeds(self):
        return [reply.embed for reply in self.replies if reply.embed is not None]

    @property
    def files(self):
        return [reply.file for reply in self.replies if reply.file is not None]

    def text(self):
        """All embed text, for loose assertions."""
        parts = []
        for embed in self.embeds:
            parts += [embed.title or "", embed.description or ""]
            parts += [f"{field.name} {field.value}" for field in embed.fields]
        return "\n".join(parts)


def owner_message(content):
    return FakeMessage(content, user_id=1000, roles=[run.OWNER_ROLE_ID])


class CommandTestCase(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.wallet = wallet.CreditsManager(db_path=os.path.join(tmp.name, "wallet.json"))
        self.passes = passes.KeyManager(db_path=os.path.join(tmp.name, "passes.json"))
        for target, value in (("credits_manager", self.wallet), ("key_manager", self.passes)):
            patcher = mock.patch.object(run, target, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        # no ML model file in tests: `.detect` answers from signatures
        patcher = mock.patch.object(run.classifier, "get_model", return_value=None)
        patcher.start()
        self.addCleanup(patcher.stop)


class DetectAndFormatTests(CommandTestCase):
    async def test_detect_names_the_obfuscator(self):
        message = owner_message(f".detect\n```lua\n{MOONSEC_V3}```")
        await run.on_message(message)
        self.assertEqual(message.embeds[-1].title, "🔍 Obfuscator Detector")
        self.assertIn("MoonSec V3", message.text())
        self.assertIn("Obfuscated with MoonSec V3", message.text())

    async def test_detect_says_clean_for_clean_code(self):
        message = owner_message(f".detect\n```lua\n{CLEAN}```")
        await run.on_message(message)
        self.assertIn("Clean (Unobfuscated)", message.text())

    async def test_format_returns_a_formatted_file(self):
        message = owner_message(".format\n```lua\nlocal   x=1\nprint( x )\n```")
        await run.on_message(message)
        self.assertEqual(message.embeds[-1].title, "✨ Code Formatted")
        self.assertEqual(len(message.files), 1)
        self.assertTrue(message.files[0].filename.endswith("_formatted.lua"))
        formatted = message.files[0].fp.read().decode()
        self.assertTrue(formatted.startswith(HOLLOW_HEADER))
        self.assertIn("print", formatted)


class GetTests(CommandTestCase):
    async def asyncSetUp(self):
        self.hits = 0

        async def script(request):
            self.hits += 1
            return web.Response(text='print("served")\n')

        app = web.Application()
        app.router.add_get("/script.lua", script)
        self.runner = web.AppRunner(app)
        await self.runner.setup()
        site = web.TCPSite(self.runner, "127.0.0.1", 0)
        await site.start()
        self.url = f"http://127.0.0.1:{site._server.sockets[0].getsockname()[1]}/script.lua"

    async def asyncTearDown(self):
        await self.runner.cleanup()

    async def test_get_refuses_a_private_link_and_refunds_the_credit(self):
        self.wallet.add_credits(5, 3)
        message = FakeMessage(f".get {self.url}", user_id=5)
        await run.on_message(message)
        self.assertEqual(message.embeds[-1].title, "⚠️ Request Failed")
        self.assertIn("not allowed", message.text())
        self.assertIn("Credit refunded", message.text())
        self.assertEqual(self.wallet.get_credits(5), 3, "the credit must come back")
        self.assertEqual(self.hits, 0, "the internal server must never be contacted")

    async def test_get_delivers_an_allowed_link_as_a_file(self):
        real = netguard.is_public_ip
        with mock.patch.object(netguard, "is_public_ip", lambda value: value == "127.0.0.1" or real(value)):
            message = owner_message(f".get {self.url}")
            await run.on_message(message)
        self.assertEqual(message.embeds[-1].title, "🌐 Request Completed")
        self.assertEqual(len(message.files), 1)
        self.assertEqual(message.files[0].filename, "script.lua")
        self.assertEqual(message.files[0].fp.read(), b'print("served")\n')


class KeyTests(CommandTestCase):
    async def test_generate_list_redeem_and_revoke_keys_without_any_site(self):
        generated = owner_message(".genkey 2")
        await run.on_message(generated)
        self.assertEqual(self.passes.get_stats()["total"], 2)
        self.assertIn("PREM-", generated.text())
        self.assertEqual(generated.author.send.await_count, 1, "keys are also sent by DM")

        listed = owner_message(".keys")
        await run.on_message(listed)
        self.assertEqual(listed.embeds[-1].title, "🔑 Key Statistics")
        self.assertIn("Total `2`", listed.text())

        first, second = list(self.passes.keys)
        with mock.patch.object(run, "grant_premium_role", mock.AsyncMock(return_value=True)):
            redeemed = FakeMessage(f".redeem {first}", user_id=77)
            await run.on_message(redeemed)
        self.assertEqual(redeemed.embeds[-1].title, "✅ Premium Role Granted")
        self.assertTrue(self.passes.has_active_key(77))

        with mock.patch.object(run, "grant_premium_role", mock.AsyncMock(return_value=True)):
            again = FakeMessage(f".redeem {first}", user_id=78)
            await run.on_message(again)
        self.assertEqual(again.embeds[-1].title, "❌ Key Redeem Failed")

        with mock.patch.object(run, "remove_premium_from_user", mock.AsyncMock()):
            revoked = owner_message(f".revoke {second}")
            await run.on_message(revoked)
        self.assertEqual(self.passes.get_stats()["revoked"], 1)


class BypassAndImageTests(CommandTestCase):
    async def test_bypass_uses_the_local_resolver(self):
        resolver = mock.AsyncMock(return_value=(True, "https://example.com/final", "Powered by test"))
        with mock.patch.object(run.unlink, "bypass_url", resolver):
            message = owner_message(".bypass https://linkvertise.com/123/abc")
            await run.on_message(message)
        resolver.assert_awaited_once_with("https://linkvertise.com/123/abc")
        self.assertEqual(message.embeds[-1].title, "🔓 Link Bypassed")
        self.assertIn("https://example.com/final", message.text())

    async def test_bypass_failure_refunds_the_credit(self):
        self.wallet.add_credits(6, 2)
        premium = FakeMessage(".bypass https://linkvertise.com/1/x", user_id=6, roles=[run.PREMIUM_ROLE_ID])
        with mock.patch.object(run.unlink, "bypass_url", mock.AsyncMock(return_value=(False, "dead link", ""))):
            await run.on_message(premium)
        self.assertEqual(premium.embeds[-1].title, "❌ Bypass Failed")
        self.assertEqual(self.wallet.get_credits(6), 2)

    async def test_imagine_uses_the_local_generator(self):
        generator = mock.AsyncMock(return_value=(b"\x89PNG fake image bytes", None))
        with mock.patch.object(run, "generate_ai_image", generator):
            message = owner_message(".imagine a red cat")
            await run.on_message(message)
        generator.assert_awaited_once_with("a red cat")
        self.assertEqual(message.embeds[-1].title, "🎨 AI Image Generated")
        self.assertEqual(message.files[0].filename, "hollow_imagine.png")


if __name__ == "__main__":
    unittest.main()
