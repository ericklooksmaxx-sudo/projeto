-- Kyzen presets (LuaU / Roblox focused).
-- Steps marked with (*) are Kyzen-added and may be absent until built; the CLI
-- skips unknown steps with a warning so partial builds still run.
return {
	-- Fast, light protection. VM + string encryption + constant array.
	["Kyzen_Light"] = {
		LuaVersion = "LuaU",
		VarNamePrefix = "",
		NameGenerator = "MangledShuffled",
		PrettyPrint = false,
		Seed = 0,
		Steps = {
			{ Name = "Vmify", Settings = {} },
			{ Name = "EncryptStrings", Settings = { HoistVmStrings = true } },
			{ Name = "ConstantArray", Settings = { Threshold = 1, StringsOnly = true, Shuffle = true, Rotate = true, LocalWrapperThreshold = 0 } },
			{ Name = "WrapInFunction", Settings = {} },
		},
	},

	-- Balanced: VM + anti-tamper + anti-sandbox + CFF + numbers.
	["Kyzen_Medium"] = {
		LuaVersion = "LuaU",
		VarNamePrefix = "",
		NameGenerator = "MangledShuffled",
		PrettyPrint = false,
		Seed = 0,
		Steps = {
			{ Name = "AntiSandbox", Settings = {} },            -- (*)
			{ Name = "Vmify", Settings = {} },
			{ Name = "EncryptStrings", Settings = { HoistVmStrings = true } },
			{ Name = "AntiTamper", Settings = { UseDebug = false } },
			{ Name = "Cff", Settings = { ExcludeVm = true } },
			{ Name = "ConstantArray", Settings = { Threshold = 1, StringsOnly = true, Shuffle = true, Rotate = true, LocalWrapperThreshold = 0 } },
			{ Name = "NumbersToExpressions", Settings = {} },
			{ Name = "WrapInFunction", Settings = {} },
		},
	},

	-- Maximum: everything + encrypted bootstrap outer layer.
	["Kyzen_Max"] = {
		LuaVersion = "LuaU",
		VarNamePrefix = "",
		NameGenerator = "MangledShuffled",
		PrettyPrint = false,
		Seed = 0,
		Bootstrap = true,
		Steps = {
			{ Name = "AntiSandbox", Settings = { Strict = true } }, -- (*)
			{ Name = "OpaquePredicates", Settings = {} },          -- (*)
			{ Name = "Vmify", Settings = {} },
			{ Name = "EncryptStrings", Settings = {} },
			{ Name = "AntiTamper", Settings = { UseDebug = false } },
			{ Name = "JunkCode", Settings = {} },                  -- (*)
			{ Name = "Cff", Settings = {} },
			{ Name = "ConstantArray", Settings = { Threshold = 1, StringsOnly = true, Shuffle = true, Rotate = true, LocalWrapperThreshold = 0 } },
			{ Name = "NumbersToExpressions", Settings = { NumberRepresentationMutation = true } },
			{ Name = "WrapInFunction", Settings = {} },
		},
	},

	-- Fortress: everything + encrypted bootstrap whose loader is ALSO VM-obfuscated.
	-- Two VM layers (inner payload VM + outer loader VM) + encryption. Heaviest.
	["Kyzen_Fortress"] = {
		LuaVersion = "LuaU",
		VarNamePrefix = "",
		NameGenerator = "MangledShuffled",
		PrettyPrint = false,
		Seed = 0,
		Bootstrap = true,
		BootstrapProtect = true,
		Steps = {
			{ Name = "AntiSandbox", Settings = { Strict = true } },
			{ Name = "OpaquePredicates", Settings = {} },
			{ Name = "Vmify", Settings = {} },
			{ Name = "EncryptStrings", Settings = {} },
			{ Name = "AntiTamper", Settings = { UseDebug = false } },
			{ Name = "JunkCode", Settings = {} },
			{ Name = "Cff", Settings = {} },
			{ Name = "ConstantArray", Settings = { Threshold = 1, StringsOnly = true, Shuffle = true, Rotate = true, LocalWrapperThreshold = 0 } },
			{ Name = "NumbersToExpressions", Settings = { NumberRepresentationMutation = true } },
			{ Name = "WrapInFunction", Settings = {} },
		},
	},
}
