local active_xpcall_func = nil
local wait_call_counts = {}
local pending_spawned_threads = {}
local in_spawn_harvest = false
-- TODO: add metatables that also have a real value like a string. For example for tostring returns on tables or sum!


local insert=table.insert
local _require=require
local settings={
    varnames=true, -- _someName69
    usesimplefunctions=false, -- functions wont be explored if true
    watchoutforloop=true, -- repetition guard, reported as a clean partial-dump notice
    spynilglobals=false, -- when true will spy all globals, even if they might not be a defined in a normal env
    hook_op=false, -- attempt to hook expressions like "==", "and", "or", "not" and more
    hook_op_default_return="original", -- "original", "spy", false, true
    log_lines=false,
    better_funcs=false, -- runs found functions after the main script finished!
}
local unfinishedfuncs,is_unfinished={},false
local thisfunction=debug.info(1,"f")
local specialhandle=false
local msecNotReady=false
local luraphnotready=0
local cenv,genv,analyzefunction,metatables,cclosures,types,func_to_name = {},{},nil,{},{},{},{}
local _tostring=tostring
local _tonumber=tonumber
local concat_me=`<dumper_concat>`
local concat_me_close=`</dumper_concat>`
local oldtype=type
local getmetatable=getmetatable
local pack,unpack=table.pack,unpack
local simplelog, isjunkie
local smart_unpack=function(packed)
    if packed and packed.n then
        return unpack(packed, 1, packed.n)
    end
    return unpack(packed or {})
end
local function tostring(var)
    if oldtype(var)=="table" and getmetatable(var) and getmetatable(var).__type=="context_type" then
        return _tostring(var)
    end
    -- if getmetatable(var)~=nil and (type(getmetatable(var))~="table" or getmetatable(var).__tostring) then
    --     return "scary-type"
    -- end
    return _tostring(var)
end
local getfenv, string, table, debug, pcall, rawget,require
    = getfenv, string, table, debug, pcall, rawget,require
getfenv().require=function()end
local function unpackchoose(packed,...)
    if packed then
        return unpack(packed)
    end
    return ...
end
local function multiunpack(...)
    local vars={}
    for _,packed in {...} do
        for _,v in packed do
            insert(vars,v)
        end
    end
    return unpack(vars)
end
local function tablefind(tbl, value)
    for index, val in next,tbl do
        if val == value then
            return index
        end
    end
    return false
end
local tbl_to_s,tostring_complex,type
local function multiinsert(target,items)
    for _,item in items do
        insert(target,item)
    end
end
local identifier=tostring(math.random(1000000,9999999))
local __dumperlocation="__dumperlocation"..tostring(math.random(1000000,9999999))
local Enum_NOCALL="NOCALL"..tostring(math.random(1000000,9999999))
local _print=print
local _xpcall=xpcall
local process = pcall(require, "@lune/process") and require("@lune/process") or require("@25msrequireluvsu/process")
local base_path=(process and oldtype(process.cwd)=="string" and process.cwd) or ""
base_path=base_path:gsub("[/\\]+$","")
local base_path_pattern=base_path:gsub("([^%w])","%%%1")

-- Strip only dumper internals here: paths, internal markers, module names and
-- sandbox source labels. Script-level error text is preserved for anti-tamper
-- checks, then cleaned again when it is written to the final output.
local function sanitize_internal_error(value)
    local msg=tostring(value or "")
    if base_path~="" then
        msg=msg:gsub(base_path_pattern.."[/\\]?","")
    end
    msg=msg:gsub("[%w_%-%./\\]*tracer[%w_%-%./\\]*:%d+:%s*","")
    msg=msg:gsub("%[string [^%]]+%]:%d+:%s*","")
    msg=msg:gsub("__DUMPER_LIMIT__:loop","the analysis stopped making progress")
    msg=msg:gsub("__DUMPER_LIMIT__:fenv","the environment stopped making progress")
    msg=msg:gsub("__DUMPER_LIMIT__:time","the analysis time limit was reached")
    msg=msg:gsub("__DUMPER_LIMIT__:output","the analysis output limit was reached")
    msg=msg:gsub("__DUMPER_LIMIT__:forced","the analysis limit was reached")
    msg=msg:gsub("__DUMPER_LIMIT__:[%w_]+","the analysis limit was reached")
    msg=msg:gsub("<dumper[^>]*>","")
    msg=msg:gsub("%s+"," ")
    msg=msg:gsub("^%s+",""):gsub("%s+$","")
    if msg=="" then msg="the script stopped unexpectedly" end
    return msg
end

-- Final user-facing text: no source paths, no sandbox line numbers and no
-- dumper internals. Keeps the useful part of ordinary runtime errors.
local function clean_display_error(value)
    local msg=sanitize_internal_error(value)
    msg=msg:gsub("^[%a][%w_ ]*:%d+:%s*","")
    msg=msg:gsub("^line %d+:%s*","")
    msg=msg:gsub("[%w_%-%./\\]+%.lua:%d+:%s*","")
    msg=msg:gsub("%s+"," ")
    msg=msg:gsub("^%s+",""):gsub("%s+$","")
    if #msg>180 then msg=msg:sub(1,177).."..." end
    if msg=="" then msg="the script stopped unexpectedly" end
    return msg
end

local function sanitize_output_string(value)
    if type(value)~="string" then return value end
    local res=value
    res=res:gsub("<dumper[^>]*>","")
    res=res:gsub("__DUMPER_LIMIT__:loop","the analysis stopped making progress")
    res=res:gsub("__DUMPER_LIMIT__:fenv","the environment stopped making progress")
    res=res:gsub("__DUMPER_LIMIT__:time","the analysis time limit was reached")
    res=res:gsub("__DUMPER_LIMIT__:progress","the analysis stopped making progress")
    res=res:gsub("__DUMPER_LIMIT__:output","the analysis output limit was reached")
    res=res:gsub("__DUMPER_LIMIT__:forced","the analysis limit was reached")
    res=res:gsub("__DUMPER_LIMIT__:[%w_]+","the analysis limit was reached")
    res=res:gsub("^[%a][%w_ ]*:%d+:%s*","")
    res=res:gsub("^line %d+:%s*","")
    res=res:gsub("[%w_%-%./\\]*tracer[%w_%-%./\\]*:%d+:%s*","")
    res=res:gsub("%[string [^%]]+%]:%d+:%s*","")
    if base_path~="" then
        res=res:gsub(base_path_pattern.."[/\\]?","")
    end
    return res
end
local is_bot=not not process.args[2]
-- The old build printed a scary "infinite loop" banner on every single run,
-- even successful ones. Status is now reported explicitly with tokens below.
local print=function(...)
    if is_bot and debug.info(2,"f")~=simplelog then
        return
    end
    local args={...}
    for i,v in args do
        if type(v)~="table" then
            args[i]=tostring(v):gsub(identifier.."_?","")
        end
    end
    _print(unpack(args))
end
local function evaluate_single_use_variables(r)
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        multiinsert(r,v:split("\n"))
    end
    local variables={}
    for i,v in r do
        local front,back
        if v:find("=", 1, true) and not v:find("{",1,true) and not v:find("function(",1,true) then
            local split=v:split("=")
            front=split[1]
            back=table.concat(split,"=",2)
            local _,c = front:gsub("_", "")
            if back==" ..." then
                local varargstr=front:split("local ")[2]
                varargstr=varargstr:sub(1,#varargstr-1)
                local varargcount=0
                for ii,v in r do
                    if ii<=i then
                        continue
                    end
                    if v:find(varargstr,1,true) then
                        local next=v:gmatch(varargstr..".") -- grr idk
                        r[ii]=v:gsub(varargstr,"...")
                    end
                    local firstname=varargstr:split(",")[1]
                    if r[ii]:find(firstname:sub(1,#firstname-1),1,true) then
                        -- print"hai"
                        varargcount+=1
                    end
                end
                if varargcount==0 then
                    r[i]=nil
                end
            end
            if c==2 and not front:find("[%.%[%]]") and not back:find("...",1,true) then
                insert(variables,{
                    name=front:split("_")[2],
                    amount=0,
                    location=i,
                    usedon={}
                })
            end
        else
            back=v
        end

        for _,data in variables do
            local match=data.name:gsub("([%^$().[%]*+?-])","%%%1")
            local _,c = back:gsub(match, "")
            for _=1,c do
                insert(data.usedon,i)
            end
            if front and not front:find("local") then
                _,c = v:gsub(match, "")
            end
            data.amount+=c
        end
    end
    for i=1,#variables do
        local data=variables[i]
        if data.amount==1 and r[data.usedon[1]] then
            local split=r[data.location]:split"="
            r[data.location]=nil
            local newback=table.concat(split,"=",2):gsub("%%","%%%%")
            -- print("usedon",r[data.usedon[1]],data.usedon[1],data.location)
            -- print("a",newback)
            r[data.usedon[1]]=r[data.usedon[1]]:gsub("_"..data.name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1").."_",newback)
        end
    end
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        if v~=nil then
            insert(r,v)
        end
    end
    return r
end
local function evaluate_stuff(r)
    for i,v in r do
        if v==nil then continue end
        local table_name
        -- print(v)
        r[i]=v:gsub("([%a%d_]+)%[\"(%a+)\"]%(([%a%d_]+)([,)])%s?",function(tbl,index,firstarg,ending)
            if tbl==firstarg then
                table_name=tbl
                return tbl..":"..index.."(" .. (ending==")" and ")" or "")
            end
        end):gsub("(.)<dumper_concat>([_%d%a\":%(%)%[%]]+)</dumper_concat>(.)",function(front,varname,back)
            local res=varname:gsub('\\"','"')
            -- print(front,varname,back)
            if front~='"' then
                res=front..'"..'..res
            end
            if back~='"' then
                res=res..'.."'..back
            end
            return res
        end)
        -- print("2",table_name,r[i-1])
        if table_name and r[i-1] then
            local previous=r[i-1]:split("=")
            local front=previous[1]
            local back=table.concat(previous,"=",2)
            if front:find(table_name,1,true) and table_name:find("%d") and not (front:find("function(",1,true) or front:find("{",1,true)) and not front:find("[%[%]]") and not front:find(",",1,true) and not (function()
                    local c=0
                    for ii=i,#r do
                        local _,cc = r[ii]:gsub(table_name:gsub("([%^$().[%]*+?-])","%%%1"), "")
                        c+=cc
                    end
                    return c>1
                end)()then
                r[i-1]=nil
                -- print("skibid",r[i],table_name,back:gsub("%%","%%%%"))
                r[i]=r[i]:gsub(table_name,(back:gsub("%%","%%%%")))
            end
        end
    end
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        if v~=nil then
            insert(r,(v:gsub(identifier.."_?","")))
        end
    end
    -- print(table.concat(r,"\n"))
end
local original_globals=getfenv()
local clock=os.clock
local startt=clock()
local commercial=false
local env_orig = (process and process.env and process.env.DUMPER_ORIG_DIR)
local inpath = if env_orig and env_orig ~= "" then env_orig else (commercial and "" or "dumps/original/")
if not inpath:match("[/\\]$") then inpath = inpath .. "/" end

local env_out = (process and process.env and process.env.DUMPER_OUT_DIR)
local outpath = if env_out and env_out ~= "" then env_out else (commercial and "" or "dumps/dumped/")
if not outpath:match("[/\\]$") then outpath = outpath .. "/" end

local fs = pcall(require, "@lune/fs") and require("@lune/fs") or require("@25msrequireluvsu/fs")
if fs and fs.isDir and not fs.isDir(outpath) then
    pcall(fs.writeDir, outpath)
end
local luau = pcall(require, "@lune/luau") and require("@lune/luau") or require("@25msrequireluvsu/luau")
local net_module = pcall(require, "@lune/net") and require("@lune/net") or require("@25msrequireluvsu/net")
local serde_module = pcall(require, "@lune/serde") and require("@lune/serde") or nil
local JsonDecode = function(str)
    if net_module and net_module.jsonDecode then
        return net_module.jsonDecode(str)
    elseif serde_module and serde_module.decode then
        return serde_module.decode("json", str)
    end
    return {}
end
local task = pcall(require, "@lune/task") and require("@lune/task") or require("@25msrequireluvsu/task")
-- local buffer=require("bufferlib")
local exec_env
do
    local ok_load, loaded = pcall(function() return luau.load(fs.readFile("env_shim.lua"))() end)
    exec_env = ok_load and loaded or {}
end
local targetfilename=process.args[1]
local user_id=process.args[2]
settings = (user_id and fs.isFile("dump_user_settings.json") and JsonDecode(fs.readFile("dump_user_settings.json"))[user_id]) or settings
local function hook_op(src)
    fs.writeFile("hook_op/file_cache/"..targetfilename,src)
    local response=(process.exec("lua",{"hook_op.lua",targetfilename}))
    if not response.ok then
        settings.hook_op=false
        return src
    end
    local newsrc=fs.readFile("hook_op/file_cache/"..targetfilename)
    local success,func,loads_er=pcall(luau.load,newsrc)
    -- _print(success,func,loads_er)
    if not (success and func) then
        settings.hook_op=false
        return src
    end
    local funcnames=table.concat({"_dumperLE","_dumperGR","_dumperLEEQ","_dumperGREQ","_dumperUNEQ","_dumperEQ","_dumperNOT","_dumperLEN","_dumperAND","_dumperOR","_dumperIF","_dumperELSEIF","_dumperWHILE","_dumperREPEAT","_dumperINDEX"},",")
    return "local "..funcnames.."="..funcnames..";"..newsrc
end
if not targetfilename then
    _print("DUMP_STATUS:FAIL")
    _print("DUMP_NOTE:no script was provided")
    return
end
local clean_target=targetfilename:match("([^/\\]+)$") or targetfilename
local urlPath=targetfilename:find("https://") and targetfilename
local resolved_file=if fs.isFile(targetfilename) then targetfilename
                    elseif fs.isFile(inpath..targetfilename) then inpath..targetfilename
                    elseif fs.isFile(inpath..clean_target) then inpath..clean_target
                    else nil
if not (urlPath or resolved_file) then
    _print("DUMP_STATUS:FAIL")
    _print("DUMP_NOTE:the script file could not be read")
    return
end
local request = net_module.request
local input = urlPath and (function()
    local cont=request({url=urlPath:gsub("/loaders/","/l/"),method ="GET",headers={["User-Agent"]="Xeno/RobloxApp/V1.0.9"}}).body
    targetfilename=process.args[3]
    if urlPath:find("https://api.junkie-development.de/api/v1/luascripts",1,true) then
        isjunkie=true
    end
    fs.writeFile(inpath..targetfilename,cont)
    return cont
end)()
or fs.readFile(resolved_file)

-- Luraph V15.1 ships with a UTF-8 BOM, and some exports use a shebang line.
-- Both are legal for text editors but not for luau.load, which reports
-- "Expected identifier when parsing expression, got Unicode character U+feff".
input=input:gsub("^\239\187\191","")
if input:sub(1,2)=="#!" then
    input=input:gsub("^#![^\r\n]*[\r\n]*","",1)
end
for _=1,3 do
    if not (input:find("&[lg]t;") or input:find("&amp;") or input:find("&quot;") or input:find("&#39;")) then break end
    input=input:gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&#39;","'"):gsub("&amp;","&")
end
input=input:gsub("[\r\n%s]*~%s*%$[\r\n%s]*$","")

local chunk,err
local variablecount,variable_backs,_dumperpredefined,spytbl,predefinefound=0,{},{}
local luraphcarry,luraphargs
settings.ignore_prom_globals=not not input:find("newproxy,setmetatable,getmetatable,select,{...})end)(...)",1,true)
if --[[input:find("[[This file was protected with MoonSec V3",1,true) and]] (input:find("=_ENV;[%a%d_]+='")) then
    msecNotReady=true
    if settings.spynilglobals then settings.spynilglobals=nil end
    if settings.hook_op then settings.hook_op=nil end
elseif input:find("(does your environment support load/loadstring?)",1,true) then
    local typeof=typeof
    local func=luau.load(input)
    local env=getfenv()
    local cenv={}
    local fenv_mt=setmetatable({},{__index=function(_,key)
        if key=="zeenjunkie"then
            isjunkie=true
        elseif not predefinefound and key=="_dumperpredefine" and input:find("_dumperpredefine",1,true) then
            predefinefound=true
            simplelog("_","_dumperpredefine","this function was referenced in the script, if you didnt do this place _dumperpredefine() on top of your script")
            return function(t)
                for i,v in t do
                    _dumperpredefined[i]=v
                end
            end
        end
        return cenv[key] or env[key]
    end})
    cenv.require=error
    env.require=error
    cenv.getfenv=function()return env end
    env.getfenv=cenv.getfenv
    local serde = require("@lune/serde")
    env.Enum = {
        CompressionAlgorithm = {
            Zstd="Zstd"
        }
    }
    local buffer=buffer
    local Services = {
        EncodingService={
            DecompressBuffer=function(_,tbl)
                local decompressedString = serde.decompress("Zstd",tbl)
                local buf = buffer.fromstring(decompressedString, "binary")
                return buf
            end
        }
    }
    env.game = {
        GetService=function(a,b)
            return Services[b]
        end
    }

    cenv.loadstring=function(src,...)
        if typeof(src)=="string" and #src>100--[[...=="Luraph"]] then
            luraphnotready=1
            input=src
            -- fs.writeFile("zzRun.lua",src)
            return function(...)
                luraphargs=table.pack(...)
                if typeof(...)=="string" and #...>100 then
                    luraphcarry=...
                end
                error("success")
            end
        end
        return luau.load(src,...)
    end
    setfenv(func,fenv_mt)
    local res={pcall(func)}
    if not is_bot then _print(unpack(res)) end
elseif input:find("=[\"']LPS") then
    specialhandle="LPS"
elseif input:find("{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},") then
    specialhandle="moonveil"
end
function tbl_to_s(tbl, indent, antioverflow)
    if not next(tbl) then return "{}" end
    indent = indent or 0
    local result = "{\n"-- "{"
    local spacing = string.rep(" ", indent + 2) -- " "
    for k, v in tbl do
        local key = "[" .. tostring_complex(k,false,antioverflow) .. "]"
        result = result .. spacing .. key .. " = " .. tostring_complex(v,false,antioverflow) .. ",\n"
    end
    result = result .. string.rep(" ", indent) .. "}"
    return result
end

local _pcall=pcall
-- if not input:find(expression) then
--     print("couldnt find anything to modify")
--     return
-- end
local runcode = settings.hook_op and hook_op(input) or input
-- if runcode==input then
--     warn("regex bad :(")
-- end
if not chunk then
    if runcode:find("while true.+do end") and not (runcode:find("if") or runcode:find("function")or runcode:find("break")) then
        _print("DUMP_STATUS:FAIL")
        _print("DUMP_NOTE:the script contains an unsupported unconditional loop")
        return
    end
    local ok_load,loaded_or_err=pcall(luau.load,runcode, luraphnotready>0 and "Luraph" or "sandbox")
    if not ok_load or not loaded_or_err then
        _print("DUMP_STATUS:FAIL")
        _print("DUMP_NOTE:the script could not be parsed")
        return
    end
    chunk=loaded_or_err
end
local env,debug_info=getfenv(chunk),debug.info
local c=0
local roblox_module = pcall(require, "@lune/roblox") and require("@lune/roblox") or nil
local raw_place = nil
local raw_ws = nil
local raw_players = nil
local raw_lp = nil
local raw_char = nil
local map_file = if (process and process.env and process.env.MAP_RBXL_PATH and fs.isFile(process.env.MAP_RBXL_PATH)) then process.env.MAP_RBXL_PATH
                 elseif fs.isFile("map.rbxl") then "map.rbxl"
                 elseif fs.isFile("/sdcard/Download/dumper/map.rbxl") then "/sdcard/Download/dumper/map.rbxl"
                 elseif fs.isFile("/var/task/map.rbxl") then "/var/task/map.rbxl"
                 else nil
if roblox_module and map_file then
    local ok, pl = pcall(function() return roblox_module.deserializePlace(fs.readFile(map_file)) end)
    if ok and pl then
        raw_place = pl
        pcall(function() raw_ws = raw_place:GetService("Workspace") end)
        pcall(function() raw_players = raw_place:GetService("Players") end)
        if raw_players and raw_ws then
            pcall(function()
                raw_lp = roblox_module.Instance.new("Player")
                raw_lp.Name = "LocalPlayer"
                raw_lp.Parent = raw_players
                
                raw_char = roblox_module.Instance.new("Model")
                raw_char.Name = "LocalPlayer"
                raw_char.Parent = raw_ws
                
                local hrp = roblox_module.Instance.new("Part")
                hrp.Name = "HumanoidRootPart"
                hrp.Position = roblox_module.Vector3.new(0, 10, 0)
                hrp.Parent = raw_char
                
                local hum = roblox_module.Instance.new("Humanoid")
                hum.Name = "Humanoid"
                hum.Health = 100
                hum.MaxHealth = 100
                hum.Parent = raw_char
                
                local head = roblox_module.Instance.new("Part")
                head.Name = "Head"
                head.Parent = raw_char
                
                raw_lp.Character = raw_char
            end)
        end
    end
end
local getglobalfuncname=function(func)
    -- not implemented, LOL!
end
type=function(var)
    -- _print(debug.traceback())
    local t=oldtype(var)
    return t=="table" and rawget(var,__dumperlocation) and "context_type" or t
end
local inuse=false
local getnewvar=function(varname)
    repeat until not inuse
    if varname and (type(varname)~="string" or varname:find("dumper",1,true) or not settings.varnames) then
        varname=nil
    end
    inuse=true
    variablecount+=1
    inuse=false
    return "_"..identifier..(varname and varname:gsub("[^A-Za-z0-9]", "") or "")..variablecount..identifier.."_"
end
local function genvars(num,name,vararg)
    local spyvars,vars={},{}
    local basevar=getnewvar(name)
    if num>0 then
        spyvars[1]=spytbl(basevar)
        vars[1]=basevar
        for i=2,num do
            insert(spyvars,spytbl(basevar.."_"..i))
            insert(vars,basevar.."_"..i)
        end
    end
    local varargvars,varargstr
    if vararg then
        varargvars,varargstr={},{}
        for i=1,10 do
            insert(varargvars,spytbl(basevar.."_vararg"..(i)))
            insert(varargstr,basevar.."_vararg"..(i))
        end
    end
    return spyvars,table.concat(vars,", "),varargvars, varargstr and table.concat(varargstr,", ") or nil
end
local function debug_getinfo(func_or_level,lol)
    if func_or_level==1 and lol=="l" then
        return
    end
    if type(func_or_level)=="context_type" then
        local varname=getnewvar("debug_getinfo")
        simplelog(varname,"debug.getinfo",func_or_level)
        return spytbl(varname)
    end
    local info = {}
    local target = type(func_or_level) == "number" and (func_or_level + 1) or func_or_level
    local ok_s, s_val, l_val, n_val, a_val, v_val, f_val = pcall(debug_info, target, "slnaf")
    if ok_s then
        info.source = s_val or "=[C]"
        info.short_src = s_val or "[C]"
        info.linedefined = l_val or -1
        info.lastlinedefined = l_val or -1
        info.currentline = l_val or -1
        info.name = n_val or ""
        info.namewhat = ""
        info.numparams = a_val or 0
        info.nparams = a_val or 0
        info.isvararg = v_val and 1 or 0
        info.is_vararg = v_val and 1 or 0
        info.func = f_val or (type(func_or_level) == "function" and func_or_level or nil)
        info.nups = 0
    end
    if (type(func_or_level) == "function" and cclosures[func_or_level]) or (info.func and cclosures[info.func]) then
        local fn_ref = type(func_or_level) == "function" and func_or_level or info.func
        local raw_n = (fn_ref and func_to_name[fn_ref]) or info.name or ""
        info.name = raw_n:match("%.([^%.]+)$") or raw_n
        info.namewhat = ""
        info.what = "C"
        info.source = "=[C]"
        info.short_src = "[C]"
        info.linedefined = -1
        info.lastlinedefined = -1
        info.currentline = -1
        info.nups = 0
        info.nparams = 0
        info.numparams = 0
        info.isvararg = 1
        info.is_vararg = 1
    else
        if type(info.short_src) == "string" then
            info.short_src = sanitize_output_string(info.short_src)
        else
            info.short_src = "[C]"
        end
        if type(info.source) == "string" then
            info.source = sanitize_output_string(info.source)
        else
            info.source = "=[C]"
        end
        info.what = (info.short_src == "[C]" or info.short_src == "=[C]") and "C" or "Lua"
    end
    return info
end
local special_replacements={}
local unclosed_blocks=0
local fenvused,genvused,currentR,fenv_mt
tostring_complex=function(var,ignoremt,antioverflow)
    local var_type=type(var)
    if special_replacements[var] then return special_replacements[var] end
    -- print(var,type(var),metatables[var],ignoremt)
    if type(var)=="context_type" then
        return var[__dumperlocation]
    elseif var==fenv_mt then
        fenvused=true
        return "fenv"
    elseif metatables[var] and not ignoremt then
        local clonemt
        local wasused=metatables[var].used
        if wasused then
            return wasused
        end
        metatables[var].used=metatables[var].used or getnewvar("t")
        local varname=metatables[var].used
        if metatables[var].mt then
            clonemt=table.clone(metatables[var].mt)
            for i in metatables[var].mt do
                metatables[var].mt[i]=nil
            end
        end
        insert(currentR,`local {varname} = {metatables[var].mt and "setmetatable(" or ""}{tostring_complex(var,true)}{metatables[var].mt and ","..tostring_complex(clonemt)..")" or ""}`)
        if clonemt then
            for i,v in clonemt do
                metatables[var].mt[i]=v
            end
        end
        return varname
    elseif var_type=="table"then
        if antioverflow and antioverflow[var] then
            return '{"<repeating table structure>"}'
        end
        antioverflow=antioverflow or {}
        antioverflow[var]=true
        return tbl_to_s(var,0,antioverflow)
    elseif var_type=="string" then
        local string_value=sanitize_output_string(var)
        if #string_value>9e9 then
            return '"<long string: '..(#string_value)..' bytes>"'
        end
        return (string.format("%q", tostring(string_value)):gsub("\\\n","\\n"):gsub(".",function(c)
            local byted=string.byte(c)
            if byted < 32 or byted > 126 then
                return string.format("\\x%02X", byted)
            end
        end))
    elseif var_type=="function" then
        if func_to_name[var] then
            return func_to_name[var]
        end
        local tablefindres=tablefind(cenv,var)
        if tablefindres then
            return tablefindres
        end
        if cclosures[var] or debug.info(var, "s")=="=[C]" or debug.info(var, "s")=="[C]" then
            local info=debug_getinfo(var)
            local n=info.name~="" and info.name or info.namewhat~="" and info.namewhat or "native_func"
            return n
        end
        local info=debug_getinfo(var)
        local name=info.namewhat~="" and info.namewhat or getglobalfuncname(var) or "~anonymous"
        local numargs, isvararg=debug.info(var, "a")
        local args,argstr,varargvars,varargstr=genvars(numargs,nil,isvararg)
        local before_unclosed=unclosed_blocks
        local returnR
        if not settings.better_funcs then
            returnR=analyzefunction(var,{},false,multiunpack(args,varargvars))
        else
            is_unfinished=true
            insert(unfinishedfuncs,{func=var,args=args,varargvars=varargvars})
        end
        local body_str = ""
        if returnR and #returnR > 0 then
            body_str = table.concat(returnR, "\n")
        elseif settings.better_funcs then
            body_str = "-- func" .. #unfinishedfuncs
        else
            body_str = "-- Callback action / state trigger\nreturn true"
        end
        local res= "function("..argstr..(varargstr and ((argstr~="" and "," or "").."...") or "")..")\n"
            .. (varargstr and "local "..varargstr.." = ...\n" or "")
            .. body_str
            .. "\nend"
        for _=before_unclosed,unclosed_blocks-1 do
            res=res.."\nend"
        end
        unclosed_blocks=before_unclosed
        return res
    elseif var_type=="userdata" then
        local luau_type = typeof(var)
        if luau_type == "Vector3" then
            return "Vector3.new(" .. tostring(var) .. ")"
        elseif luau_type == "Vector2" then
            return "Vector2.new(" .. tostring(var) .. ")"
        elseif luau_type == "CFrame" then
            return "CFrame.new(" .. tostring(var) .. ")"
        elseif luau_type == "Color3" then
            return "Color3.new(" .. tostring(var) .. ")"
        elseif luau_type == "UDim2" then
            return "UDim2.new(" .. tostring(var) .. ")"
        elseif luau_type == "UDim" then
            return "UDim.new(" .. tostring(var) .. ")"
        elseif luau_type == "BrickColor" then
            return "BrickColor.new(\"" .. tostring(var) .. "\")"
        elseif luau_type == "EnumItem" then
            return tostring(var)
        elseif luau_type == "Instance" then
            return "Instance.new(\"" .. var.ClassName .. "\")"
        end
        return tostring(var)
    elseif table.find({"boolean","number","nil"},var_type) then
        local tostringed=tostring(var)
        if tostringed=="nan" then
            return "0/0"
        elseif tostringed=="inf" then
            return "1/0"
        elseif tostringed=="-inf" then
            return "-1/0"
        end
        return tostringed
    else
        return "{"..tostring_complex("<unknown-type:"..tostring(var)..">").."}"
    end
end
local stringify=function(...)
    local data=table.pack(...)
    local stringified={}
    for i=1,data.n do
        insert(stringified,tostring_complex(data[i]))
    end
    return table.concat(stringified,", ")
end
local lastcouple,lastfound,lastinsert={},0,1
local loop_line,loop_started,loop_hits=nil,0,0
local function limitinsert(str)
    lastcouple[lastinsert]=str
    lastinsert=lastinsert%60+1
    lastfound=lastfound<60 and lastfound+1 or 60
end
local function getheight()
    for i=0,100 do
        local res=pcall(getfenv,i)
        if not res then return i-10 end
    end
end
local tfind,plserror=table.find
local DUMPER_LIMITS={
    analysis_seconds=100,
    max_output_lines=120000,
    max_output_bytes=4*1024*1024,
    max_line_length=16000,
    max_repeated_lines=6,
    flush_every=120,
    silent_seconds=25,
    fenv_flush_after=60000,
    fenv_abort_after=250000,
}
local analysis_started=nil
local analysis_active=false
local budget_exceeded=false
local partial_output=false
local partial_note=nil
local partial_flush_count=0
local last_output_at=0
local partial_path=outpath..clean_target:gsub("%.lua$","")..".partial.lua"
local last_emitted_line=nil
local repeated_line_count=1
local last_flush_at=0
local emitted_bytes=0
local last_flush_size=0

local function flush_partial(force)
    if not currentR or #currentR==0 then return end
    local size=#currentR
    if not force then
        -- Only rewrite when the fallback copy has grown meaningfully.
        if size<last_flush_size*2 and size-last_flush_size<500 then return end
    end
    partial_flush_count+=1
    local now=clock()
    if not force and partial_flush_count<DUMPER_LIMITS.flush_every
        and now-last_flush_at<1.5 then return end
    partial_flush_count=0
    last_flush_at=now
    last_flush_size=size
    local ok,text=pcall(table.concat,currentR,"\n")
    if not ok or type(text)~="string" or #text==0 then return end
    text=text:gsub(identifier.."_?","")
    if #text>DUMPER_LIMITS.max_output_bytes then
        text=text:sub(1,DUMPER_LIMITS.max_output_bytes).."\n-- [[output truncated]]"
    end
    pcall(fs.writeFile,partial_path,text)
end

local function check_budget()
    if budget_exceeded then
        error("__DUMPER_LIMIT__:time",0)
    end
    if not analysis_active then return end
    local now=clock()
    if analysis_started and now-analysis_started>DUMPER_LIMITS.analysis_seconds then
        budget_exceeded=true
        partial_output=true
        partial_note=partial_note or "the analysis time limit was reached"
        flush_partial(true)
        error("__DUMPER_LIMIT__:time",0)
    end
    if analysis_started and last_output_at>0 and now-analysis_started>3
        and now-last_output_at>DUMPER_LIMITS.silent_seconds then
        budget_exceeded=true
        partial_output=true
        partial_note=partial_note or "the analysis stopped making progress"
        flush_partial(true)
        error("__DUMPER_LIMIT__:progress",0)
    end
end

local function check_output_limit()
    if #currentR>=DUMPER_LIMITS.max_output_lines then
        budget_exceeded=true
        partial_output=true
        partial_note=partial_note or "the analysis output limit was reached"
        flush_partial(true)
        error("__DUMPER_LIMIT__:output",0)
    end
end

simplelog=function(varname,source,...)
    if msecNotReady then return end
    check_budget()
    local callargs=stringify(...)
    local back_string=source..(...~=Enum_NOCALL and ("("..callargs..")") or "")
    local write_string="local "..varname.." ="..back_string
    local smegstring=back_string:gsub("_[%a%d_]+","_var"):gsub("%d+","_num")
    local minus=35
    local structural=smegstring:match("^%s*[%)%}]+%s*$") or smegstring:match("^%s*end%s*$") or smegstring:match("^%s*else%s*$")
    if settings.watchoutforloop and not structural and #smegstring>3 and tfind(lastcouple,smegstring) then
        if loop_line~=smegstring then
            loop_line=smegstring
            loop_started=clock()
            loop_hits=0
        end
        loop_hits+=1
        lastfound=lastfound>minus and lastfound-minus or 0
        if loop_hits>20000 and clock()-loop_started>6 and varname~="er" then
            plserror=true
            budget_exceeded=true
            partial_output=true
            partial_note=partial_note or "the analysis stopped making progress"
            flush_partial(true)
            error("__DUMPER_LIMIT__:loop",0)
        end
    else
        loop_line=nil
        loop_hits=0
        lastfound=lastfound>minus and lastfound-minus or 0
    end
    limitinsert(smegstring)
    if settings.log_lines then
        local linenumber=debug.traceback():split"\n"
        for i,v in linenumber do
            if v:find("sandbox",1,true) then
                linenumber=v:split(":")[2]
                break
            end
        end
        if type(linenumber)=="string" then write_string..="-- line "..linenumber end
    end
    if write_string==last_emitted_line then
        repeated_line_count+=1
        if repeated_line_count>DUMPER_LIMITS.max_repeated_lines then
            if repeated_line_count==DUMPER_LIMITS.max_repeated_lines+1 then
                insert(currentR,"-- [[repeated output suppressed]]")
            end
            flush_partial(false)
            return
        end
    else
        last_emitted_line=write_string
        repeated_line_count=1
    end
    emitted_bytes+=#write_string+1
    if emitted_bytes>DUMPER_LIMITS.max_output_bytes then
        budget_exceeded=true
        partial_output=true
        partial_note=partial_note or "the analysis output limit was reached"
        flush_partial(true)
        error("__DUMPER_LIMIT__:output",0)
    end
    check_output_limit()
    print(write_string)
    multiinsert(currentR,write_string:split("\n"))
    last_output_at=clock()
    flush_partial(false)
    -- variable_backs[varname]=back_string
end
local function simplemath(operator)
    return function(left,right)
        local varname=getnewvar()
        insert(currentR,"local "..varname.." =(" .. tostring_complex(left)..operator..tostring_complex(right)..")")
        if operator=="==" and settings.hook_op_default_return~="spy" then
            if settings.hook_op_default_return=="original" then
                return rawequal(left,right)
            else
                return settings.hook_op_default_return
            end
        end
        return --[[operator=="==" and true or]] spytbl(varname)
    end
end
local smarthook=function(funcname,original)
    local f=function(...)
        local args=table.pack(...)
        for i=1,args.n do
            if type(args[i])=="context_type" then
                local varname=getnewvar(funcname)
                simplelog(varname,funcname,...)
                return spytbl(varname)
            end
        end
        return original(...)
    end
    cclosures[f]=true
    return f
end
local spymt={
    __index=function(_,key)
        check_budget()
        if (types[_]=="string" or _[__dumperlocation]:find("tostring",1,true) or _[__dumperlocation]:find("str",1,true)) and cenv.string and cenv.string[key] then
            return cenv.string[key]
        end
        local varname=getnewvar((_[__dumperlocation]:sub(1,1)~="_" and _[__dumperlocation] or "")..(type(key)=="string" and key or "Idx"))
        simplelog(varname,_[__dumperlocation].."["..tostring_complex(key).."]",Enum_NOCALL)
        if type(key)=="string" and _dumperpredefined[key]~=nil then
            return _dumperpredefined[key]
        elseif key=="lil skid tried to dump" then
            return
        end
        if key=="IsStudio" then
            return function()return false end
        end
        return spytbl(varname)
    end,
    __newindex=function(_,key,value)
        check_budget()
        check_output_limit()
        insert(currentR,_[__dumperlocation].."["..tostring_complex(key).."] ="..tostring_complex(value) .. (settings.log_lines and " -- line "..(function()
            local linenumber=debug.traceback():split"\n"
            for i,v in linenumber do
                if v:find("sandbox",1,true) then
                    linenumber=v:split(":")[2]
                    break
                end
            end
            return linenumber
        end)() or ""))
        flush_partial(false)
    end,
    __call=function(_,...)
        check_budget()
        if type((...))=="string" and (...):find("This is a signature - If you are seeing this, you know what not to do :3",1,true) then
            partial_output=true
            partial_note=partial_note or "the script stopped early"
            plserror=true
        end
        local varname=getnewvar("call"..(_[__dumperlocation]:sub(1,1)~="_" and _[__dumperlocation] or ""))
        simplelog(varname,_[__dumperlocation],...)
        local spy=spytbl(varname)
        -- local a,b,c=...
        -- if b=="HttpService" then
        --     insert(currentR,"_pmo()")
        --     if not _.HttpServiceSave then
        --         _.HttpServiceSave=spy
        --     else
        --         return _.HttpServiceSave
        --     end
        -- end
        return spy
    end,
    __concat=function(left,right)
        local varname=getnewvar()
        simplelog(varname,tostring_complex(left).." .. "..tostring_complex(right),Enum_NOCALL)
        return spytbl(varname)
    end,
    __tostring=function(_)
        return concat_me.._[__dumperlocation]..concat_me_close
    end,
    __iter=function(_,funcused)
        local ran=false
        return function(t,...)
            check_budget()
            if not ran then
                unclosed_blocks+=1
                local vars,varsstr=genvars(2)
                local mid=_[__dumperlocation]
                if funcused=="next" then
                    mid="next,"..mid
                elseif funcused then
                    mid=`{funcused}({mid})`
                end
                insert(currentR,`for {varsstr} in {mid} do`)
                ran=true
                return unpack(vars)
            end
            unclosed_blocks-=1
            insert(currentR,"end")
        end
    end,
    __len=function(_)
        check_budget()
        local returnvalue=math.random(1e3,1e9)
        local varname=getnewvar("len"..(_[__dumperlocation]:sub(1,1)~="_" and _[__dumperlocation] or ""))
        special_replacements[returnvalue]=varname
        insert(currentR,"local "..varname.." =#".._[__dumperlocation])--.." -- returning: " .. returnvalue .. " (if you see this number again you will know its from this!)")
        return returnvalue
    end,
    __add=simplemath"+",
    __sub=simplemath"- ",
    __mul=simplemath"*",
    __div=simplemath"/",
    __mod=simplemath"%",
    __pow=simplemath"^",
    __lt=simplemath"<",
    __le=simplemath"<=",
    __eq=simplemath"==",
    __unm=function(self)
        check_budget()
        local varname=getnewvar()
        insert(currentR,"local "..varname.." =" .. "-"..tostring_complex(self))
        return spytbl(varname)
    end,
    __type="context_type",
}
analyzefunction = function(chunk,r,lowestlayer,...)
    if plserror then return r end
    local oldR=currentR
    currentR=r
    cenv["__dumper_analyzing"]=true
    spytbl=function(pre,var_type)
        local tbl=setmetatable({
            [__dumperlocation]=pre,
        },spymt)
        if var_type then
            types[tbl]=var_type
        end
        return tbl
    end
    if settings.hook_op~=false then
        local log_if_needed=function(operation,a,b,actual)
            if type(a)=="context_type" or type(b)=="context_type" then
                local varname=getnewvar()
                local place_front=operation=="#" or operation=="not"
                simplelog(varname,(place_front and operation.." " or "")..(tostring_complex(a)..(not place_front and " "..operation.." " or "")..(not place_front and tostring_complex(b) or "")),Enum_NOCALL)
                local setting=settings.hook_op_default_return
                if setting=="spy" then
                    return spytbl(varname)
                elseif setting=="original" then
                    local success,result=pcall(actual)
                    return if success then result else 1
                else
                    if operation=="not" then
                        return not setting
                    end
                    return setting
                end
            end
            return actual()
        end
        cenv._dumperLE=function(a,b) return log_if_needed("<",a,b,(function()return(a < b)end)) end
        cenv._dumperGR=function(a,b) return log_if_needed(">",a,b,(function()return(a > b)end)) end
        cenv._dumperLEEQ=function(a,b) return log_if_needed("<=",a,b,(function()return(a <= b)end)) end
        cenv._dumperGREQ=function(a,b) return log_if_needed(">=",a,b,(function()return(a >= b)end)) end
        cenv._dumperUNEQ=function(a,b) return log_if_needed("~=",a,b,(function()return(a ~= b)end)) end
        cenv._dumperEQ=function(a,b)return log_if_needed("==",a,b,(function()return(a == b)end)) end
        cenv._dumperNOT=function(a) return log_if_needed("not",a,nil,(function()return(not a)end)) end
        cenv._dumperLEN=function(a) return log_if_needed("#",a,nil,(function()return(#a)end)) end

        cenv._dumperAND=function(a,b)
            if type(a)=="context_type" then
                b=b()
                local varname=getnewvar()
                simplelog(varname,(tostring_complex(a).." and "..tostring_complex(b)),Enum_NOCALL)
                if settings.hook_op_default_return=="original" then
                    return a and b
                end
                return settings.hook_op_default_return=="spy" and spytbl(varname) or settings.hook_op_default_return
            elseif a then
                b=b()
                if type(b)=="context_type" then
                    local varname=getnewvar()
                    simplelog(varname,(tostring_complex(a).." and "..tostring_complex(b)),Enum_NOCALL)
                    return settings.hook_op_default_return=="spy" and spytbl(varname) or settings.hook_op_default_return=="original" and b or settings.hook_op_default_return
                end
                return a and b
            else
                return a and b()
            end
        end
        cenv._dumperOR=function(a,b)
            local is_a_context=type(a)=="context_type"
            if is_a_context or not a then
                b=b()
                if is_a_context or type(b)=="context_type" then
                    local varname=getnewvar()
                    simplelog(varname,`({tostring_complex(a)} or {tostring_complex(b)})`,Enum_NOCALL)
                    return spytbl(varname)
                end
                return b
            else
                return a or b()
            end
        end

        cenv._dumperIF=function(a)if type(a)=="context_type" then insert(currentR,"CHECKIF("..tostring_complex(a)..")")end return a end
        cenv._dumperELSEIF=function(a)if type(a)=="context_type" then insert(currentR,"CHECKELSEIF("..tostring_complex(a)..")")end return a end
        local while_metas={}
        local while_counts={}
        cenv._dumperWHILE=function(a)
            check_budget()
            if type(a)=="context_type" then
                if while_metas[a] then
                    insert(currentR,"end")
                    return false
                end
                insert(currentR,"while "..tostring_complex(a).." do")
                while_metas[a]=true
                return a
            end
            local cs = debug.info(2, "l") or 0
            while_counts[cs] = (while_counts[cs] or 0) + 1
            if while_counts[cs] > 4096 then
                return false
            end
            return a
        end
        cenv._dumperREPEAT=function(a)
            check_budget()
            if type(a)=="context_type" then
                insert(currentR,"until "..tostring_complex(a))
                return true
            end
            return a
        end
        cenv._dumperINDEX=function(tbl)
            return setmetatable({},{
                __index=function(_,key)
                    if type(tbl)~="context_type" and type(key)=="context_type" then
                        local varname=getnewvar("idx")
                        metatables[tbl]=metatables[tbl] or {
                            mt=false,
                            used=false
                        }
                        simplelog(varname,`{tostring_complex(tbl)}[{tostring_complex(key)}]`,Enum_NOCALL)
                        return spytbl(varname)
                    end
                    return tbl[key]
                end,
                __newindex=function(_,key,value)
                    if type(tbl)~="context_type" and (type(key)=="context_type" and type(value)=="context_type") then -- OR WOULD BE COOL BUT DOESNT WORK ON OBF OKAY!
                        -- local varname=getnewvar()
                        metatables[tbl]=metatables[tbl] or {
                            mt=false,
                            used=false
                        }
                        insert(currentR,`{tostring_complex(tbl)}[{tostring_complex(key)}] = {tostring_complex(value)}`)
                        -- tbl[key]=spytbl(varname) -- could add ts i dunno :3
                    end
                    tbl[key]=value
                end,
                __type="opaque_type",
            })
        end
    end
    cenv.setmetatable=function(...)
        if select("#", ...) < 2 then return setmetatable(...) end
        local tbl,mt = ...
        if type(tbl)=="context_type" or tbl==fenv_mt or type(mt)=="context_type" then
            local varname=getnewvar("setmetatable")
            simplelog(varname,"setmetatable",tbl,mt)
            return spytbl(varname)
        end
        metatables[tbl]={
            mt=mt,
            used=false
        }
        return setmetatable(...)
    end
    cenv.setfenv=function(f, t)
        if type(f)=="function" and (cclosures[f] or debug.info(f, "s")=="=[C]" or debug.info(f, "s")=="[C]") then
            error("'setfenv' cannot change environment of given object", 2)
        end
        return env.setfenv(f, t)
    end
    cclosures[cenv.setfenv]=true
    func_to_name[cenv.setfenv]="setfenv" 
    local game_meta=table.clone(spymt)
    game_meta.__call=function()
        return error("game cant be called")
    end
    if specialhandle=="moonveil" then
        local og_index=game_meta.__index
        game_meta.__index=function(_,key)
            if type(key)=="string" then
                if key:sub(1,1):lower()==key:sub(1,1) or key:sub(#key,#key):upper()==key:sub(#key,#key)then
                    game_meta.__index=og_index
                    error"moonveil is bad"
                end
            end
            return og_index(_,key)
        end
    end
    local wrap_instance, lp_proxy, char_proxy
    local function make_mouse_proxy()
        local loc = "game.Players.LocalPlayer:GetMouse()"
        local make_sig = function(signame)
            return {
                Connect = function(_, cb)
                    local varname = getnewvar("conn")
                    simplelog(varname, loc .. "." .. signame .. ":Connect", cb)
                    return { Disconnect = function() end, Connected = true }
                end,
                connect = function(_, cb)
                    local varname = getnewvar("conn")
                    simplelog(varname, loc .. "." .. signame .. ":Connect", cb)
                    return { Disconnect = function() end, Connected = true }
                end,
                Once = function(_, cb)
                    local varname = getnewvar("conn")
                    simplelog(varname, loc .. "." .. signame .. ":Once", cb)
                    return { Disconnect = function() end, Connected = true }
                end,
                Wait = function(_)
                    return nil
                end,
            }
        end
        return {
            Hit = roblox_module and roblox_module.CFrame.new(0, 5, 0) or spytbl(loc .. ".Hit"),
            Target = cenv.workspace,
            X = 500,
            Y = 300,
            KeyDown = make_sig("KeyDown"),
            KeyUp = make_sig("KeyUp"),
            Button1Down = make_sig("Button1Down"),
            Button1Up = make_sig("Button1Up"),
            Button2Down = make_sig("Button2Down"),
            Button2Up = make_sig("Button2Up"),
            Move = make_sig("Move"),
            Idle = make_sig("Idle"),
            [__dumperlocation] = loc,
        }
    end

    wrap_instance = function(raw, loc)
        if not raw then return spytbl(loc) end
        return setmetatable({
            [__dumperlocation] = loc,
            __raw = raw,
        }, {
            __index = function(self, key)
                check_budget()
                if key == __dumperlocation then
                    return loc
                elseif key == "__raw" then
                    return raw
                elseif key == "Name" then
                    local ok, n = pcall(function() return raw.Name end)
                    return ok and n or tostring(key)
                elseif key == "ClassName" then
                    local ok, c = pcall(function() return raw.ClassName end)
                    return ok and c or "Instance"
                elseif key == "Parent" then
                    local ok, p = pcall(function() return raw.Parent end)
                    return (ok and p) and wrap_instance(p, loc .. ".Parent") or spytbl(loc .. ".Parent")
                elseif key == "GetService" and raw == raw_place then
                    return function(_, sname)
                        if sname == "Workspace" or sname == "workspace" then
                            return cenv.workspace
                        elseif sname == "Players" then
                            return cenv.Players
                        end
                        local ok_s, s = pcall(function() return raw_place:GetService(sname) end)
                        if ok_s and s then
                            return wrap_instance(s, "game:GetService(\"" .. sname .. "\")")
                        end
                        return spytbl("game:GetService(\"" .. sname .. "\")")
                    end
                elseif key == "FindFirstChild" then
                    return function(_, name, rec)
                        local varname = getnewvar("ffc")
                        if rec ~= nil then
                            simplelog(varname, loc .. ":FindFirstChild", name, rec)
                        else
                            simplelog(varname, loc .. ":FindFirstChild", name)
                        end
                        local ok_c, c = pcall(function() return raw:FindFirstChild(name, rec) end)
                        if ok_c and c then
                            return wrap_instance(c, varname)
                        end
                        return spytbl(varname)
                    end
                elseif key == "FindFirstChildOfClass" then
                    return function(_, className)
                        local ok_ch, children = pcall(function() return raw:GetChildren() end)
                        if ok_ch and children then
                            for _, c in ipairs(children) do
                                if c.ClassName == className then
                                    return wrap_instance(c, loc .. "[\"" .. c.Name .. "\"]")
                                end
                            end
                        end
                        return nil
                    end
                elseif key == "FindFirstChildWhichIsA" then
                    return function(_, className)
                        local ok_ch, children = pcall(function() return raw:GetChildren() end)
                        if ok_ch and children then
                            for _, c in ipairs(children) do
                                local ok_is, is = pcall(function() return c:IsA(className) end)
                                if ok_is and is then
                                    return wrap_instance(c, loc .. "[\"" .. c.Name .. "\"]")
                                end
                            end
                        end
                        return nil
                    end
                elseif key == "FindFirstAncestor" then
                    return function(_, name)
                        local cur = raw
                        while cur do
                            local ok_p, p = pcall(function() return cur.Parent end)
                            if not ok_p or not p then break end
                            cur = p
                            if cur.Name == name then
                                return wrap_instance(cur, loc .. ".Parent")
                            end
                        end
                        return nil
                    end
                elseif key == "FindFirstAncestorOfClass" then
                    return function(_, className)
                        local cur = raw
                        while cur do
                            local ok_p, p = pcall(function() return cur.Parent end)
                            if not ok_p or not p then break end
                            cur = p
                            if cur.ClassName == className then
                                return wrap_instance(cur, loc .. ".Parent")
                            end
                        end
                        return nil
                    end
                elseif key == "FindFirstAncestorWhichIsA" then
                    return function(_, className)
                        local cur = raw
                        while cur do
                            local ok_p, p = pcall(function() return cur.Parent end)
                            if not ok_p or not p then break end
                            cur = p
                            local ok_is, is = pcall(function() return cur:IsA(className) end)
                            if ok_is and is then
                                return wrap_instance(cur, loc .. ".Parent")
                            end
                        end
                        return nil
                    end
                elseif key == "WaitForChild" then
                    return function(_, name, timeout)
                        local varname = getnewvar("wfc")
                        if timeout ~= nil then
                            simplelog(varname, loc .. ":WaitForChild", name, timeout)
                        else
                            simplelog(varname, loc .. ":WaitForChild", name)
                        end
                        local ok_c, c = pcall(function() return raw:FindFirstChild(name) end)
                        if ok_c and c then
                            return wrap_instance(c, varname)
                        end
                        return spytbl(varname)
                    end
                elseif key == "GetChildren" then
                    return function(_)
                        local ok_ch, children = pcall(function() return raw:GetChildren() end)
                        local wrapped = {}
                        if ok_ch and children then
                            for _, c in ipairs(children) do
                                insert(wrapped, wrap_instance(c, loc .. "[\"" .. c.Name .. "\"]"))
                            end
                        end
                        return wrapped
                    end
                elseif key == "GetDescendants" then
                    return function(_)
                        local ok_ch, desc = pcall(function() return raw:GetDescendants() end)
                        local wrapped = {}
                        if ok_ch and desc then
                            for _, c in ipairs(desc) do
                                insert(wrapped, wrap_instance(c, loc .. "[\"" .. c.Name .. "\"]"))
                            end
                        end
                        return wrapped
                    end
                elseif key == "IsA" then
                    return function(_, className)
                        local ok_is, is = pcall(function() return raw:IsA(className) end)
                        return ok_is and is or false
                    end
                elseif key == "IsDescendantOf" then
                    return function(_, ancestor)
                        return false
                    end
                elseif key == "IsAncestorOf" then
                    return function(_, descendant)
                        return false
                    end
                elseif key == "GetFullName" then
                    return function(_)
                        return loc
                    end
                elseif key == "ClearAllChildren" then
                    return function(_)
                        pcall(function() raw:ClearAllChildren() end)
                    end
                elseif key == "Clone" then
                    return function(_)
                        local ok_cl, cl = pcall(function() return raw:Clone() end)
                        if ok_cl and cl then
                            return wrap_instance(cl, loc .. ":Clone()")
                        end
                        return wrap_instance(raw, loc .. ":Clone()")
                    end
                elseif key == "JSONDecode" or key == "JsonDecode" then
                    return function(_, str)
                        if type(str) == "string" and serde_module then
                            local ok_j, res = pcall(function() return serde_module.decode("json", str) end)
                            if ok_j and res then return res end
                        end
                        local varname = getnewvar("json")
                        simplelog(varname, loc .. ":JSONDecode", str)
                        return spytbl(varname)
                    end
                elseif key == "JSONEncode" or key == "JsonEncode" then
                    return function(_, val)
                        local varname = getnewvar("json")
                        simplelog(varname, loc .. ":JSONEncode", val)
                        if oldtype(val) == "table" and type(val) ~= "context_type" and serde_module then
                            local function sanitize_json(v, seen)
                                seen = seen or {}
                                if type(v) == "context_type" then
                                    return "<" .. tostring(rawget(v, __dumperlocation) or "expr"):gsub(identifier.."_?", "") .. ">"
                                elseif oldtype(v) == "table" then
                                    if seen[v] then return nil end
                                    seen[v] = true
                                    local out_t = {}
                                    for jk, jv in v do
                                        if jk ~= __dumperlocation and type(jv) ~= "function" then
                                            out_t[jk] = sanitize_json(jv, seen)
                                        end
                                    end
                                    return out_t
                                elseif type(v) == "function" or type(v) == "userdata" or type(v) == "thread" then
                                    return tostring(v)
                                end
                                return v
                            end
                            local ok_j, res = pcall(function() return serde_module.encode("json", sanitize_json(val)) end)
                            if ok_j and res then return res end
                        end
                        return "{}"
                    end
                elseif key == "GenerateGUID" then
                    return function(_, ...)
                        return "{00000000-0000-0000-0000-000000000000}"
                    end
                elseif key == "IsStudio" then
                    return function(_) return false end
                elseif key == "IsClient" then
                    return function(_) return true end
                elseif key == "IsServer" then
                    return function(_) return false end
                elseif key == "GetPlayers" then
                    return function(_) return { lp_proxy } end
                elseif key == "GetPlayerFromCharacter" then
                    return function(_, char) return lp_proxy end
                elseif key == "GetMouseLocation" then
                    return function(_) return roblox_module and roblox_module.Vector2.new(500, 300) or spytbl("Vector2") end
                elseif key == "Kick" or key == "kick" then
                    return function(_, ...)
                        local varname = getnewvar("kick")
                        simplelog(varname, loc .. ":Kick", ...)
                    end
                elseif key == "FireServer" or key == "fireServer" then
                    return function(_, ...)
                        local varname = getnewvar("fire")
                        simplelog(varname, loc .. ":FireServer", ...)
                        return spytbl(varname)
                    end
                elseif key == "InvokeServer" or key == "invokeServer" then
                    return function(_, ...)
                        local varname = getnewvar("invk")
                        simplelog(varname, loc .. ":InvokeServer", ...)
                        return spytbl(varname)
                    end
                elseif key == "Destroy" or key == "destroy" then
                    return function(_)
                        local varname = getnewvar("dst")
                        simplelog(varname, loc .. ":Destroy")
                    end
                elseif key == "Connect" or key == "connect" or key == "Once" then
                    return function(_, cb)
                        local varname = getnewvar("conn")
                        simplelog(varname, loc .. ":" .. key, cb)
                        return { Disconnect = function() end, Connected = true }
                    end
                end

                if raw == raw_place then
                    if key == "PlaceId" then return 2753915549
                    elseif key == "JobId" then return "mock-job-id-001"
                    elseif key == "GameId" then return 123456789
                    elseif key == "Workspace" or key == "workspace" then return cenv.workspace
                    elseif key == "Players" then return cenv.Players
                    elseif key == "Lighting" and raw_place:FindFirstChild("Lighting") then
                        return wrap_instance(raw_place:FindFirstChild("Lighting"), "game.Lighting")
                    elseif key == "ReplicatedStorage" and raw_place:FindFirstChild("ReplicatedStorage") then
                        return wrap_instance(raw_place:FindFirstChild("ReplicatedStorage"), "game.ReplicatedStorage")
                    end
                end

                if (raw == raw_players or loc == "game:GetService(\"Players\")" or loc == "game.Players") and key == "LocalPlayer" then
                    return lp_proxy
                end

                if raw == raw_lp and key == "Character" then
                    return char_proxy
                end

                if raw == raw_lp and key == "GetMouse" then
                    return make_mouse_proxy
                end

                local ok_ch, child = pcall(function() return raw:FindFirstChild(key) end)
                if ok_ch and child then
                    return wrap_instance(child, loc .. "[\"" .. tostring(key) .. "\"]")
                end

                local ok_p, prop = pcall(function() return raw[key] end)
                if ok_p and prop ~= nil then
                    if typeof(prop) == "Instance" then
                        return wrap_instance(prop, loc .. "[\"" .. tostring(key) .. "\"]")
                    elseif typeof(prop) == "function" then
                        return function(self_arg, ...)
                            local unwrapped = (type(self_arg) == "table" and self_arg.__raw) and self_arg.__raw or self_arg
                            local ok_call, res = pcall(prop, unwrapped, ...)
                            if ok_call then
                                if typeof(res) == "Instance" then
                                    return wrap_instance(res, loc .. ":" .. tostring(key) .. "(" .. stringify(...) .. ")")
                                elseif type(res) == "table" then
                                    local wrapped_tbl = {}
                                    for k, v in res do
                                        wrapped_tbl[k] = (typeof(v) == "Instance") and wrap_instance(v, loc .. ":" .. tostring(key) .. "()[" .. tostring(k) .. "]") or v
                                    end
                                    return wrapped_tbl
                                end
                                return res
                            end
                            local varname = getnewvar("call")
                            simplelog(varname, loc .. ":" .. tostring(key), ...)
                            return spytbl(varname)
                        end
                    end
                    return prop
                end

                if type(key) == "string" and (key == "Changed" or key == "ChildAdded" or key == "ChildRemoved" or key == "Touched" or key:find("Event$") or key:find("Click$")) then
                    local ev_loc = loc .. "." .. key
                    return setmetatable({
                        [__dumperlocation] = ev_loc,
                        Connect = function(_, cb)
                            local varname = getnewvar("conn")
                            simplelog(varname, ev_loc .. ":Connect", cb)
                            return { Disconnect = function() end, Connected = true }
                        end,
                        connect = function(_, cb)
                            local varname = getnewvar("conn")
                            simplelog(varname, ev_loc .. ":Connect", cb)
                            return { Disconnect = function() end, Connected = true }
                        end,
                        Once = function(_, cb)
                            local varname = getnewvar("conn")
                            simplelog(varname, ev_loc .. ":Once", cb)
                            return { Disconnect = function() end, Connected = true }
                        end,
                        Wait = function(_)
                            local varname = getnewvar("wait")
                            simplelog(varname, ev_loc .. ":Wait")
                            return spytbl(varname)
                        end,
                        FireServer = function(_, ...)
                            local varname = getnewvar("fire")
                            simplelog(varname, ev_loc .. ":FireServer", ...)
                            return spytbl(varname)
                        end,
                        fireServer = function(_, ...)
                            local varname = getnewvar("fire")
                            simplelog(varname, ev_loc .. ":FireServer", ...)
                            return spytbl(varname)
                        end,
                        InvokeServer = function(_, ...)
                            local varname = getnewvar("invk")
                            simplelog(varname, ev_loc .. ":InvokeServer", ...)
                            return spytbl(varname)
                        end,
                        invokeServer = function(_, ...)
                            local varname = getnewvar("invk")
                            simplelog(varname, ev_loc .. ":InvokeServer", ...)
                            return spytbl(varname)
                        end,
                    }, spymt)
                end

                local varname = getnewvar(loc:gsub("[^%a%d_]", "") .. "_" .. tostring(key):gsub("[^%a%d_]", ""))
                simplelog(varname, loc .. "[\"" .. tostring(key) .. "\"]", Enum_NOCALL)
                return spytbl(varname)
            end,
            __newindex = function(self, key, value)
                check_budget()
                check_output_limit()
                insert(currentR, loc .. "[\"" .. tostring(key) .. "\"] = " .. tostring_complex(value))
                flush_partial(false)
                pcall(function() raw[key] = value end)
            end,
            __tostring = function()
                return concat_me .. loc .. concat_me_close
            end,
            __type = "context_type",
        })
    end

    if raw_place then
        cenv.game = wrap_instance(raw_place, "game")
    else
        cenv.game = setmetatable({ [__dumperlocation] = "game" }, game_meta)
    end
    cenv.Game = cenv.game

    if raw_ws then
        cenv.workspace = wrap_instance(raw_ws, "workspace")
    else
        cenv.workspace = spytbl("workspace")
    end
    cenv.Workspace = cenv.workspace

    if raw_lp then
        lp_proxy = wrap_instance(raw_lp, "game.Players.LocalPlayer")
    else
        lp_proxy = spytbl("game.Players.LocalPlayer")
    end
    if raw_char then
        char_proxy = wrap_instance(raw_char, "game.Players.LocalPlayer.Character")
    else
        char_proxy = spytbl("game.Players.LocalPlayer.Character")
    end

    if raw_players then
        cenv.Players = wrap_instance(raw_players, "game:GetService(\"Players\")")
    else
        cenv.Players = spytbl("game:GetService(\"Players\")")
    end

    for _,name in {
                "Drawing","ypcall","gethwid","setfpscap",--[["os",]]"rconsoleprint",
                "rconsolewarn","package","makefolder","writefile","readfile","listfiles",
                "mkdir","isfile","delay","clonefunction","hookmetamethod",
                "setreadonly", "getrawmetatable", "fireproximityprompt",
                "Font","cloneref",
                "TweenInfo","OverlapParams","setclipboard","toclipboard",
                "hookmetatable","hookfunction","base64","Random","RaycastParams",
                "restorefunction","script","hookfunction","print",
                "request","http_request","httpRequest","HttpRequest","http",
                "warn","getconnections","hash",
                "Rect","getgc",
                "getcustomasset","_VERSION","PhysicalProperties","queue_on_teleport",
                "shared","gethui","fireproximityprompt","crypt","getnamecallmethod",
                "getconstants","cleardrawcache","WebSocket","isrenderobj",
                "setrenderproperty","getrenderproperty","setidentity","setthreadcontext",
                "getidentity","getthreadcontext","getthreadidentity","setthreadidentity",
                "getsenv","getscripts","getscripthash","getrunningscripts","queueonteleport",
                "isrbxactive","isgameactive","cache","checkcaller","getupvalue","DeepCopy",
                "DateTime","input","time","Vector3int16","Vector2int16",
            } do
        cenv[name]=spytbl(name)
    end

    cenv.Path2DControlPoint = {
        new = function(...)
            local a, b, c = ...
            if select("#", ...) > 0 and type(a) ~= "userdata" and type(a) ~= "context_type" then
                error("invalid argument #1 to 'new' (UDim2 expected)", 2)
            end
            local def_u2 = roblox_module and roblox_module.UDim2.new(0, 0, 0, 0) or spytbl("UDim2")
            return setmetatable({
                Position = a or def_u2,
                LeftTangent = b or def_u2,
                RightTangent = c or def_u2,
                [__dumperlocation] = "Path2DControlPoint.new(" .. stringify(...) .. ")",
            }, spymt)
        end
    }
    cclosures[cenv.Path2DControlPoint.new] = true
    func_to_name[cenv.Path2DControlPoint.new] = "Path2DControlPoint.new"

    if roblox_module then
        cenv.Vector3 = table.clone(roblox_module.Vector3)
        cenv.Vector3.FromAxis = function(...) return roblox_module.Vector3.fromAxis(...) end
        cenv.Vector3.FromNormalId = function(...) return roblox_module.Vector3.fromNormalId(...) end
        cenv.Vector2 = roblox_module.Vector2
        cenv.CFrame = roblox_module.CFrame
        cenv.Color3 = roblox_module.Color3
        cenv.UDim = roblox_module.UDim
        cenv.UDim2 = roblox_module.UDim2
        cenv.BrickColor = roblox_module.BrickColor
        cenv.Ray = roblox_module.Ray
        cenv.NumberRange = roblox_module.NumberRange
        cenv.NumberSequence = roblox_module.NumberSequence
        cenv.ColorSequence = roblox_module.ColorSequence
        cenv.NumberSequenceKeypoint = roblox_module.NumberSequenceKeypoint
        cenv.ColorSequenceKeypoint = roblox_module.ColorSequenceKeypoint
        cenv.PhysicalProperties = roblox_module.PhysicalProperties
        cenv.Rect = roblox_module.Rect
        cenv.Font = roblox_module.Font
        cenv.Enum = roblox_module.Enum
    else
        cenv.Vector3 = spytbl("Vector3")
        cenv.Vector2 = spytbl("Vector2")
        cenv.CFrame = spytbl("CFrame")
        cenv.Color3 = spytbl("Color3")
        cenv.UDim = spytbl("UDim")
        cenv.UDim2 = spytbl("UDim2")
        cenv.BrickColor = spytbl("BrickColor")
        cenv.Ray = spytbl("Ray")
        cenv.NumberRange = spytbl("NumberRange")
        cenv.NumberSequence = spytbl("NumberSequence")
        cenv.ColorSequence = spytbl("ColorSequence")
        cenv.TweenInfo = spytbl("TweenInfo")
        cenv.Enum = spytbl("Enum")
    end

    cenv.Instance = {
        new = function(className, parent)
            if type(className) ~= "string" and type(className) ~= "context_type" then
                error("invalid argument #1 to 'new' (string expected)", 2)
            end
            local varname = getnewvar(className)
            if parent then
                simplelog(varname, "Instance.new", className, parent)
            else
                simplelog(varname, "Instance.new", className)
            end
            if className == "Path2D" then
                local pts = {}
                local p2d_methods = {
                    GetControlPoints = function(self) return table.clone(pts) end,
                    SetControlPoints = function(self, new_pts)
                        simplelog("_", varname .. ":SetControlPoints", new_pts)
                        if type(new_pts) == "table" then pts = table.clone(new_pts) end
                    end,
                    GetControlPoint = function(self, idx)
                        return pts[idx] or cenv.Path2DControlPoint.new()
                    end,
                    GetLength = function(self) return 100 end,
                    GetBoundingRect = function(self)
                        return roblox_module and roblox_module.Rect.new(0, 0, 100, 100) or spytbl("Rect")
                    end,
                    GetMaxControlPoints = function(self) return 50 end,
                    GetPositionOnCurve = function(self, t)
                        return roblox_module and roblox_module.UDim2.new(t or 0.5, 0, t or 0.5, 0) or spytbl("UDim2")
                    end,
                    GetPositionOnCurveArcLength = function(self, t)
                        return roblox_module and roblox_module.UDim2.new(t or 0.5, 0, t or 0.5, 0) or spytbl("UDim2")
                    end,
                    GetTangentOnCurve = function(self, t)
                        return roblox_module and roblox_module.Vector2.new(1, 0) or spytbl("Vector2")
                    end,
                    GetTangentOnCurveArcLength = function(self, t)
                        return roblox_module and roblox_module.Vector2.new(1, 0) or spytbl("Vector2")
                    end,
                    UpdateControlPoint = function(self, idx, pt) pts[idx] = pt end,
                    InsertControlPoint = function(self, idx, pt) table.insert(pts, idx, pt) end,
                    RemoveControlPoint = function(self, idx) table.remove(pts, idx) end,
                    Destroy = function(self) simplelog("_", varname .. ":Destroy") end,
                }
                for mk, mv in p2d_methods do
                    cclosures[mv] = true
                    func_to_name[mv] = mk
                end
                return setmetatable({
                    [__dumperlocation] = varname,
                    __raw = true,
                    ClassName = "Path2D",
                    Name = "Path2D",
                }, {
                    __index = function(self, k)
                        if p2d_methods[k] then return p2d_methods[k] end
                        return spymt.__index(self, k)
                    end,
                    __newindex = spymt.__newindex,
                    __tostring = spymt.__tostring,
                    __type = "context_type",
                })
            end
            local raw = nil
            if roblox_module then
                pcall(function() raw = roblox_module.Instance.new(className) end)
            end
            if raw then
                if parent and type(parent) == "table" and rawget(parent, "__raw") then
                    pcall(function() raw.Parent = rawget(parent, "__raw") end)
                end
                return wrap_instance(raw, varname)
            end
            return spytbl(varname)
        end
    }
    cenv.tick=function()return os.clock()end
    cenv.Random={
        new=function(seed)
            if seed ~= nil and type(seed) ~= "number" and type(seed) ~= "context_type" then
                error("invalid argument #1 to 'new' (number expected)", 2)
            end
            local r_obj = {
                NextNumber=function(self, a, b)
                    if type(self) ~= "table" or (a ~= nil and type(a) ~= "number") or (b ~= nil and type(b) ~= "number") then error("invalid argument to 'NextNumber'", 2) end
                    if a and b then return a + math.random() * (b - a) end
                    return math.random()
                end,
                NextInteger=function(self, a, b)
                    if type(self) ~= "table" or type(a) ~= "number" or (b ~= nil and type(b) ~= "number") then error("invalid argument to 'NextInteger'", 2) end
                    if a and b then return math.random(a, b) end
                    return math.random(1, a or 100)
                end,
                NextUnitVector=function(self)
                    if type(self) ~= "table" then error("invalid argument to 'NextUnitVector'", 2) end
                    return roblox_module and roblox_module.Vector3.new(1, 0, 0) or spytbl("Vector3")
                end,
                Shuffle=function(self, t)
                    if type(self) ~= "table" or type(t) ~= "table" then error("invalid argument to 'Shuffle'", 2) end
                end,
                Clone=function(self)
                    if type(self) ~= "table" then error("invalid argument to 'Clone'", 2) end
                    return self
                end,
            }
            for rk, rv in r_obj do
                if type(rv) == "function" then cclosures[rv] = true; func_to_name[rv] = rk end
            end
            return r_obj
        end
    }
    for _, fn in {"rawequal", "rawlen", "select", "assert", "error"} do
        if env[fn] then
            cenv[fn] = env[fn]
            cclosures[env[fn]] = true
            func_to_name[env[fn]] = fn
        end
    end
    cenv._VERSION="Luau"
    cenv.bit=bit32
    cenv.bit32=bit32
    cenv.vector=vector
    cenv.utf8=table.clone(utf8)
    cenv.utf8.nfcnormalize=function(...)
        if select("#", ...) == 0 or type((...)) ~= "string" then error("invalid argument #1 to 'nfcnormalize' (string expected)", 2) end
        local str = ...
        local ok, res = pcall(function()
            local r = process.exec("python3", {"-c", "import unicodedata, sys; sys.stdout.buffer.write(unicodedata.normalize('NFC', sys.argv[1].encode('utf-8', 'surrogateescape').decode('utf-8')).encode('utf-8'))", str})
            return r.ok and r.stdout or str
        end)
        return ok and res or str
    end
    cenv.utf8.nfdnormalize=function(...)
        if select("#", ...) == 0 or type((...)) ~= "string" then error("invalid argument #1 to 'nfdnormalize' (string expected)", 2) end
        local str = ...
        local ok, res = pcall(function()
            local r = process.exec("python3", {"-c", "import unicodedata, sys; sys.stdout.buffer.write(unicodedata.normalize('NFD', sys.argv[1].encode('utf-8', 'surrogateescape').decode('utf-8')).encode('utf-8'))", str})
            return r.ok and r.stdout or str
        end)
        return ok and res or str
    end
    cenv.utf8.graphemes=function(...)
        if select("#", ...) == 0 or type((...)) ~= "string" then error("invalid argument #1 to 'graphemes' (string expected)", 2) end
        local str, i, j = ...
        if i ~= nil and type(i) ~= "number" then error("invalid argument #2 to 'graphemes' (number expected)", 2) end
        if j ~= nil and type(j) ~= "number" then error("invalid argument #3 to 'graphemes' (number expected)", 2) end
        i = i or 1
        j = j or #str
        local spans = {}
        local p = 1
        local len = #str
        local function is_combining(cp)
            return (cp >= 0x0300 and cp <= 0x036F)
                or (cp >= 0x1160 and cp <= 0x11FF)
                or (cp >= 0x3099 and cp <= 0x309A)
                or (cp >= 0xFE00 and cp <= 0xFE0F)
                or (cp >= 0x20D0 and cp <= 0x20FF)
                or (cp >= 0x1AB0 and cp <= 0x1AFF)
                or (cp >= 0x1DC0 and cp <= 0x1DFF)
                or (cp >= 0xFE20 and cp <= 0xFE2F)
        end
        while p <= len do
            local next_p = utf8.offset(str, 2, p) or (len + 1)
            local cp = utf8.codepoint(str, p)
            while next_p <= len do
                local next_cp = utf8.codepoint(str, next_p)
                local is_hangul_lv = (cp >= 0x1100 and cp <= 0x115F) and (next_cp >= 0x1160 and next_cp <= 0x11FF)
                if is_combining(next_cp) or is_hangul_lv then
                    next_p = utf8.offset(str, 2, next_p) or (len + 1)
                else
                    break
                end
            end
            if p >= i and p <= j then
                table.insert(spans, {p, next_p - 1})
            end
            p = next_p
        end
        local idx = 0
        return function()
            idx += 1
            if spans[idx] then return spans[idx][1], spans[idx][2] end
            return nil
        end
    end
    cenv.buffer=buffer
    local spynewcclosure=spytbl("newcclosure")
    cenv.newcclosure=function(...)
        local func=...
        local varname=getnewvar("cclosure")
        simplelog(varname,"newcclosure",...)
        local new_f=function(...)
            if type(func)=="function" then return func(...) end
        end 
        cclosures[new_f]=true
        func_to_name[new_f]=varname
        return new_f
    end
    cenv.newlclosure=function(...)
        local func=...
        local varname=getnewvar("lclosure")
        simplelog(varname,"newlclosure",...)
        local new_f=function(...)
            if type(func)=="function" then return func(...) end
        end
        func_to_name[new_f]=varname
        return new_f
    end
    cenv.clonefunction=function(func,...)
        local varname=getnewvar("cloned")
        simplelog(varname,"clonefunction",func,...)
        local new_f=function(...)
            if type(func)=="function" then return func(...) end
        end
        if type(func)=="function" and cclosures[func] then cclosures[new_f]=true end
        func_to_name[new_f]=varname
        return new_f
    end
    cenv.hookfunction=function(target, hook, ...)
        local varname=getnewvar("old_hook")
        simplelog(varname,"hookfunction",target,hook,...)
        return spytbl(varname)
    end
    cenv.replaceclosure=cenv.hookfunction
    cenv.hookmetamethod=function(obj, method, hook, ...)
        local varname=getnewvar("old_mm")
        simplelog(varname,"hookmetamethod",obj,method,hook,...)
        return spytbl(varname)
    end
    cenv.getconnections=function(sig, ...)
        local varname=getnewvar("conns")
        simplelog(varname,"getconnections",sig,...)
        local conn_entry = spytbl(varname .. "[1]")
        return { conn_entry }
    end
    cclosures[cenv.newcclosure]=true
    cenv.iscclosure=function(f)
        if cclosures[f] then return true end
        local ok, src = pcall(debug.info, f, "s")
        return ok and (src=="=[C]" or src=="[C]") or false
    end
    cenv.islclosure=function(f)
        return not cenv.iscclosure(f)
    end
    cclosures[cenv.iscclosure]=true
    cclosures[cenv.islclosure]=true
    func_to_name[cenv.iscclosure]="iscclosure"
    func_to_name[cenv.islclosure]="islclosure"

    cenv.isexecutorclosure=function(...)
        simplelog("_","isexecutorclosure",...)
        return true
    end
    cenv.require=function(...)
        local mod=...
        local t=type(mod)
        if t=="string" then
            error("module '"..tostring(mod).."' not found",2)
        end
        local varname=getnewvar("req")
        simplelog(varname,"require",...)
        return spytbl(varname)
    end
    cenv.tonumber=function(...)
        if select("#", ...) == 0 then return _tonumber() end
        local a = ...
        if type(a) == "context_type" then
            local varname = getnewvar("tonumber")
            simplelog(varname, "tonumber", ...)
            return nil
        end
        return _tonumber(...)
    end
    local library_budget_tick=0
    for _, k in {"print","warn","pcall","xpcall","select","unpack","tonumber","tostring","type","typeof","assert","error","getfenv","setfenv","rawget","rawset","rawequal","rawlen","setmetatable","getmetatable","pairs","ipairs","next"} do
        if env[k] then func_to_name[env[k]] = k end
        if cenv[k] then func_to_name[cenv[k]] = k end
    end
    for _,name in {"table","string","math","debug","os","coroutine","buffer"} do
        local og=env[name]
        cenv[name]={}
        for i,func in og do
            if i=="insert" then
                cenv[name][i]=og[i]
                cclosures[og[i]]=true
                func_to_name[og[i]]=name.."."..i
                continue
            elseif type(func)~="function" then
                cenv[name][i]=func
            else
                cenv[name][i]=function(...)
                    library_budget_tick+=1
                    if library_budget_tick>=256 then
                        library_budget_tick=0
                        check_budget()
                    end
                    local a,b,c=...
                    local has_context=false
                    for _argi=1,select("#",...) do
                        if type(select(_argi,...))=="context_type" then has_context=true; break end
                    end
                    if name=="coroutine" and i=="wrap" then
                        if type(a)~="function" and type(a)~="context_type" then
                            error("invalid argument #1 to 'wrap' (function expected)", 2)
                        end
                        if type(a)=="function" and not active_xpcall_func then
                            local varname=getnewvar("cowrap")
                            simplelog(varname,"coroutine.wrap",a)
                        end
                    end
                    if not has_context and name~="debug" and not (i=="find" and type(a)=="function") and not (i=="concat" and name=="table") and not (i=="create" and name=="table") and not (i=="char" and name=="string" and a==nil) then
                        return func(...)
                    end
                    if name=="debug" and (i=="info" or i=="getinfo") then
                        local isnumber=type(a)=="number"
                        if isnumber and a<0 then
                            return error("invalid argument #1 to 'info' (level can't be negative)")
                        elseif a==0 and b=="l" then
                            return -1
                        elseif isnumber and a>=1 then
                            local real_lvl = 1
                            for _step = 1, a do
                                real_lvl += 1
                                local cur_s = debug.info(real_lvl, "s")
                                if cur_s == "[C]" or cur_s == "=[C]" then
                                    local next_f = debug.info(real_lvl + 1, "f")
                                    local next_s = debug.info(real_lvl + 1, "s")
                                    if next_f and cclosures[next_f] and next_s ~= "[C]" and next_s ~= "=[C]" then
                                        real_lvl += 1
                                    end
                                end
                            end
                            for ii=1,real_lvl+1 do
                                local targetfunc=debug.info(ii,"f")
                                if targetfunc==analyzefunction then
                                    return
                                end
                            end
                            a = real_lvl - 1
                        end
                        a=isnumber and a+1 or a
                        local res=pack(func(a,b,c))
                        if b=="slnaf" and type(a)=="function" and cclosures[a] then
                            local diddlename
                            for k,v in cenv do
                                if a==v then
                                    diddlename=k
                                end
                            end
                            local raw_n = func_to_name[a] or diddlename or ""
                            local fn_name = raw_n:match("%.([^%.]+)$") or raw_n
                            return "[C]",-1,fn_name,0,true,a
                        end
                        return smart_unpack(res)
                    elseif i=="char" and name=="string" and a==nil and not active_xpcall_func then
                        return ""
                    elseif i=="concat" and name=="table" then
                        if type(a) == "table" then
                            for ii,v in a do
                                if type(v)=="context_type" then
                                    a[ii]=concat_me..tostring_complex(v)..concat_me_close
                                end
                            end
                        elseif type(a) ~= "context_type" then
                            return func(...)
                        end
                    elseif i=="create" and name=="table" then
                        if type(a) ~= "number" or active_xpcall_func then
                            return func(...)
                        elseif a<0 then
                            return {}
                        end
                    end
                    if i=="find" and type(a)=="function" then
                        local varname=getnewvar("find")
                        simplelog(varname,"string.find",a,b,c)
                        return spytbl(varname)
                    end
                    local real_res=has_context and not table.find({"pack","move","unpack"},i) or {func(...)}
                    if i=="traceback" and name=="debug" and type(real_res[1])=="string" then
                        real_res[1]=real_res[1]:gsub("%[string \"%.\\tracer\"%]:%d+\n",""):gsub("%[string \"sandbox\"%]:(%d+)\n","[string \"DontDtcTsPls\"]:%1\n")
                    end
                    if (has_context and not table.find({"pack","move","unpack"},i) or real_res[1]=="[string \"./tracer\"]") then
                        local num_returns = (name == "string" and (i == "find" or i == "gsub")) and 2 or 1
                        local vars,varstr=genvars(num_returns)
                        simplelog(varstr,name.."."..i,...)
                        return unpack(vars)
                    end
                    return unpack(real_res)
                end
                cclosures[cenv[name][i]]=true
                func_to_name[cenv[name][i]]=name.."."..i
                func_to_name[func]=name.."."..i
            end
        end
        if name=="debug" then
            cenv.debug.getinfo=debug_getinfo
            for i,v in {"getlocal","setlocal","sethook",--[["gethook"]]"getregistry","getmetatable","setmetatable","setupvalue"} do
                cenv.debug[v]=spytbl("debug."..v,"function")
            end
            cenv.debug.getupvalues=function(f)
                simplelog("_calldebuggetupvalues","debug.getupvalues",f)
                return {}
            end
            cenv.debug.getupvalue=function(f,idx)
                simplelog("_calldebuggetupvalue","debug.getupvalue",f,idx)
                return nil
            end
            cclosures[cenv.debug.getupvalues]=true
            cclosures[cenv.debug.getupvalue]=true
            func_to_name[cenv.debug.getupvalues]="debug.getupvalues"
            func_to_name[cenv.debug.getupvalue]="debug.getupvalue"
        end
        if name~="debug" then table.freeze(cenv[name]) end
    end
    -- local enumspytbl
    -- enumspytbl=function(pre)
    --     return setmetatable({
    --         [__dumperlocation]=pre
    --     },{
    --         __index=function(_,key)
    --             return enumspytbl(pre.."."..key)
    --         end,
    --         __type="context_type",
    --         __tostring=function()
    --             return "<Enum: "..pre..">"
    --         end
    --     })
    -- end
    -- Keep roblox_module.Enum from line 1650 if available
    cenv.pcall=function(...)
        if select("#", ...) == 0 then return _pcall() end
        local res = table.pack(_pcall(...))
        if not res[1] and type(res[2])=="string" then
            if res[2]:find("__DUMPER_LIMIT__", 1, true) then
                error(res[2], 0)
            elseif res[2]:find("__DUMPER_YIELD_BREAK__", 1, true) then
                return true
            end
        end
        return unpack(res, 1, res.n)
    end
    cenv.xpcall=function(f, err_handler, ...)
        if type(err_handler) ~= "function" then return _xpcall(f, err_handler, ...) end
        local prev_xp = active_xpcall_func
        active_xpcall_func = true
        local res = table.pack(_xpcall(f, err_handler, ...))
        active_xpcall_func = prev_xp
        if not res[1] and type(res[2])=="string" and res[2]:find("__DUMPER_LIMIT__", 1, true) then
            error(res[2], 0)
        end
        return unpack(res, 1, res.n)
    end
    cclosures[cenv.pcall]=true
    cclosures[cenv.xpcall]=true
    func_to_name[cenv.pcall]="pcall"
    func_to_name[cenv.xpcall]="xpcall"

    if input:find("newproxy, setmetatable, getmetatable, select,",1,true) then
        local error_just_called
        cenv.pcall = function(...)
            if select("#", ...) == 0 then return _pcall() end
            local results = table.pack(_pcall(...))
            if error_just_called then
                error_just_called = false
                return unpack(results, 1, results.n)
            end
            local first = results[1]
            if type(first) == "boolean" and first == false then
                local second = results[2]
                if type(second) == "string" and second:find("sandbox", 1, true) then
                    results[2] = (second:gsub(":(%d+)([:\r\n])", ":1%2"))
                end
            end
            return unpack(results, 1, results.n)
        end
        cclosures[cenv.pcall]=true
        func_to_name[cenv.pcall]="pcall"
        local _error = error
        cenv.error = function(...)
            error_just_called = true
            return _error(...)
        end
        cclosures[cenv.error]=true
        func_to_name[cenv.error]="error"
    end
    for _,v in {"pairs","ipairs"} do
        cenv[v]=function(...)
            local tbl = ...
            if type(tbl)=="context_type" then
                local mt=getmetatable(tbl)
                if not mt or not mt.__iter then
                    simplelog("_",v,tbl)
                    return function()end
                end
                return mt.__iter(tbl,v)
            else return env[v](...)
            end
        end
    end
    local nextcalls={}
    cenv.next=function(...)
        local tbl = ...
        if type(tbl)=="context_type" then
            if select("#", ...) > 1 and nextcalls[tbl] then
                return nextcalls[tbl](...)
            end
            local func=getmetatable(tbl).__iter(tbl,"next")
            nextcalls[tbl]=func
            return func(...)
        else return env.next(...)
        end
    end
    cenv.ishooked=function(...)
        simplelog("_","ishook",...)
        return false
    end
    cenv.IsHooked=function(...)
        simplelog("_","IsHooked",...)
        return false
    end
    cenv.isfunctionhooked=function(...)
        simplelog("_","isfunctionhooked",...)
        return false
    end
    cenv.wait=function(...)
        local cs = tostring(debug.info(2, "s") or "") .. ":" .. tostring(debug.info(2, "l") or 0)
        wait_call_counts[cs] = (wait_call_counts[cs] or 0) + 1
        if wait_call_counts[cs] > 3 then
            error("__DUMPER_YIELD_BREAK__", 0)
        end
        simplelog("_","wait",...)
        return ((...) or 0)+math.random()/10
    end
    cenv.loadstring=function(src,...)
        local varname=getnewvar()
        if type(src)=="string" then
            if not(type(src)=="string" and src:find(".@%(/*,.......      ...,,*/(#%&@@.\n                     (*   ,/(#%%&&@@@@&%((////(((##%###((/**,,.     ,//(&.\n                   /* .%@@@@@@@@%",1,true)) then
                simplelog(varname,"loadstring",src,...)
            end
            src=settings.hook_op and hook_op(src) or src
            local success,_func,a=_pcall(luau.load,src,(...) or "dumper_loadstring")
            if not success then
                return nil,_func
            end
            local _funcenv=getfenv(_func)
            if _funcenv.require~=cenv.require then
                setfenv(_func,setmetatable({},{__index=function(_,key)
                    return cenv[key] or _funcenv[key]
                end}))
            end
            return _func,a
        elseif type(src)=="context_type" then
            simplelog(varname,"loadstring",src)
            return function(...)
                local func_varname=getnewvar()
                simplelog(func_varname,varname,...)
                return spytbl(func_varname)
            end
        else
            return luau.load(src, ...)
        end
    end
    -- cenv.request=function()
    --     return setmetatable({
    --         StatusCode=200,
    --     },{
    --         __index=function(_,key)
    --             cenv.print("idx",key)
    --             return spytbl("_dumperR."..key)
    --         end
    --     })
    -- end
    if msecNotReady then
        cenv.allowLogging=function()
            msecNotReady=false
            cenv.allowLogging=nil
            cenv.SetCenv=nil
        end
        cenv.SetCenv=function(key,value)
            cenv[key]=value
        end
    end
    cenv.ce_like_loadstring_fn=cenv.loadstring
    cenv.script_key="c4ce76cd36f2afee4dcee7e87576e5fa"
    local _rawset=rawset
    local tsenv={}
    cenv.getgenv=function()
        -- return genv
        return setmetatable({
            [__dumperlocation]="genv",
        },{__index=function(_,key)
            local varname=getnewvar()

            insert(currentR,"local "..varname.." =genv["..stringify(key).."]")
            -- if key=="Token" or key=="AdoptMe" then return nil end
            if settings.spynilglobals and _dumperpredefined[key]==nil and genv[key]==nil then
                return spytbl(varname)
            end
            return _dumperpredefined[key] or genv[key] or cenv[key] or env[key]
        end,__newindex=function(_,k,v)
            genvused=true
            insert(currentR,"genv["..stringify(k).."]="..tostring_complex(v))
            genv[k]=v
        end,
        __type="context_type"})
    end
    cenv.getrenv=function()
        return setmetatable({
            [__dumperlocation]="renv",
        },{__index=cenv,__newindex=function(_,k,v)
            insert(currentR,"getrenv()["..stringify(k).."]="..tostring_complex(v))
        end,__type="context_type"})
    end
    cenv._G=setmetatable({
        [__dumperlocation]="_G"
    },{__index=function(_,key)
        insert(currentR,"local _ =_G["..stringify(key).."]")
        return rawget(_,key) or _dumperpredefined[key] or cenv[key] or genv[key] or env[key]
    end,__newindex=function(_,k,v)
        insert(currentR,"_G["..stringify(k).."]="..tostring_complex(v)..(settings.log_lines and " -- line "..(function()
                            local linenumber=debug.traceback():split"\n"
                            for i,v in linenumber do
                                if v:find("sandbox",1,true) then
                                    linenumber=v:split(":")[2]
                                    break
                                end
                            end
                            return linenumber
                        end)() or ""))
        rawset(_,k,v)
    end,
    __type="context_type"})
    local main_thread = coroutine.running()
    cenv.task=setmetatable({
        wait=function(...)
            local t_arg = ...
            if t_arg ~= nil and type(t_arg) ~= "number" and type(t_arg) ~= "context_type" then
                error("invalid argument #1 to 'wait' (number expected)", 2)
            end
            local cs = tostring(debug.info(2, "s") or "") .. ":" .. tostring(debug.info(2, "l") or 0)
            wait_call_counts[cs] = (wait_call_counts[cs] or 0) + 1
            if wait_call_counts[cs] > 3 then
                error("__DUMPER_YIELD_BREAK__", 0)
            end
            simplelog("_","task.wait",...)
            local ret = (type(t_arg) == "number" and t_arg or 0) + math.random()/10
            if not in_spawn_harvest and main_thread and coroutine.running() ~= main_thread and coroutine.isyieldable() then
                return coroutine.yield(ret)
            end
            return ret
        end,
        spawn=function(f,...)
            if type(f)~="function" and type(f)~="thread" and type(f)~="context_type" then
                return coroutine.create(f)
            end
            if type(f) == "function" then
                local co = coroutine.create(f)
                local saved_r_len = #currentR
                local ok, res = coroutine.resume(co, ...)
                if coroutine.status(co) == "suspended" then
                    -- Roll back partial lines emitted before yield; if not closed by anti-tamper, we will harvest the full function body at the end!
                    for idx = #currentR, saved_r_len + 1, -1 do
                        table.remove(currentR, idx)
                    end
                    table.insert(pending_spawned_threads, { co = co, kind = "task.spawn", f = f, args = table.pack(...) })
                end
                return co
            elseif type(f) == "thread" then
                coroutine.resume(f, ...)
                return f
            end
            simplelog("_","task.spawn",f,...)
            return coroutine.create(function() end)
        end,
        defer=function(f,...)
            if type(f)~="function" and type(f)~="thread" and type(f)~="context_type" then
                return coroutine.create(f)
            end
            local co = type(f)=="thread" and f or coroutine.create(type(f)=="function" and f or function() end)
            if type(f)=="function" then
                table.insert(pending_spawned_threads, { co = co, kind = "task.defer", f = f, args = table.pack(...) })
            else
                simplelog("_","task.defer",f,...)
            end
            return co
        end,
        delay=function(t,f,...)
            if (t~=nil and type(t)~="number" and type(t)~="context_type") then
                error("invalid argument #1 to 'delay' (number expected)", 2)
            end
            if type(f)~="function" and type(f)~="thread" and type(f)~="context_type" then
                return coroutine.create(f)
            end
            local co = type(f)=="thread" and f or coroutine.create(type(f)=="function" and f or function() end)
            if type(f)=="function" then
                table.insert(pending_spawned_threads, { co = co, kind = "task.delay", t = t, f = f, args = table.pack(...) })
            else
                simplelog("_","task.delay",t,f,...)
            end
            return co
        end,
        cancel=function(th)
            if type(th)~="thread" and type(th)~="context_type" then
                return coroutine.close(th)
            end
            if type(th)=="thread" then pcall(coroutine.close, th) end
            simplelog("_","task.cancel",th)
        end,
        desynchronize=function() simplelog("_","task.desynchronize") end,
        synchronize=function() simplelog("_","task.synchronize") end,
    },{
        __index=spytbl("task"),
    })
    for tk, tv in cenv.task do
        if type(tv) == "function" then
            cclosures[tv] = true
            func_to_name[tv] = "task." .. tk
        end
    end
    cenv.spawn=function(f,...)
        simplelog("_","spawn",f,...)
        if type(f)=="function" then pcall(f,...) end
    end
    cenv.delay=function(t,f,...)
        simplelog("_","delay",t,f,...)
        if type(f)=="function" then pcall(f,...) end
    end
    cenv.getfenv=function(lvl)
        local origlvl=lvl
        if type(lvl)=="number" and lvl<0 then return error("invalid argument #1 to 'getfenv' (level must be non-negative)") end
        if type(lvl)=="boolean" then return error("invalid argument #1 to 'getfenv' (number expected, got boolean)") end
        lvl=lvl and (type(lvl)=="number" and lvl+1 or lvl) or 2
        local res=getfenv(table.find({"function","number"},type(lvl)) and lvl or nil)
        local res_mt=getmetatable(res)
        if rawget(res,"require")==_require or (type(res_mt)=="table" and type(res_mt.__index)=="table" and res_mt.__index.require==_require) or (res_mt~=nil and type(res_mt~="table"))then
            -- local varname=getnewvar()
            -- simplelog(varname,"getfenv",origlvl)
            -- return spytbl(varname)
            return fenv_mt
        end
        return res
    end
    cenv.identifyexecutor=function()
        local vars,varstr=genvars(2)
        simplelog(varstr,"identifyexecutor")
        return vars[1],vars[2]
    end
    -- cenv.identifyexecutor=function()
    --     return "Wave"
    -- end
    cenv.getexecutorname=function()
        local varname=getnewvar()
        simplelog(varname,"getexecutorname")
        return spytbl(varname)
    end
    local fake_file_system={}
    cenv.writefile=function(path,cont)
        simplelog("_","writefile",path,cont)
        fake_file_system[path]=cont
    end
    cenv.appendfile=function(path,cont)
        simplelog("_","appendfile",path,cont)
        if fake_file_system[path] then
            fake_file_system[path]=fake_file_system[path]..cont
        else
            fake_file_system[path]=cont
        end
    end
    cenv.readfile=function(path)
        local varname=getnewvar()

        return fake_file_system[path]
    end
    cenv.isfile=function(path)
        return fake_file_system[path]~=nil
    end
    cenv.isfolder=function(path)
        return fake_file_system[path]~=nil
    end
    cenv.mkdir=function(path)
        simplelog("_","mkdir",path)
        fake_file_system[path]={}
    end
    cenv.listfiles=function(path)
        local varname=getnewvar()
        simplelog(varname,"listfiles",path)
        local res={}
        for i,v in fake_file_system do
            if table.concat(v:reverse():split("/"),"/",2):reverse()==path then
                insert(res,i)
            end
        end
        return spytbl(varname)
    end
    for i,v in cenv do
        genv[i] = v
    end
    local typin_check=false
    cenv._dumpersigma=function(...) if ...=="meow :3" then error("Controlled shutdown") end end
    cenv.type=function(...)
        if select("#", ...) == 0 then return oldtype() end
        local res=type(...)
        if ...=="dumper is such a god" then typin_check=true;
                return "my dihh hurts"
        elseif typin_check==true and res=="table" and (...)[1]=="bat is gay" then
            local calledtimes,extreme_meow=math.random(1,10),0
            local meow_obj
            for i=1,calledtimes do
                local len=math.random(1,3)
                local str=string.rep(".",len)
                if extreme_meow+len>100 then
                    str=""
                else
                    extreme_meow+=len
                end
                meow_obj=(...)[str]
            end
            meow_obj[__dumperlocation]="meow_obj"
            setmetatable(meow_obj,{
                __index=function(_,key)
                    if key==extreme_meow then
                        return string.rep(" ",calledtimes-1).."\x1B"
                    elseif key==420 then
                        return "\x1B"
                    end
                    return string.rep(" ",math.random(1,20))
                end,
                __type="context_type",
                __metatable=false
            })
            return nil
        end
        if typeof((...)) == "Vector3" then
            return "vector"
        elseif oldtype((...)) == "table" and rawget((...), "__raw") then
            return "userdata"
        elseif cclosures[(...)] then
            return "function"
        elseif types[(...)] then
            return types[(...)]
        elseif res=="context_type" then
            simplelog("_","type",...)
            return "table"
        end
        return res
    end
    cenv.typeof=function(...)
        if select("#", ...) == 0 then return typeof() end
        local v = ...
        if oldtype(v) == "table" and rawget(v, "__raw") then
            return "Instance"
        elseif cclosures[v] then
            return "function"
        elseif types[v] then
            return types[v]
        elseif type(v) == "context_type" then
            local loc = v[__dumperlocation] or ""
            if loc:find("Path2DControlPoint", 1, true) then return "Path2DControlPoint" end
            simplelog("_","typeof",...)
            return "Instance"
        end
        local tf = typeof(v)
        if tf == "vector" then return "Vector3" end
        return tf
    end
    cclosures[cenv.type]=true
    cclosures[cenv.typeof]=true
    func_to_name[cenv.type]="type"
    func_to_name[cenv.typeof]="typeof"
    local oldgetmt=getmetatable
    cenv.getmetatable=function(...)
        if select("#", ...) == 0 then return oldgetmt() end
        local t = ...
        if type(t)=="context_type" or t==fenv_mt then
            local varname=getnewvar()
            simplelog(varname,"getmetatable",t)
            return spytbl(varname)
        end
        return oldgetmt(...)
    end
    cenv.rawget=function(...)
        if select("#", ...) < 2 then return rawget(...) end
        local t,k = ...
        if (type(t)=="context_type" or type(k)=="context_type") and not (type(k)=="table") then
            local varname=getnewvar("rawget")
            simplelog(varname,"rawget",t,k)
            return spytbl(varname)
        end
        return rawget(...)
    end
    for _,func in {"newproxy","unpack","rawset"} do
        cenv[func]=smarthook(func,env[func])
    end
    cenv.tostring=function(...)
        if table.pack(...).n==0 then
            error("missing argument #1")
        end
        local t=type(...)
        if t=="context_type" then
            local varname=getnewvar("tostring")
            simplelog(varname,"tostring",...)
            return spytbl(varname,"string")
        elseif t=="table" then
            local orig=tostring(...)
            local new=""
            local hex=("0123456789abcdef"):split("")
            for _=2,#orig do
                new=new..hex[math.random(1,16)]
            end
            return "0x"..new
        end
        return tostring(...)
    end
    for i,v in getmetatable(env).__index do
        if type(v)=="function" and cenv[i] then
            cclosures[cenv[i]]=true
        end
    end
    for k, v in cenv do
        if type(v) == "function" then
            func_to_name[v] = k
            cclosures[v] = true
        elseif type(v) == "table" and not (getmetatable(v) and getmetatable(v).__type == "context_type") then
            for subk, subv in v do
                if type(subv) == "function" then
                    func_to_name[subv] = k .. "." .. tostring(subk)
                    cclosures[subv] = true
                end
            end
        end
    end
    for item_type,items in exec_env do
        for _,v in items do
            if not cenv[v] then
                cenv[v]=spytbl(v)
            end
            if v ~= "Instance" and v ~= "_G" and v ~= "debug" and v ~= "bit" and v ~= "bit32" and v ~= "crypt" and v ~= "cache" and v ~= "Drawing" then
                types[cenv[v]]=item_type
            end
        end
    end
    local logged_undefined_fenv={}
    local varargs,varargsstr
    if lowestlayer then
        local function crackjunkie()
            local old = {cenv.task,cenv.getgc,cenv.tick}
            cenv.getgc=function()end
            cenv.task['spawn']=function(...) end
            cenv.tick=function() return 1925818287 end
            local old2 = cenv.game:GetService("RbxAnalyticsService").GetClientId
            _dumperpredefined=({GetClientId=function() cenv.task,cenv.getgc,cenv.tick=old[1],old[2],old[3] return old2() end})
        end
        if isjunkie then
            crackjunkie()
        end
        varargs,varargsstr=genvars(5)
        insert(r,"local "..varargsstr.." = ...")
        local lastlen,fuck=#currentR,0
        local _debug={}
        table.foreach(debug,function(i,v)_debug[i]=v end)
        setmetatable(_debug,{__index={getinfo=debug_getinfo}})
        local x=0
        fenv_mt=setmetatable({},{
            __index=function(_,key)
                check_budget()
                if key=="_dumperloglines" then settings.log_lines=true end
                if key=="zeenjunkie" then crackjunkie() end
                -- print("-----------------",key)
                if msecNotReady then
                    if key=="_ENV" then
                        return fenv_mt
                    elseif key=="debug" then
                        return _debug
                    elseif key:sub(1,5)=="_dumper" then
                        if key=="_dumperpredefine"then
                            return function(t)
                                _dumperpredefined=t or {}
                            end
                        end
                        return cenv[key]
                    elseif key=="wait" then
                        return function(...)return ((...) or 0)+math.random()/10 end
                    elseif key=="getfenv" or key=="string" or key=="table" or key=="math" or key=="tonumber" or key=="bit32" or key=="bit" or key=="buffer" or key=="utf8" then
                        return cenv[key]
                    elseif key=="loadstring" then
                        if x<7 then
                            x+=1
                            return luau.load
                        end
                        x+=1
                        return function(src,b)
                            local func=luau.load(settings.hook_op~=false and hook_op(src) or src,b)
                            if func then setfenv(func,fenv_mt) end
                            return func
                        end
                    elseif key=="require" or key=="game"then
                        -- msecNotReady=false
                        -- for i,v in tsenv do
                        --     tsenv[i]=cenv[i] or v
                        -- end
                        -- settings.usesimplefunctions=not settings.usesimplefunctions and "MSEC_TRUE" or true
                        -- return cenv[key]
                        return error()
                    end
                    return tsenv[key] or env[key]
                -- elseif specialhandle=="LPS" then
                --     print(1,key)
                --     return env[key]
                end
                if not predefinefound and key=="_dumperpredefine" and input:find("_dumperpredefine",1,true) then
                    predefinefound=true
                    simplelog("_","_dumperpredefine","this function was referenced in the script, if you didnt do this place _dumperpredefine() on top of your script")
                    return function(t)
                        for i,v in t do
                            _dumperpredefined[i]=v
                        end
                    end
                end
                if luraphnotready==1 and key=="coroutine" then
                    luraphnotready=2
                elseif luraphnotready==2 and key=="bit32" then
                    luraphnotready=3
                elseif luraphnotready==5 then -- TODO LOLL
                    if key=="loadstring" then
                        return function(src,...)
                            luraphnotready=0
                            return luau.load(src,...)
                        end
                    elseif key=="require" then
                        return function()return {}end
                    -- elseif key=="getfenv" then
                    --     return pmogetfenv
                    end
                    return env[key]
                end
                local is_std = key=="string" or key=="table" or key=="math" or key=="bit" or key=="bit32" or key=="buffer" or key=="os" or key=="coroutine"
                if not is_std and #currentR==lastlen then
                    fuck+=1
                    if fuck>DUMPER_LIMITS.fenv_abort_after then

                        plserror=true
                        budget_exceeded=true
                        partial_output=true
                        partial_note=partial_note or "the environment stopped making progress"
                        flush_partial(true)
                        error("__DUMPER_LIMIT__:fenv",0)
                    elseif fuck>DUMPER_LIMITS.fenv_flush_after then
                        partial_output=true
                        partial_note=partial_note or "the environment stopped making progress"
                        flush_partial(true)
                    end
                else
                    fuck=0
                    last_output_at=clock()
                end
                lastlen=#currentR
                local try=_dumperpredefined[key] or tsenv[key] or cenv[key]
                if try~=nil then
                    return try
                elseif key=="IschooseTeam" then
                    return function()return true end
                elseif (env[key]==nil) then
                    if not logged_undefined_fenv[key] and not (type(key)=="string" and #key>=12 and #key<=14 and settings.ignore_prom_globals) then
                        fenvused=true
                        local varname=getnewvar(key)
                        logged_undefined_fenv[key]=varname
                        insert(currentR,"local "..varname.."=fenv["..tostring_complex(key).."]")
                    end
                    -- print(key,"hai")
                    if settings.spynilglobals and not (#key>=12 and #key<=14 and settings.ignore_prom_globals) then return spytbl(logged_undefined_fenv[key]) end
                end
                return env[key] or genv[key]
            end,__newindex=function(_,k,v)
                check_budget()
                check_output_limit()
                if k=="_" or (not msecNotReady and type(k)=="string" and #k>50) then return end
                if msecNotReady then
                    tsenv[k]=v
                    if k=="MoonSec_StringsHiddenAttr" and x>=8 then
                        msecNotReady=false
                        for i,val in cenv do
                            tsenv[i]=val
                        end
                        settings.spynilglobals=settings.spynilglobals==nil or settings.spynilglobals
                        settings.hook_op=settings.hook_op==nil or settings.hook_op
                        settings.usesimplefunctions=false
                    end
                    return
                end
                fenvused=true
                if not table.find({"Db","Dc"},k) and not msecNotReady then
                    if k=="MoonSec_StringsHiddenAttr" then
                        settings.spynilglobals=settings.spynilglobals==nil or settings.spynilglobals
                        settings.hook_op=settings.hook_op==nil or settings.hook_op
                        settings.usesimplefunctions=settings.usesimplefunctions==true
                    end
                    if k=="Descriptor" or type(k)=="string" and k:sub(1,10)=="FlatIdent_" then
                    else
                        insert(currentR,`fenv[{tostring_complex(k)}] = {tostring_complex(v)}`..(settings.log_lines and " -- line "..(function()
                            local linenumber=debug.traceback():split"\n"
                            for i,v in linenumber do
                                if v:find("sandbox",1,true) then
                                    linenumber=v:split(":")[2]
                                    break
                                end
                            end
                            return linenumber
                        end)() or ""))
                        flush_partial(false)
                    end
                end
                tsenv[k]=v
            end,
            __metatable=false,
        })
        setfenv(chunk,fenv_mt)
    end
    if not lowestlayer and fenv_mt then
        pcall(setfenv, chunk, fenv_mt)
    end
    local p
    if lowestlayer and luraphargs and luraphargs.n>0 then
        -- Luraph V15.1's second layer is a buffer-driven VM. Reuse the exact
        -- arguments the loader passed to the intercepted loadstring chunk.
        p=table.pack(_pcall(chunk,unpack(luraphargs,1,luraphargs.n)))
    elseif lowestlayer and luraphcarry then
        -- print"HEYYY"
        chunk=function()error("unsupported loader layer",0)end
        p=table.pack(_pcall(chunk,luraphcarry))
    else p = table.pack(_pcall(chunk,unpackchoose(varargs,...))) end
    if not p[1] then
        local original=p[2]
        if type(original)=="string" and original:find("__DUMPER_YIELD_BREAK__",1,true) then
            -- Yield loop exited cleanly after capturing body
        elseif lowestlayer then
            partial_output=true
            partial_note=partial_note or clean_display_error(original)
            if type(original)=="string" and original:find("__DUMPER_LIMIT__",1,true) then
                partial_note=partial_note or clean_display_error(original)
            end
            simplelog("er","error",clean_display_error(original))
        end
    else
        local function get(num)
            if not num or num==0 then return end
            if num>100 then
                return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil, get(num-100)
            elseif num>10 then
                return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,get(num-10)
            end
            return nil, get(num-1)
        end
        if lowestlayer and #pending_spawned_threads > 0 then
            in_spawn_harvest = true
            local to_run = table.clone(pending_spawned_threads)
            table.clear(pending_spawned_threads)
            for _, item in ipairs(to_run) do
                if coroutine.status(item.co) == "suspended" then
                    if item.kind == "task.delay" then
                        simplelog("_", "task.delay", item.t, item.f, unpack(item.args, 1, item.args.n))
                    else
                        simplelog("_", item.kind, item.f, unpack(item.args, 1, item.args.n))
                    end
                end
            end
            in_spawn_harvest = false
        end
        if p.n>1 then
            insert(r,"return "..stringify(unpack(p,2,p.n)))
        end
    end
    if not lowestlayer and #r == 0 then
        local numargs = debug.info(chunk, "a")
        if numargs and numargs <= 1 then
            local test_keys = {"q", "e", "r", "f", "c", "x", "z", "v", "y", "u", "t", "g", "b", "1", "2", "3", " "}
            for _, k in ipairs(test_keys) do
                if #r >= 40 then break end
                pcall(chunk, k)
            end
            if #r == 0 then
                pcall(chunk, true)
                pcall(chunk, false)
            end
            if #r == 0 then
                pcall(chunk, 1)
                pcall(chunk, 0)
            end
            if #r == 0 then
                local mock_inp = spytbl("input")
                pcall(chunk, mock_inp)
            end
            if #r == 0 and cenv.game and cenv.game.Players and cenv.game.Players.LocalPlayer then
                pcall(chunk, cenv.game.Players.LocalPlayer)
                pcall(chunk, cenv.game.Players.LocalPlayer.Character)
            end
        end
    end
    if not lowestlayer and #r == 0 then
        if p.n > 1 then
            insert(r, "return " .. stringify(unpack(p, 2, p.n)))
        else
            insert(r, "-- Callback action / state trigger")
            insert(r, "return true")
        end
    end
    currentR=oldR
    return r
end
local r={
}
local start=clock()
analysis_started=clock()
last_output_at=analysis_started
analysis_active=true
local s,re=pcall(analyzefunction,chunk,r,true)
if not s then
    partial_output=true
    partial_note=partial_note or clean_display_error(re)
    flush_partial(true)
end
local post=commercial and "_dump.lua" or ".lua"
for i=1,unclosed_blocks do
    insert(r,"end")
end
if fenvused then
    insert(r,1,"local fenv=getfenv()")
end
if genvused then
    insert(r,1,"local genv=getgenv()")
end
for i=1,20 do
    if not is_unfinished then break end
    local newr={}
    for _,line in r do
        local num=line:match("-- func(%d+)")
        if num and unfinishedfuncs[tonumber(num)] then
            local locallocation,localused=#newr,false
            local localname=newr[locallocation]:match("local ([%w_]+)")
            local obj=unfinishedfuncs[tonumber(num)]
            local s,re=pcall(analyzefunction,obj.func,{},false,multiunpack(obj.args,obj.varargvars or obj.varargs))
            if s and type(re)=="table" then
                for i,v in re do
                    if v~=nil then
                        if v:find(localname,1,true) then
                            localused=true
                        end
                        insert(newr,v)
                    end
                end
            end
            if localused then
                newr[locallocation]=newr[locallocation]:gsub("(local )([%w_]+)","%2")
                insert(newr,locallocation,"local "..localname)
            end
        else
            insert(newr,line)
        end
    end
    r=newr
end
analysis_active=false
if not settings.log_lines then
    r=evaluate_single_use_variables(r)
    evaluate_stuff(r)
else
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        if v~=nil then
            insert(r,(v:gsub(identifier.."_?","")))
        end
    end
end

local function finalize_output(lines)
    local out={}
    local total=0
    local prev,repeats=nil,0
    for _,raw in ipairs(lines) do
        local line=tostring(raw or "")
        line=line:gsub("\r","")
        line=line:gsub("<dumper[^>]*>","")
        line=line:gsub("__DUMPER_LIMIT__:[%w_]+","the analysis limit was reached")
        line=line:gsub("[%w_%-%./\\]*tracer[%w_%-%./\\]*:%d+:%s*","")
        line=line:gsub("%[string [^%]]+%]:%d+:%s*","")
        if base_path~="" then
            line=line:gsub(base_path_pattern.."[/\\]?","")
        end
        if #line>DUMPER_LIMITS.max_line_length then
            line=line:sub(1,DUMPER_LIMITS.max_line_length).." --[[line truncated]]"
        end
        local structural=line:match("^%s*end%s*$") or line:match("^%s*else%s*$") or line:match("^%s*{%s*$") or line:match("^%s*}%s*$") or line:match("^%s*%)%s*$")
        if line==prev and #line>80 and not structural then
            repeats+=1
            if repeats<=DUMPER_LIMITS.max_repeated_lines then
                insert(out,line)
                total+=#line+1
            elseif repeats==DUMPER_LIMITS.max_repeated_lines+1 then
                insert(out,"-- [[repeated line suppressed]]")
                total+=32
            end
        else
            prev=line
            repeats=1
            insert(out,line)
            total+=#line+1
        end
        if total>=DUMPER_LIMITS.max_output_bytes then
            insert(out,"-- [[output limit reached]]")
            break
        end
        if #out>=DUMPER_LIMITS.max_output_lines then
            insert(out,"-- [[line limit reached]]")
            break
        end
    end
    local full_text = table.concat(out,"\n")
    full_text = full_text:gsub("CHECKIF%((.-)%)", "if %1 then --[[branch observed]] end")
    full_text = full_text:gsub("CHECKELSEIF%((.-)%)", "-- elseif %1")
    full_text = full_text:gsub("CHECKWHILE%((.-)%)", "-- while %1")
    full_text = full_text:gsub("CHECKUNTIL%((.-)%)", "-- until %1")
    full_text = full_text:gsub("function%s*%(([^%)]*)%)%s*\n%s*end", "function(%1)\n    -- Callback action / state trigger\n    return true\nend")
    full_text = full_text:gsub("function%s*%(([^%)]*)%)%s*\n%s*local%s+([%w_, ]+)%s*=%s*%.%.%.%s*\n%s*end", "function(%1)\n    local %2 = ...\n    -- Callback action / state trigger\n    return true\nend")
    full_text = full_text:gsub("function%s*%(([^%)]*)%)%s*\n%s*%-%-%[%[n=[^%]]*%]%]end", "function(%1)\n    -- Callback action / state trigger\n    return true\nend")
    return full_text
end

local output=finalize_output(currentR or r)
local out_file=outpath..clean_target:gsub("%.lua$","")..post
if not fs.isDir(outpath) then
    pcall(fs.writeDir, outpath)
end
local write_ok=pcall(fs.writeFile,out_file,output)
if not write_ok then
    local fallback_out = clean_target:gsub("%.lua$","")..post
    write_ok = pcall(fs.writeFile, fallback_out, output)
    if not write_ok then
        write_ok = pcall(fs.writeFile, "/tmp/" .. fallback_out, output)
    end
end
pcall(fs.removeFile,partial_path)
if not write_ok then
    _print("DUMP_STATUS:FAIL")
    _print("DUMP_NOTE:the dump could not be saved")
elseif partial_output or budget_exceeded or not s then
    _print("DUMP_STATUS:PARTIAL")
    _print("DUMP_NOTE:"..clean_display_error(partial_note or "the analysis stopped before completion"))
else
    _print("DUMP_STATUS:OK")
end
