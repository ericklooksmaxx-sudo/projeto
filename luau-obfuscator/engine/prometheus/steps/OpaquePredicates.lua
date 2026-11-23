-- Kyzen Obfuscator - OpaquePredicates step
--
-- Inserts opaque-predicate-guarded branches at random positions of the top-level
-- chunk. Always-true predicates guard empty THEN clauses with dead ELSE junk;
-- always-false predicates guard dead THEN junk. A static analyzer cannot fold the
-- arithmetic predicates away, so decompilers keep the dead paths. Scope-clean:
-- every block is a self-contained parsed `do ... end`.

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local Source = require("prometheus.source")

local OpaquePredicates = Step:extend()
OpaquePredicates.Description = "Injects opaque always-true/false predicates to confuse decompilers."
OpaquePredicates.Name = "Opaque Predicates"

OpaquePredicates.SettingsDescriptor = {
	MinCount = { type = "number", default = 5, min = 0, description = "Minimum opaque branches to insert." },
	MaxCount = { type = "number", default = 12, min = 0, description = "Maximum opaque branches to insert." },
}

function OpaquePredicates:init(settings) end

local function rName()
	local n = math.random(5, 9)
	local t = {}
	for i = 1, n do t[i] = string.char(math.random(97, 122)) end
	return table.concat(t)
end
local function rNum() return math.random(1, 1000000) end

local TRUE_PREDS = {
	function() local n = math.random(10, 99); return string.format("%d %% %d == 0", n, n) end,
	function() local n = rNum(); return string.format("%d - %d == 0", n, n) end,
	function() local n = rNum(); return string.format("%d * 0 + %d == %d", n, n, n) end,
	function() local a = math.random(1, 50); local b = math.random(51, 99); return string.format("(not (%d >= %d)) == (%d < %d)", a, b, a, b) end,
	function() local n = rNum(); return string.format("not (%d ~= %d)", n, n) end,
	function() local a = math.random(1, 50); local b = a + math.random(1, 50); return string.format("%d + %d == %d", a, b - a, b) end,
}
local FALSE_PREDS = {
	function() local n = math.random(10, 99); return string.format("%d %% %d ~= 0", n, n) end,
	function() local n = rNum(); return string.format("%d ~= %d", n, n) end,
	function() local n = rNum(); return string.format("%d > %d", n, n) end,
	function() local n = rNum(); return string.format("not (%d == %d)", n, n) end,
}

local function deadJunk()
	local v, w = rName(), rName()
	return string.format("local %s=%d local %s=%s*%d for %s=1,%d do %s=%s-%d end",
		v, rNum(), w, v, math.random(2, 9), rName(), math.random(2, 12), w, w, rNum())
end

local BUILDERS = {
	function() -- always-true: then empty, else dead
		return string.format("do if %s then else %s end end", TRUE_PREDS[math.random(#TRUE_PREDS)](), deadJunk())
	end,
	function() -- always-false: then dead
		return string.format("do if %s then %s end end", FALSE_PREDS[math.random(#FALSE_PREDS)](), deadJunk())
	end,
	function() -- always-true with nested false
		return string.format("do if %s then if %s then %s end end end",
			TRUE_PREDS[math.random(#TRUE_PREDS)](), FALSE_PREDS[math.random(#FALSE_PREDS)](), deadJunk())
	end,
}

function OpaquePredicates:apply(ast, pipeline)
	local body = ast.body
	if not body or not body.statements or #body.statements == 0 then return ast end

	local luaVersion = pipeline.LuaVersion or Enums.LuaVersion.LuaU
	local lo = math.min(self.MinCount, self.MaxCount)
	local hi = math.max(self.MinCount, self.MaxCount)
	local count = (hi <= 0) and 0 or math.random(lo, hi)

	for _ = 1, count do
		local src = BUILDERS[math.random(#BUILDERS)]()
		local ok, parsed = pcall(function()
			return Parser:new({ LuaVersion = luaVersion }):parse(src, Source.internal("OpaquePredicates", src))
		end)
		if ok and parsed and parsed.body.statements[1] then
			local pos = math.random(1, #body.statements)
			table.insert(body.statements, pos, parsed.body.statements[1])
		end
	end

	return ast
end

return OpaquePredicates
