-- Kyzen Obfuscator - JunkCode step
--
-- Inserts self-contained, never-executed junk blocks at random positions of the
-- top-level chunk. Each block is a parsed `do ... end` referencing only its own
-- locals (+ globals it never reaches), so it is scope-clean and has zero runtime
-- effect. Placed before Vmify/Cff it gets flattened and spread through the output.

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local Source = require("prometheus.source")
local Ast = require("prometheus.ast")

local JunkCode = Step:extend()
JunkCode.Description = "Inserts dead junk code to confuse readers and decompilers."
JunkCode.Name = "Junk Code"

JunkCode.SettingsDescriptor = {
	MinCount = { type = "number", default = 6, min = 0, description = "Minimum junk blocks to insert." },
	MaxCount = { type = "number", default = 14, min = 0, description = "Maximum junk blocks to insert." },
}

function JunkCode:init(settings) end

local function rName()
	local n = math.random(5, 9)
	local t = {}
	for i = 1, n do t[i] = string.char(math.random(97, 122)) end
	return table.concat(t)
end

local function rNum() return math.random(1, 1000000) end

-- Always-false opaque predicates (dead-code guards).
local FALSE_PREDS = {
	function() local n = math.random(10, 99); return string.format("%d %% %d ~= 0", n, n) end,
	function() local n = rNum(); return string.format("%d ~= %d", n, n) end,
	function() local n = rNum(); return string.format("%d > %d", n, n) end,
	function() local a = math.random(1, 50); local b = a + math.random(1, 50); return string.format("%d + %d ~= %d", a, b - a, b) end,
	function() local n = rNum(); return string.format("not (%d == %d)", n, n) end,
}

-- Builders returning a self-contained `do ... end` string.
local BUILDERS = {
	-- harmless local chain (dead-ish, never referenced elsewhere)
	function()
		local a, b, c = rName(), rName(), rName()
		return string.format("do local %s=%d local %s=%s*%d local %s=%s+%d end",
			a, rNum(), b, a, math.random(2, 9), c, b, rNum())
	end,
	-- dead false-guarded block with fake logic
	function()
		local p = FALSE_PREDS[math.random(#FALSE_PREDS)]()
		local v, w = rName(), rName()
		return string.format("do if %s then local %s=%d for %s=1,%d do %s=%s+%s end end end",
			p, v, rNum(), w, math.random(2, 20), v, v, w)
	end,
	-- dead function definition that is never called
	function()
		local f, x, y = rName(), rName(), rName()
		return string.format("do local function %s(%s) local %s=%s or %d return %s end end",
			f, x, y, x, rNum(), y)
	end,
	-- dead while with break
	function()
		local p = FALSE_PREDS[math.random(#FALSE_PREDS)]()
		local v = rName()
		return string.format("do while %s do local %s=%d break end end", p, v, rNum())
	end,
	-- dead table build
	function()
		local t = rName()
		return string.format("do local %s={%d,%d,%d} %s[%d]=%d end", t, rNum(), rNum(), rNum(), t, math.random(1, 3), rNum())
	end,
}

function JunkCode:apply(ast, pipeline)
	local body = ast.body
	if not body or not body.statements or #body.statements == 0 then return ast end

	local luaVersion = pipeline.LuaVersion or Enums.LuaVersion.LuaU
	local lo = math.min(self.MinCount, self.MaxCount)
	local hi = math.max(self.MinCount, self.MaxCount)
	local count = (hi <= 0) and 0 or math.random(lo, hi)

	for _ = 1, count do
		local src = BUILDERS[math.random(#BUILDERS)]()
		local ok, parsed = pcall(function()
			return Parser:new({ LuaVersion = luaVersion }):parse(src, Source.internal("JunkCode", src))
		end)
		if ok and parsed and parsed.body.statements[1] then
			local stat = parsed.body.statements[1]
			-- Never insert after a trailing return (keeps `return` last => valid).
			local maxPos = #body.statements
			local pos = math.random(1, maxPos)
			table.insert(body.statements, pos, stat)
		end
	end

	return ast
end

return JunkCode
