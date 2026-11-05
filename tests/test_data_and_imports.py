"""The renamed modules must all import, and the bot must keep its data (credits, keys) on its own."""
import importlib
import os
import tempfile
import unittest

# run.py refuses to start without a token; any value will do for importing it.
os.environ.setdefault("DISCORD_TOKEN", "test-token")

MODULES = (
    "storage", "netguard", "fingerprint", "classifier", "tidy", "namer", "unlink", "assistant",
    "wallet", "passes", "guard", "draws", "sandbox", "pipeline", "run",
)


class ImportTests(unittest.TestCase):
    def test_every_module_imports(self):
        for name in MODULES:
            with self.subTest(module=name):
                importlib.import_module(name)

    def test_the_bot_has_no_client_for_a_remote_site(self):
        run = importlib.import_module("run")
        self.assertFalse(hasattr(run, "HollowAPI"))
        sandbox = importlib.import_module("sandbox")
        self.assertFalse(hasattr(sandbox, "dump_script_remote"))


class DataTests(unittest.TestCase):
    def test_runtime_data_lives_in_the_data_folder(self):
        import draws, guard, passes, storage, wallet

        self.assertTrue(os.path.isdir(storage.DATA_DIR))
        for path in (wallet.DB_PATH, passes.KEYS_DB, guard.CONFIG_FILE, draws.GIVEAWAY_DB, draws.WARNINGS_DB):
            with self.subTest(path=path):
                self.assertEqual(os.path.dirname(path), storage.DATA_DIR)

    def test_credits_survive_a_restart(self):
        import wallet

        with tempfile.TemporaryDirectory() as tmp:
            db = os.path.join(tmp, "wallet.json")
            wallet.CreditsManager(db_path=db).add_credits(42, 7)
            self.assertEqual(wallet.CreditsManager(db_path=db).get_credits(42), 7)

    def test_premium_keys_are_generated_redeemed_and_revoked_locally(self):
        import passes

        with tempfile.TemporaryDirectory() as tmp:
            db = os.path.join(tmp, "passes.json")
            manager = passes.KeyManager(db_path=db)
            first, second = manager.generate_keys(2, creator_id=1)

            reloaded = passes.KeyManager(db_path=db)
            self.assertEqual(reloaded.get_stats(), {"total": 2, "active": 2, "claimed": 0, "revoked": 0})

            self.assertEqual(reloaded.redeem_key(first.lower(), 99), (True, "Key successfully redeemed!"))
            self.assertFalse(reloaded.redeem_key(first, 100)[0], "a key can only be redeemed once")
            self.assertTrue(reloaded.has_active_key(99))

            self.assertEqual(reloaded.revoke_key(second), (True, None))
            self.assertEqual(passes.KeyManager(db_path=db).get_stats(), {"total": 2, "active": 0, "claimed": 1, "revoked": 1})


if __name__ == "__main__":
    unittest.main()
