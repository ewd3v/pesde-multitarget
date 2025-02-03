local lib = require("../")

lib.build("pesde.toml", "dist", {
	luau = true,
	lune = true,
	roblox = true,
}, {
	"src",
}, nil, true)
