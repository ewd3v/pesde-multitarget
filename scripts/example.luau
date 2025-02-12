local lib = require("../src/lib")

lib.build(
	"pesde.toml",
	"dist",
	{
		luau = true,
		lune = true,
		roblox = true,
	},
	{
	"src",
	},
	"LUA_ENV",
	true
)
