#!/usr/bin/env lua5.1
-- Kyzen Obfuscator CLI
-- Usage: lua5.1 kyzen.lua [--preset NAME] [--out FILE] [--seed N]
--                        [--lua51|--luau] [--pretty] [--no-header] input.luau
-- Built on the Prometheus engine (engine/). Kyzen adds Roblox/LuaU hardening.

local function script_dir()
	local s = (debug.getinfo(1, "S").source:sub(2))
	return s:match("(.*[/\\])") or "./"
end
local root = script_dir()
package.path = root .. "engine/?.lua;" .. root .. "?.lua;" .. package.path

local Prometheus = require("prometheus")
local Config = Prometheus.Config
local Logger = Prometheus.Logger

-- Merge Kyzen presets over the engine presets.
local Presets = {}
for k, v in pairs(Prometheus.Presets) do Presets[k] = v end
for k, v in pairs(require("kyzen_presets")) do Presets[k] = v end

-- ---- arg parsing --------------------------------------------------------
local opts = { preset = "Kyzen_Medium", luaVersion = "LuaU", pretty = false, header = true }
local input
local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "--preset" or a == "-p" then i = i + 1; opts.preset = arg[i]
	elseif a == "--out" or a == "-o" then i = i + 1; opts.out = arg[i]
	elseif a == "--seed" then i = i + 1; opts.seed = tonumber(arg[i])
	elseif a == "--lua51" then opts.luaVersion = "Lua51"
	elseif a == "--luau" then opts.luaVersion = "LuaU"
	elseif a == "--pretty" then opts.pretty = true
	elseif a == "--no-header" then opts.header = false
	elseif a == "--bootstrap" then opts.bootstrap = true
	elseif a == "--no-bootstrap" then opts.bootstrap = false
	elseif a == "--bootstrap-protect" then opts.bootstrap = true; opts.bootstrapProtect = true
	elseif a == "--list" then
		print("Available presets:")
		local names = {}; for k in pairs(Presets) do names[#names+1] = k end; table.sort(names)
		for _, n in ipairs(names) do print("  " .. n) end
		os.exit(0)
	elseif a == "-h" or a == "--help" then
		print("Kyzen " .. Config.Version .. " - LuaU obfuscator")
		print("Usage: lua5.1 kyzen.lua [--preset NAME] [--out FILE] [--seed N] [--lua51|--luau]")
		print("                        [--pretty] [--no-header] [--bootstrap|--bootstrap-protect] input.luau")
		print("       lua5.1 kyzen.lua --list")
		print("")
		print("  --bootstrap          Wrap output in an encrypted runtime loader (outer layer)")
		print("  --bootstrap-protect  Like --bootstrap, and re-obfuscate the loader itself (2 layers)")
		os.exit(0)
	elseif a:sub(1,1) == "-" then
		io.stderr:write("Unknown option: " .. a .. "\n"); os.exit(1)
	else input = a end
	i = i + 1
end

if not input then io.stderr:write("KYZEN: no input file. Use -h for help.\n"); os.exit(1) end

local cfg = Presets[opts.preset]
if not cfg then io.stderr:write("KYZEN: unknown preset '" .. opts.preset .. "'. Use --list.\n"); os.exit(1) end

-- clone cfg so we don't mutate the shared preset table
local c = {}; for k, v in pairs(cfg) do c[k] = v end
c.LuaVersion = opts.luaVersion
c.PrettyPrint = opts.pretty
if opts.seed then c.Seed = opts.seed end

-- Drop steps whose implementation is not registered yet (partial builds).
local available = Prometheus.Pipeline.Steps
local steps = {}
for _, s in ipairs(cfg.Steps or {}) do
	if available[s.Name] then steps[#steps+1] = s
	else io.stderr:write("KYZEN: step '" .. s.Name .. "' not available yet, skipping.\n") end
end
c.Steps = steps

Logger.logLevel = Logger.LogLevel.Error

local f = io.open(input, "rb")
if not f then io.stderr:write("KYZEN: cannot open '" .. input .. "'\n"); os.exit(1) end
local code = f:read("*a"); f:close()

local pipeline = Prometheus.Pipeline:fromConfig(c)
local ok, out = pcall(function() return pipeline:apply(code, input) end)
if not ok then io.stderr:write("KYZEN: obfuscation error: " .. tostring(out) .. "\n"); os.exit(1) end

-- Resolve bootstrap: explicit flag wins, else preset default.
local wantBootstrap = opts.bootstrap
if wantBootstrap == nil then wantBootstrap = cfg.Bootstrap or false end
local wantProtect = opts.bootstrapProtect
if wantProtect == nil then wantProtect = cfg.BootstrapProtect or false end

if wantBootstrap and not opts.pretty then
	math.randomseed((opts.seed or cfg.Seed or os.time()) + 0x5bD1E7)
	local Bootstrap = require("bootstrap")
	out = Bootstrap.wrap(out, {})
	if wantProtect then
		-- Second layer: obfuscate the loader with a light VM+CFF pass.
		local loaderCfg = {
			LuaVersion = opts.luaVersion, NameGenerator = "MangledShuffled",
			PrettyPrint = false, Seed = (opts.seed or cfg.Seed or 0) + 1,
			Steps = {
				{ Name = "Vmify", Settings = {} },
				{ Name = "ConstantArray", Settings = { Threshold = 1, StringsOnly = true, Shuffle = true, Rotate = true, LocalWrapperThreshold = 0 } },
				{ Name = "WrapInFunction", Settings = {} },
			},
		}
		local ok2, out2 = pcall(function()
			return Prometheus.Pipeline:fromConfig(loaderCfg):apply(out, "kyzen-loader")
		end)
		if ok2 then out = out2
		else io.stderr:write("KYZEN: loader protect failed, keeping single layer: " .. tostring(out2) .. "\n") end
	end
end

if opts.header and not opts.pretty then
	out = Config.WatermarkHeader .. "\n" .. out
end

local outPath = opts.out or (input:gsub("%.lua[u]?$", "") .. ".kyzen.luau")
local o = io.open(outPath, "wb"); o:write(out); o:close()
io.stderr:write(string.format("KYZEN: %s (%s%s%s) -> %s [%d bytes]\n",
	opts.preset, opts.luaVersion,
	wantBootstrap and "+bootstrap" or "", wantProtect and "+protect" or "",
	outPath, #out))
