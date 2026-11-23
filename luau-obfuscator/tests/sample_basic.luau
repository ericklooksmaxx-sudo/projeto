local function fib(n)
    if n < 2 then return n end
    return fib(n-1) + fib(n-2)
end
local t = {}
for i = 1, 10 do
    t[i] = fib(i)
end
print("fib:", table.concat(t, ","))
local s = "hello" .. " " .. "world"
print(s, #s)
