-- Kyzen smoke driver (runs under lua5.1)
local engineDir = (arg[0]:match("(.*[/\\])") or "./") .. "../engine/"
package.path = engineDir .. "?.lua;" .. package.path
local Prometheus = require("prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

local preset = arg[1] or "Strong"
local infile = arg[2] or "tests/sample_basic.luau"
local outfile = arg[3] or "tests/out.luau"

local f = io.open(infile, "rb"); local code = f:read("*a"); f:close()
local Presets = Prometheus.Presets
local cfg = Presets[preset]
cfg.LuaVersion = "LuaU"
local pipeline = Prometheus.Pipeline:fromConfig(cfg)
local ok, out = pcall(function() return pipeline:apply(code, infile) end)
if not ok then
  io.stderr:write("OBFUSCATION ERROR: "..tostring(out).."\n"); os.exit(1)
end
local o = io.open(outfile, "wb"); o:write(out); o:close()
print("OK preset="..preset.." bytes="..#out.." -> "..outfile)
