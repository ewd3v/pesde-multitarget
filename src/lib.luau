local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local pathfs = require("../lune_packages/pathfs")
local fs = pathfs.fs
local gt = require("../lune_packages/greentea")
local glob = require("../lune_packages/glob")
local process = require("@lune/process")
local darklua = require("../lune_packages/darklua_lune")

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`
local DEFAULT_DARKLUA_RULES = {
	"remove_unused_if_branch",
	"filter_after_early_return",
	"remove_empty_do",
}

type Dependency = {
	name: string?,
	version: string?,
	wally: string?,
	workspace: string?,
	repo: string?,
	path: string?,
}

local multitarget = {}

local targetsType = gt.build(gt.table({
	luau = gt.opt(gt.boolean()),
	lune = gt.opt(gt.boolean()),
	roblox = gt.opt(gt.boolean()),
}))
local environmentType = gt.build(gt.union(gt.literal("luau"), gt.literal("lune"), gt.literal("roblox")))
local optionalStringType = gt.build(gt.opt(gt.string()))
local optionalStringArrayType = gt.build(gt.opt(gt.array(gt.string())))
local optionalBooleanType = gt.build(gt.opt(gt.boolean()))

local optionalAsPathType = gt.build(gt.opt(pathfs.types.AsPath:type()))
function multitarget.build(
	pesdeTomlPath: typeof(optionalAsPathType:type()),
	outputPath: typeof(pathfs.types.AsPath:type()),
	targets: typeof(targetsType:type()),
	buildFiles: typeof(optionalStringArrayType:type()),
	luaEnvGlobal: typeof(optionalStringType:type()),
	workspace: typeof(optionalBooleanType:type())
)
	optionalAsPathType:assert(pesdeTomlPath)
	pathfs.types.AsPath:assert(outputPath)
	targetsType:assert(targets)
	optionalStringArrayType:assert(buildFiles)
	optionalStringType:assert(luaEnvGlobal)
	optionalBooleanType:assert(workspace)

	-- selene: allow(shadowing)
	local luaEnvGlobal = luaEnvGlobal or "LUA_ENV"
	-- selene: allow(shadowing)
	local pesdeTomlFile = pathfs.File.fromExisting(pesdeTomlPath or "pesde.toml")
	local outputDir = pathfs.Directory.new(outputPath)
	local pesdeToml: {
		includes: { string }?,
		target: {
			environment: typeof(environmentType:type())?,
			lib: string?,
			bin: string?,
			build_files: { string }?,
			scripts: { [string]: string }?,
		},
		dependencies: { [string]: Dependency }?,
		dev_dependencies: { [string]: Dependency }?,
		peer_dependencies: { [string]: Dependency }?,
	} =
		serde.decode("toml", pesdeTomlFile:readFile())

	if not pesdeToml.target then
		stdio.ewrite(`{ERROR_PREFIX} 'target' field is required in 'pesde.toml'.\n`)
		process.exit(1)
		error("unreachable")
	end
	-- selene: allow(shadowing)
	local buildFiles = (pesdeToml.target.build_files or buildFiles) :: typeof(buildFiles)

	local pesdeAddParams = {}
	local function getPackageName(dep: Dependency): string?
		if dep.name and dep.version then
			return `{dep.name}/{dep.version}`
		end
		if dep.wally and dep.version then
			return `wally#{dep.name}/{dep.version}`
		end
		return nil
	end
	if pesdeToml.dependencies then
		for _, dep in pesdeToml.dependencies do
			local packageName = getPackageName(dep)
			if packageName then
				table.insert(pesdeAddParams, { packageName })
			end
		end
	end
	if pesdeToml.peer_dependencies then
		for _, dep in pesdeToml.peer_dependencies do
			local packageName = getPackageName(dep)
			if packageName then
				table.insert(pesdeAddParams, { "--peer", packageName })
			end
		end
	end

	local members = {}
	for t, _ in targets :: { [typeof(environmentType:type())]: boolean } do
		table.insert(members, t)
	end
	if not buildFiles then
		print(`{stdio.color("yellow")}warning{stdio.color("reset")}: None of build files are specified. The files may not be processed properly.`)
	end
	for _, target in members do
		environmentType:assert(target)

		local targetDir = pathfs.Directory.new(outputDir.path:join(target))
		-- selene: allow(shadowing)
		local newPesdeToml = table.clone(pesdeToml)
		if newPesdeToml.includes then
			for _, include in newPesdeToml.includes do
				for _, path in glob(include) do
					local dest = targetDir.path:join(path)
					local parent = dest:parent()
					if parent then
						fs.writeDir(parent)
					end
					fs.copy(path, dest, true)
				end
			end
		else
			if newPesdeToml.target.lib then
				local dest = targetDir.path:join(newPesdeToml.target.lib)
				local parent = dest:parent()
				if parent then
					fs.writeDir(parent)
				end
				fs.copy(newPesdeToml.target.lib, dest, true)
			end
			if newPesdeToml.target.bin then
				local dest = targetDir.path:join(newPesdeToml.target.bin)
				local parent = dest:parent()
				if parent then
					fs.writeDir(parent)
				end
				fs.copy(newPesdeToml.target.bin, dest, true)
			end
		end

		local injectGlobalValueRule = {
			rule = "inject_global_value",
			identifier = luaEnvGlobal,
			value = target,
		}
		if buildFiles then
			if target == "luau" or target == "lune" then
				newPesdeToml.target.build_files = nil
				for _, buildFile in buildFiles do
					local darkluaOutputPath = targetDir.path:join(buildFile)

					local rules = { injectGlobalValueRule :: any }
					for _, rule in DEFAULT_DARKLUA_RULES do
						table.insert(rules, rule)
					end
					darklua.process(buildFile, darkluaOutputPath:toString(), {
						rules = rules,
					})
				end
			elseif target == "roblox" then
				newPesdeToml.target.build_files = buildFiles
				newPesdeToml.target.bin = nil
				newPesdeToml.target.scripts = nil
				for _, buildFile in buildFiles do
					local darkluaOutputPath = targetDir.path:join(buildFile)

					local rules = {
						injectGlobalValueRule :: any,
						{
							rule = "convert_require",
							current = {
								name = "path",
							},
							target = {
								name = "roblox",
								indexing_style = "property",
								rojo_sourcemap = if fs.isFile("sourcemap.json") then "sourcemap.json" else nil,
							},
						},
					}
					for _, rule in DEFAULT_DARKLUA_RULES do
						table.insert(rules, rule)
					end
					darklua.process(buildFile, darkluaOutputPath:toString(), {
						rules = rules,
					})
				end
			end
		end

		newPesdeToml.target.environment = target
		newPesdeToml.dev_dependencies = nil
		newPesdeToml.peer_dependencies = nil
		newPesdeToml.dependencies = nil
		fs.writeFile(targetDir.path:join("pesde.toml"), serde.encode("toml", newPesdeToml, true))

		for _, pesdeAddParam in pesdeAddParams do
			local params = { "add" }
			for _, param in pesdeAddParam do
				table.insert(params, param)
			end
			table.insert(params, "--target")
			table.insert(params, target)
			local result = process.spawn("pesde", params, {
				cwd = targetDir.path:toString(),
				stdio = "inherit",
			})
			if not result.ok then
				stdio.ewrite(`{ERROR_PREFIX} Failed to add dependencies to '{target}' target.\n`)
				process.exit(1)
				error("unreachable")
			end
		end
	end

	if workspace then
		local workspacePesdeToml = {
			name = "multitarget/root",
			version = "0.0.0",
			private = true,
			workspace_members = members,
			target = { environment = "luau" },
		}
		fs.writeFile(outputDir.path:join("pesde.toml"), serde.encode("toml", workspacePesdeToml, true))
	end
end

return multitarget
