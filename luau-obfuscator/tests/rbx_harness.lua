-- Simulates a Roblox-like global environment under lua5.1 to exercise AntiSandbox
-- against the REAL obfuscated output. Modes:
--   authentic  : faithful stub -> guard must PASS (script runs)
--   fake-typeof: typeof lies    -> guard must TRIP
--   instrument : string.dump re-enabled in a roblox env -> guard must TRIP
--   none       : no roblox env at all -> guard must PASS (off-Roblox no-op)
local mode, obf = arg[1], arg[2]

local function installAuthentic()
	local reg = setmetatable({}, { __mode = "k" })
	_G.typeof = function(x) if reg[x] then return "Instance" else return type(x) end end
	local svccache = {}
	local function newInstance(cls)
		local t = { ClassName = cls }
		local self
		self = setmetatable(t, {
			__metatable = "The metatable is locked",
			__index = function(_, k)
				if k == "GetService" then
					return function(_, name)
						if not svccache[name] then svccache[name] = newInstance(name) end
						return svccache[name]
					end
				elseif k == "Destroy" then
					return function() end
				end
				return nil
			end,
		})
		reg[self] = true
		return self
	end
	_G.game = newInstance("DataModel")
	_G.workspace = _G.game:GetService("Workspace")
	_G.Instance = { new = function(cls) return newInstance(cls or "Instance") end }
	-- Vanilla Roblox has no string.dump / debug.info semantics of Lua:
	string.dump = nil
	if debug then debug.info = nil end
end

if mode == "authentic" then
	installAuthentic()
elseif mode == "fake-typeof" then
	installAuthentic()
	_G.typeof = function() return "table" end        -- sandbox lies about types
elseif mode == "instrument" then
	installAuthentic()
	string.dump = function() return "BYTECODE" end     -- dumper re-enabled dump
elseif mode == "none" then
	-- leave bare lua5.1 env
end

local f = io.open(obf, "rb"); local src = f:read("*a"); f:close()
local chunk, err = loadstring(src, "@obf")
if not chunk then io.stderr:write("LOAD ERROR: " .. tostring(err) .. "\n"); os.exit(3) end
local ok, e = pcall(chunk)
if ok then
	print("[RESULT] ran-to-completion")
else
	print("[RESULT] crashed: " .. tostring(e))
end
