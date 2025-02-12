local argparse = require("../lune_packages/argparse")
local multitarget = require("./lib")
local pathfs = require("../lune_packages/pathfs")
local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local process = require("@lune/process")

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`
local DEFAULT_OUTPUT_DIR = "dist"
local DEFAULT_LUA_ENV_GLOBAL = "LUA_ENV"
local DEFAULT_DECLARATION_FILE_CONTENT = `declare _G: \{\
	{DEFAULT_LUA_ENV_GLOBAL}: ("luau" | "lune" | "roblox")?,\
\}\
`
local TARGETS_COLORS = {
	luau = stdio.color("blue"),
	lune = stdio.color("purple"),
	roblox = stdio.color("red"),
}

local cli = argparse("multitarget")

local build = cli:command("build", "Build a pesde project for multiple targets")
build:argument("project", "Path to the pesde.toml file"):default("pesde.toml")
build:option("-o --output", "Output directory"):default(DEFAULT_OUTPUT_DIR)
build:option("-g --global", "Lua environment global variable name"):default(DEFAULT_LUA_ENV_GLOBAL)
build:flag("-w --workspace", "Build as pesde workspace")
build:flag("--luau", "Build for Luau")
build:flag("--lune", "Build for Lune")
build:flag("--roblox", "Build for Roblox")
build:flag("-a --all", "Build for every targets (luau, lune, roblox)")
build:option("--build-files", "Paths to build files"):args("*")
build:action(function(args: {
	project: string,
	output: string,
	global: string,
	workspace: boolean,
	luau: boolean,
	lune: boolean,
	roblox: boolean,
	all: boolean,
	build_files: { string }?,
})
	local output = args.output
	if args.all then
		args.luau = true
		args.lune = true
		args.roblox = true
	end
	local targets = {
		luau = args.luau,
		lune = args.lune,
		roblox = args.roblox,
	}
	multitarget.build(args.project, output, targets, args.build_files, args.global, args.workspace)

	local colorfulTargets = {}
	for target: string, enabled: boolean in targets :: any do
		if enabled then
			table.insert(colorfulTargets, TARGETS_COLORS[target] .. target .. stdio.color("reset"))
		end
	end
	print(`\n{stdio.color("green")}Build completed!{stdio.color("reset")} {table.concat(colorfulTargets, ",")}`)
end)

local function tableSet(t: {}, path: { any }, value: any)
	local current = t
	for i = 1, #path - 1 do
		local key = path[i]
		if not current[key] then
			current[key] = {}
		end
		current = current[key]
	end
	current[path[#path]] = value
end

local function tableGet(t: {}, path: { any }): any?
	local current = t
	for i = 1, #path - 1 do
		local key = path[i]
		if not current[key] then
			return nil
		end
		current = current[key]
	end
	return current[path[#path]]
end

local setup = cli:command("setup", "Setup your project before building")
setup:action(function()
	do
		local pesdeToml = pathfs.File.new("pesde.toml")
		if not pesdeToml:isFile() then
			stdio.ewrite(`{ERROR_PREFIX} pesde.toml is not found. Are you in the right directory?\n`)
			process.exit(1)
			error("unreachable")
		end
		local pesdeManifest: {
			private: boolean?,
		} = serde.decode("toml", pesdeToml:readFile())
		if not pesdeManifest.private then
			if stdio.prompt("confirm", `Would you like to set 'private = true' in the current project's pesde.toml? (because usually your root project is not for publish)`) then
				tableSet(pesdeManifest, { "private" }, true)
				pesdeToml:writeFile(serde.encode("toml", pesdeManifest, true))
			end
		end
	end
	do
		local gitignore = pathfs.findFile(".gitignore")
		if gitignore then
			local toIgnore = `/{DEFAULT_OUTPUT_DIR}`
			local content = gitignore:readFile()
			local found = false
			for _, line in content:split("\n") do
				if line == toIgnore then
					found = true
					break
				end
			end
			if not found then
				if
					stdio.prompt(
						"confirm",
						`Found a .gitignore file. Would you like to add the default output directory('{toIgnore}') to it?`
					)
				then
					content ..= "\n" .. toIgnore .. "\n"
					gitignore:writeFile(content)
				end
			end
		end
	end
	do
		local seleneFile = pathfs.findFile("selene.toml")
		if seleneFile then
			-- selene: allow(shadowing)
			local seleneToml: {
				config: {
					global_usage: {
						ignore_pattern: string?,
					}?,
				}?,
			} =
				serde.decode("toml", seleneFile:readFile())
			local path = { "config", "global_usage", "ignore_pattern" }
			if not tableGet(seleneToml, path) then
				if
					stdio.prompt(
						"confirm",
						`Found a selene.toml file. Would you like to add the default lua environment global variable name('{DEFAULT_LUA_ENV_GLOBAL}') to the ignore pattern?`
					)
				then
					tableSet(seleneToml, path, DEFAULT_LUA_ENV_GLOBAL)
					seleneFile:writeFile(serde.encode("toml", seleneToml, true))
				end
			end
		end
	end
	do
		local ok, result = pcall(process.spawn, "darklua", { "--version" })
		if not ok or (ok and not result.ok) then
			if stdio.prompt("confirm", `darklua is not found. Would you like to install it from pesde?`) then
				process.spawn("pesde", { "add", "pesde/darklua", "--dev", "-t", "lune" }, { stdio = "forward" })
				process.spawn("pesde", { "install" }, { stdio = "forward" })
			end
		end
	end
	do
		local declarationFile = pathfs.File.new(".d.luau")
		if not declarationFile:isFile() then
			if
				stdio.prompt(
					"confirm",
					`Would you like to add .d.luau type definition file for default lua environment global variable name('{DEFAULT_LUA_ENV_GLOBAL}')?`
				)
			then
				declarationFile:writeFile(DEFAULT_DECLARATION_FILE_CONTENT)
			end
		end
	end
	do
		local vscodeDir = pathfs.Directory.new(".vscode")
		local vscodeSettings = pathfs.File.new(vscodeDir.path:join("settings.json"))
		local settings: {
			["luau-lsp.types.definitionFiles"]: { string }?,
		} = if vscodeSettings:isFile()
			then serde.decode("json", vscodeSettings:readFile())
			else {}
		if
			not settings["luau-lsp.types.definitionFiles"]
			or not table.find(settings["luau-lsp.types.definitionFiles"], ".d.luau")
		then
			if
				stdio.prompt(
					"confirm",
					"Would you like to add .d.luau type definition file to '.vscode/settings.json'?"
				)
			then
				local defFiles = settings["luau-lsp.types.definitionFiles"] or {}
				table.insert(defFiles, ".d.luau")
				settings["luau-lsp.types.definitionFiles"] = defFiles
				if not vscodeDir:isDir() then
					vscodeDir:writeDir()
				end
				vscodeSettings:writeFile(serde.encode("json", settings, true))
			end
		end
	end

	print("You are ready to go! Try running 'multitarget build [arguments]' to build your project.")
end)

cli:parse()
