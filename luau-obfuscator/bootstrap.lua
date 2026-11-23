-- Kyzen Obfuscator - encrypted bootstrap layer
--
-- Wraps an already-obfuscated inner script into an outer loader: the inner source
-- is encrypted into an opaque blob and only decrypted + loaded at runtime. This
-- adds a real outer layer that:
--   * hides the inner script from static dumps (it is ciphertext until runtime),
--   * provides tamper integrity (editing the blob -> garbage -> load fails),
--   * can itself be run through the pipeline again for a second obfuscation layer.
--
-- The keystream is an LCG whose products stay below 2^53 so the arithmetic is
-- bit-exact across Lua 5.1 (encode side) and Luau (decode side) -- no bit32 needed,
-- so the loader is fully portable and testable off-Roblox.

local Bootstrap = {}

-- LCG parameters: product (< 2^31) * MULT (~1e6) + ADD stays < 2.2e15 < 2^53.
local MULT = 1000003
local ADD = 12347
local MOD = 2147483648 -- 2^31

local function keystreamByte(state)
	state = (state * MULT + ADD) % MOD
	local k = math.floor(state / 32768) % 256
	return state, k
end

-- Encrypt bytes with the modular-add keystream. Reversible with (b - k) % 256.
local function encrypt(src, seed)
	local out = {}
	local st = seed
	for i = 1, #src do
		local k
		st, k = keystreamByte(st)
		out[i] = (string.byte(src, i) + k) % 256
	end
	return out
end

-- Emit a Lua string literal from byte values, keeping safe printables literal and
-- escaping the rest as \ddd, so arbitrary ciphertext embeds compactly and safely.
local function bytesToLuaString(bytes)
	local parts = {}
	for i = 1, #bytes do
		local b = bytes[i]
		-- safe, non-ambiguous printable ASCII (exclude " \ and control chars)
		if b >= 32 and b <= 126 and b ~= 34 and b ~= 92 then
			parts[i] = string.char(b)
		else
			-- Always 3 digits so the escape cannot merge with a following literal
			-- digit (e.g. \5 + "7" would read as \57). \%03d is unambiguous.
			parts[i] = string.format("\\%03d", b)
		end
	end
	return table.concat(parts)
end

-- Build the loader source wrapping `inner`. `header` is an optional comment line.
function Bootstrap.wrap(inner, opts)
	opts = opts or {}
	local seed = opts.seed or math.random(1, MOD - 1)
	local enc = encrypt(inner, seed)
	local blob = bytesToLuaString(enc)

	-- Randomized local names reduce trivial pattern matching (the pipeline will
	-- further rename them if the loader is re-obfuscated).
	local function rn()
		local t = {}
		for i = 1, math.random(4, 7) do t[i] = string.char(math.random(97, 122)) end
		return table.concat(t)
	end
	local D, S, K, I, B, O, ST, LD, F =
		rn(), rn(), rn(), rn(), rn(), rn(), rn(), rn(), rn()

	-- The decode loop mirrors encrypt() exactly.
	local loader = string.format([[
local %s = "%s"
local %s = %d
local %s = (loadstring or load)
local function %s(%s, %s)
	local %s = {}
	local %s = %s
	local byte, char = string.byte, string.char
	for %s = 1, #%s do
		%s = (%s * %d + %d) %% %d
		local %s = (math.floor(%s / 32768) %% 256)
		%s[%s] = char((byte(%s, %s) - %s) %% 256)
	end
	return table.concat(%s)
end
local %s = %s(%s(%s, %s), "=kyzen")
return %s(...)
]],
		D, blob,                          -- data
		S, seed,                          -- seed
		LD,                               -- load fn
		O, D, S,                          -- function O(data, seed)
		B,                                -- out table
		ST, S,                            -- state = seed
		I, D,                             -- for i = 1, #data
		ST, ST, MULT, ADD, MOD,           -- state update
		K, ST,                            -- key byte
		B, I, D, I, K,                    -- out[i] = char((byte(data,i)-key)%256)
		B,                                -- return concat(out)
		F, LD, O, D, S,                   -- local F = load(O(D,S), ...)
		F                                 -- return F(...)
	)

	if opts.header then
		loader = opts.header .. "\n" .. loader
	end
	return loader
end

return Bootstrap
