-- demo script
local function greet(name)
    return "Hello, " .. name .. "!"
end

local players = {"Alice", "Bob", "Carol"}
for _, p in ipairs(players) do
    print(greet(p))
end

local total = 0
for i = 1, 10 do total += i end
print("Total:", total)
