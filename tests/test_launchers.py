"""tools/lune and tools/darklua are launchers. With no arch-specific binary next to them they must hand over to the
real tool installed on the system, even though up.sh puts tools/ first on PATH (they used to call themselves forever)."""
import os
import shutil
import stat
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.tools = os.path.join(self.tmp, "tools")  # a copy of the launchers, with no lune-x86_64 beside them
        self.system = os.path.join(self.tmp, "system-bin")
        os.makedirs(self.tools)
        os.makedirs(self.system)
        for name in ("lune", "darklua"):
            shutil.copy(os.path.join(ROOT, "tools", name), os.path.join(self.tools, name))
            fake = os.path.join(self.system, name)
            with open(fake, "w") as handle:
                handle.write(f'#!/bin/sh\necho "system {name} $*"\n')
            os.chmod(fake, os.stat(fake).st_mode | stat.S_IXUSR)

    def run_launcher(self, name):
        env = dict(os.environ, PATH=os.pathsep.join([self.tools, self.tmp, self.system, "/usr/bin", "/bin"]))
        return subprocess.run(
            ["bash", os.path.join(self.tools, name), "--version"],
            env=env, capture_output=True, text=True, timeout=10,
        )

    def test_lune_launcher_hands_over_to_the_system_binary(self):
        result = self.run_launcher("lune")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "system lune --version")

    def test_darklua_launcher_hands_over_to_the_system_binary(self):
        result = self.run_launcher("darklua")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "system darklua --version")

    def test_launcher_reports_a_clear_error_when_the_tool_is_missing(self):
        os.remove(os.path.join(self.system, "lune"))
        result = self.run_launcher("lune")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No executable 'lune' found", result.stderr)


if __name__ == "__main__":
    unittest.main()
