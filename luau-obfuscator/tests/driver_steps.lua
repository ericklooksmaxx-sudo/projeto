-- apply an arbitrary comma-separated step list (no settings) under LuaU
local root=(arg[0]:match("(.*[/\\])") or "./").."../"
package.path=root.."engine/?.lua;"..package.path
local P=require("prometheus"); P.Logger.logLevel=P.Logger.LogLevel.Error
local stepsCsv, infile, outfile = arg[1], arg[2], arg[3]
local f=io.open(infile,"rb"); local code=f:read("*a"); f:close()
local steps={}
for name in stepsCsv:gmatch("[^,]+") do steps[#steps+1]={Name=name, Settings={}} end
local cfg={LuaVersion="LuaU",NameGenerator="MangledShuffled",PrettyPrint=false,Seed=0,Steps=steps}
local t0=os.clock()
local out=P.Pipeline:fromConfig(cfg):apply(code,infile)
local o=io.open(outfile,"wb"); o:write(out); o:close()
io.stderr:write(string.format("steps=[%s] bytes=%d time=%.2fs\n", stepsCsv, #out, os.clock()-t0))
