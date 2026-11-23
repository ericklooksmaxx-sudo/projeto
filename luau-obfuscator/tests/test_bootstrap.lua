local root=(arg[0]:match("(.*[/\\])") or "./").."../"
package.path=root.."?.lua;"..package.path
math.randomseed(12345)
local Bootstrap=require("bootstrap")
-- inner: a tiny real script
local inner=[[print("inner-ran", 7*6) return "OKRET"]]
local loader=Bootstrap.wrap(inner, {header="-- This file has been protected with Kyzen V1.0 "})
local o=io.open(arg[1] or "tests/boot.luau","wb"); o:write(loader); o:close()
io.stderr:write("loader bytes="..#loader.."\n")
