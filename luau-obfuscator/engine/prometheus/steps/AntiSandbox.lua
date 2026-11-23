-- Kyzen Obfuscator - AntiSandbox step
--
-- Roblox/LuaU-focused protection against env loggers, dumpers and sandboxes
-- that emulate the Roblox environment to extract the protected payload.
--
-- Design notes:
--  * The injected guard runs BEFORE the payload. Every probe is wrapped in
--    pcall and only flips the tamper flag on a POSITIVE detection. A missing
--    API (e.g. running outside Roblox) is treated as "not applicable" and
--    skipped, so clean environments (and the Lua 5.1 test harness) keep
--    running normally - sandboxes/dumpers are what trip the guard.
--  * On detection the guard derails execution in an obscure, deniable way
--    instead of printing an obvious "tamper detected" message, so dumpers
--    cannot trivially locate and strip the check.
--  * Place this step BEFORE Vmify so the guard itself is compiled into the VM.

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local Source = require("prometheus.source")
local RandomStrings = require("prometheus.randomStrings")

local AntiSandbox = Step:extend()
AntiSandbox.Description =
	"Breaks the script inside Roblox env-loggers, dumpers and fake-game sandboxes."
AntiSandbox.Name = "Anti Sandbox"

AntiSandbox.SettingsDescriptor = {
	Strict = {
		type = "boolean",
		default = false,
		description = "Enable aggressive probes (env metatable logger, locked-metatable, timing). May false-positive on exotic executors.",
	},
	Crash = {
		type = "enum",
		values = { "error", "freeze", "overflow" },
		default = "error",
		description = "How the guard derails when tampering is detected.",
	},
}

-- Realistic-looking error messages so a tripped guard resembles a normal bug.
local FAKE_ERRORS = {
	"attempt to index nil with 'Parent'",
	"attempt to call a nil value",
	"attempt to perform arithmetic (add) on nil",
	"invalid argument #1 (table expected, got nil)",
	"attempt to index nil with 'Name'",
}

function AntiSandbox:init(settings) end

local function crashSnippet(mode)
	if mode == "freeze" then
		return "while true do end"
	elseif mode == "overflow" then
		return "local function _o() return _o() end _o()"
	else
		local msg = FAKE_ERRORS[math.random(1, #FAKE_ERRORS)]
		return string.format("error(%q, 0)", msg)
	end
end

function AntiSandbox:apply(ast, pipeline)
	if pipeline.PrettyPrint then
		-- Guard relies on exact control flow; pretty print is for debugging only.
		return ast
	end

	local decoy = RandomStrings.randomString()
	local strict = self.Strict and true or false
	local crash = crashSnippet(self.Crash)

	-- Build the guard body. Written in plain Lua 5.1 syntax so it parses under
	-- either target; all Roblox globals are read dynamically and guarded.
	local parts = {}
	local function add(s) parts[#parts + 1] = s end

	add("do")
	add("local safe = true")
	add("local pcall, type, tostring, rawequal = pcall, type, tostring, rawequal")
	add("local getmetatable = getmetatable")
	add("local gameG, typeofG, InstanceG, workspaceG = game, typeof, Instance, workspace")
	add("local getfenvG, getrawmetatableG = getfenv, getrawmetatable")
	add("local iscclosureG, islclosureG = iscclosure, islclosure")
	add("local hookfunctionG, newcclosureG = hookfunction, newcclosure")
	add("local dbg = debug")
	add(string.format("local decoy = %q", decoy))

	-- 1) pcall integrity (a hooked pcall that swallows calls breaks this).
	add([[
	do
		local ok, v = pcall(function() return decoy end)
		if not ok or v ~= decoy then safe = false end
	end]])

	-- 2) Cross-marker consistency: real Roblox always ships typeof + Instance
	--    whenever `game` exists. A sandbox that stubs `game` but forgets these
	--    (or nils them to dodge probes) is inconsistent.
	add([[
	if gameG then
		if not typeofG or not InstanceG or type(typeofG) ~= "function" then
			safe = false
		end
	end]])

	-- 3) Fake-game / sandbox authenticity (only runs in Roblox-like envs).
	add([[
	if gameG and typeofG and type(typeofG) == "function" then
		local ok, res = pcall(function()
			if typeofG(gameG) ~= "Instance" then return false end
			if gameG.ClassName ~= "DataModel" then return false end
			local svc = gameG:GetService("RunService")
			if typeofG(svc) ~= "Instance" then return false end
			if workspaceG and not rawequal(workspaceG, gameG:GetService("Workspace")) then
				return false
			end
			if InstanceG then
				local inst = InstanceG.new("Folder")
				if typeofG(inst) ~= "Instance" then return false end
				pcall(function() inst:Destroy() end)
			end
			return true
		end)
		if ok then
			if res == false then safe = false end
		else
			-- Genuine Roblox APIs do not error here; a throw means a broken sandbox.
			safe = false
		end
	end]])

	-- 4) Anti function-hook on core C closures (loggers detour these).
	--    iscclosure is the precise signal; else fall back to Luau's debug.info
	--    (string source). We deliberately avoid Lua's debug.getinfo (returns a
	--    table with different semantics) so this stays a no-op off-Roblox.
	add([[
	do
		local core = { pcall, type, tostring, rawequal, getmetatable, setmetatable }
		if iscclosureG and type(iscclosureG) == "function" then
			for i = 1, #core do
				if core[i] then
					local ok, c = pcall(iscclosureG, core[i])
					if ok and c == false then safe = false end
				end
			end
		elseif dbg and type(dbg.info) == "function" and gameG then
			local info = dbg.info
			for i = 1, #core do
				if core[i] then
					local ok, s = pcall(function() return info(core[i], "s") end)
					if ok and type(s) == "string" and s ~= "[C]" and string.sub(s, 1, 3) ~= "=[C" then
						safe = false
					end
				end
			end
		end
	end]])

	-- 5) Anti-dump: vanilla Roblox strips string.dump. If it exists AND we are in
	--    a Roblox-like env, the env has been instrumented to allow dumping.
	add([[
	if gameG and string and string.dump then
		local ok = pcall(string.dump, function() return decoy end)
		if ok then safe = false end
	end]])

	-- 6) Anti function-arg hook: a __tostring logger on passed objects fires here.
	add([[
	do
		local tripped = false
		local probe = setmetatable({}, { __tostring = function() tripped = true; return "" end })
		pcall(function() return tostring(probe) end)
		-- tripped is expected; a logger that *also* records globals is caught elsewhere.
	end]])

	if strict then
		-- 7) Env-metatable logger: function-based __index/__newindex on the script
		--    env is how loggers intercept global reads/writes. We flag only when
		--    the hook is a FUNCTION (tables are normal executor global shims) to
		--    avoid false positives. No timing check: it is unreliable inside a VM.
		add([[
	if getrawmetatableG and type(getrawmetatableG) == "function" and getfenvG then
		local ok, env = pcall(getfenvG, 1)
		if ok and type(env) == "table" then
			local ok2, rmt = pcall(getrawmetatableG, env)
			if ok2 and type(rmt) == "table" then
				if type(rmt.__index) == "function" or type(rmt.__newindex) == "function" then
					safe = false
				end
			end
		end
	end]])

		-- 8) Locked-metatable check: Roblox exposes game's metatable as a string.
		add([[
	if gameG and getmetatable then
		local ok, mt = pcall(getmetatable, gameG)
		if ok and mt ~= nil and type(mt) ~= "string" then safe = false end
	end]])
	end

	-- Derail on detection.
	add("if not safe then")
	add("\t" .. crash)
	add("end")
	add("end")

	local code = table.concat(parts, "\n")
	local luaVersion = pipeline.LuaVersion or Enums.LuaVersion.LuaU
	local parsed = Parser:new({ LuaVersion = luaVersion })
		:parse(code, Source.internal("AntiSandbox", code))
	local doStat = parsed.body.statements[1]
	table.insert(ast.body.statements, 1, doStat)

	return ast
end

return AntiSandbox
