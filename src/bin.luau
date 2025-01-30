local argparse = require("../lune_packages/argparse")
local multitarget = require("./lib")

local cli = argparse("multitarget")
local build = cli:command("build", "Build a pesde project for multiple targets")
build:argument("config", "Path to the pesde.toml file"):default("pesde.toml")
build:option("-o --output", "Output directory"):default("dist")
build:option("-g --global", "Lua environment global variable name"):default("LUA_ENV")
build:flag("--luau", "Build for Luau")
build:flag("--lune", "Build for Lune")
build:flag("--roblox", "Build for Roblox")
build:option("--build-files", "Paths to build files"):args("*")
build:action(function(args: {
	config: string,
	output: string,
	global: string,
	luau: boolean,
	lune: boolean,
	roblox: boolean,
	build_files: { string }?,
})
	local config = args.config
	local output = args.output
	local targets = {
		luau = args.luau,
		lune = args.lune,
		roblox = args.roblox,
	}
	multitarget.build(config, output, targets, args.build_files, args.global)
end)

cli:parse()
