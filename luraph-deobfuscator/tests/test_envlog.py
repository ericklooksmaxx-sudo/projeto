import unittest

from luraph_deob.envlog import dump


class EnvLogTests(unittest.TestCase):
    def run_src(self, src, **kw):
        return dump(src.encode(), timeout=30, **kw)

    def test_basic_trace(self):
        r = self.run_src('''
local Players = game:GetService("Players")
local p = Instance.new("Part")
p.Name = "Hello"
p.Size = Vector3.new(4, 1, 2)
p.Parent = workspace
game:GetService("RunService").Heartbeat:Connect(function(dt)
    p.CFrame = p.CFrame * CFrame.new(0, dt, 0)
end)
loadstring("game.Players.LocalPlayer.Name = 'z'")()
''')
        s = r.source
        self.assertIn('game:GetService("Players")', s)
        self.assertIn('part.Size = Vector3.new(4, 1, 2)', s)
        self.assertIn('Heartbeat:Connect(function(a1)', s)
        self.assertIn('game.Players.LocalPlayer.Name = "z"', s)
        self.assertEqual(len(r.chunks), 1)
        self.assertIsNone(r.error)

    def test_error_is_reported_not_raised(self):
        r = self.run_src('game:GetService("Players")\nerror("boom")')
        self.assertIn("boom", r.error)
        self.assertIn("-- error:", r.source)

    def test_timeout(self):
        r = dump(b"while true do end", timeout=2)
        self.assertTrue(r.timed_out)

    def test_next_allows_removal_during_traversal(self):
        r = self.run_src('local t={a=1,b=2,c=3}\nfor k in pairs(t) do t[k]=nil end\nprint(next(t))')
        self.assertIsNone(r.error)


if __name__ == "__main__":
    unittest.main()


class RepairTests(unittest.TestCase):
    def test_mojibake_roundtrip(self):
        from luraph_deob.envlog import repair_mojibake
        orig = b'print("\xf0\x9f\x98\x80 \x81\xff")'
        broken = orig.decode("cp1252", errors="replace").encode("utf-8") if False else \
            "".join(chr(b) for b in orig).encode("utf-8")
        self.assertNotEqual(broken, orig)
        self.assertEqual(repair_mojibake(broken), orig)
        self.assertIsNone(repair_mojibake(b"print(1)"))
