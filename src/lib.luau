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
		},
	} =
		serde.decode("toml", pesdeTomlFile:readFile())

	if not pesdeToml.target then
		stdio.ewrite(`{ERROR_PREFIX} 'target' field is required in 'pesde.toml'.\n`)
		process.exit(1)
		error("unreachable")
	end

	local members = {}
	for t, _ in targets :: { [typeof(environmentType:type())]: boolean } do
		table.insert(members, t)
	end
	for _, target in members do
		environmentType:assert(target)

		local targetDir = pathfs.Directory.new(outputDir.path:join(target))
		-- selene: allow(shadowing)
		local pesdeToml = table.clone(pesdeToml)
		if pesdeToml.includes then
			for _, include in pesdeToml.includes do
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
			if pesdeToml.target.lib then
				local dest = targetDir.path:join(pesdeToml.target.lib)
				local parent = dest:parent()
				if parent then
					fs.writeDir(parent)
				end
				fs.copy(pesdeToml.target.lib, dest, true)
			end
			if pesdeToml.target.bin then
				local dest = targetDir.path:join(pesdeToml.target.bin)
				local parent = dest:parent()
				if parent then
					fs.writeDir(parent)
				end
				fs.copy(pesdeToml.target.bin, dest, true)
			end
		end

		local injectGlobalValueRule = {
			rule = "inject_global_value",
			identifier = luaEnvGlobal,
			value = target,
		}
		if buildFiles then
			if target == "luau" or target == "lune" then
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
			elseif target == "roblox" then -- not ready yet, needs darklua path require conversion
				pesdeToml.target.build_files = buildFiles
				pesdeToml.target.bin = nil
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

		pesdeToml.target.environment = target
		fs.writeFile(targetDir.path:join("pesde.toml"), serde.encode("toml", pesdeToml, true))
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
