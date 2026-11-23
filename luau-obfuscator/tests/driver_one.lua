-- apply a single step with settings, output to file
local root=(arg[0]:match("(.*[/\\])") or "./").."../"
package.path=root.."engine/?.lua;"..package.path
local P=require("prometheus"); P.Logger.logLevel=P.Logger.LogLevel.Error
local stepName, infile, outfile = arg[1], arg[2], arg[3]
local f=io.open(infile,"rb"); local code=f:read("*a"); f:close()
local cfg={LuaVersion="LuaU",NameGenerator="MangledShuffled",PrettyPrint=false,Seed=0,
  Steps={{Name=stepName, Settings={Strict=true}}, {Name="Vmify",Settings={}}}}
local pipe=P.Pipeline:fromConfig(cfg)
local out=pipe:apply(code,infile)
local o=io.open(outfile,"wb"); o:write(out); o:close()
print("wrote "..outfile)
