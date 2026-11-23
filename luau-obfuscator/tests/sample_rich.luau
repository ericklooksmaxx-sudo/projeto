-- varied features (no Roblox/LuaU-only globals, so lua5.1 can verify correctness)
local function map(t, f) local r = {} for i,v in ipairs(t) do r[i]=f(v) end return r end
local function reduce(t, f, acc) for _,v in ipairs(t) do acc=f(acc,v) end return acc end
local nums = {1,2,3,4,5,6,7,8,9,10}
local sq = map(nums, function(x) return x*x end)
print("sum_sq", reduce(sq, function(a,b) return a+b end, 0))

local mt = setmetatable({}, { __index = function(_,k) return "<"..k..">" end })
print("mt", mt.foo, mt.bar)

local function vararg(...) local n = select("#", ...) local s=0 for i=1,n do s=s+select(i,...) end return n, s end
print("vararg", vararg(10,20,30))

local ok, err = pcall(function() error("boom") end)
print("pcall", ok, tostring(err):match("boom") ~= nil)

local co = coroutine.wrap(function() for i=1,3 do coroutine.yield(i*i) end end)
print("coro", co(), co(), co())

local s = "The Quick Brown Fox"
print("str", s:lower(), s:upper():gsub("%s","_"), #s)
local acc = 0
for i=1,100 do if i%2==0 then acc=acc+i elseif i%3==0 then acc=acc-1 end end
print("loop", acc)
