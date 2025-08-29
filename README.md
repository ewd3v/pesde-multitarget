Fork of https://github.com/jiwonz/pesde-multitarget containing my fixes & updates that may not merged into the official repository yet.

# [pesde-multitarget](https://pesde.dev/packages/ewdev/multitarget)
Customizable and flexible build script for multiple pesde targets

Build your pure pesde project easier targeting both `luau` and `roblox` targets at the same time.

No more annoying package build scripts manually! (But this doesn't support `wally`)

## How to use
### `pesde add` (recommended)
Add & Install this pesde package and darklua as a dev_dependency:
```sh
pesde add pesde/darklua --dev -t lune # Pass if darklua is installed already.

pesde add ewdev/multitarget --dev -t lune

pesde install
```
Use as a binary:
```sh
multitarget --help
```
Use a library with pesde scripts(runtime is lune actually):
```luau
-- scripts/build.luau

local multitarget = require("../lune_packages/multitarget")

multitarget.build(
	"pesde.toml", -- defaults to "pesde.toml"
	{ -- pesde project file path defaults to "pesde.toml"
		luau = true,
		roblox = true,
	},
	"./path/to/output", -- defaults to "dist"
	{
		"build files path" -- files/directories to be built
	},
	"LUA_ENV", -- defaults to "LUA_ENV"
	"pkg", -- defaults to "pkg"
	"luau_pkg", -- defaults to "luau_pkg"
	true -- defaults to true
)
```
`pesde.toml`
```toml
[scripts]
build = "scripts/build.luau"
```
```sh
pesde run build
```

### `pesde x`
Execute directly without installation:
```sh
pesde x ewdev/multitarget -- --help
```

## Usage
Check the [example code](lune/example.luau) out. and run `multitarget --help` for more information about commands and arguments.

### `setup`
Setups your project before building.

With a binary:
```sh
multitarget setup
```
With `pesde x`:
```sh
pesde x ewdev/multitarget -- setup
```

### `build`
Builds your pesde project targeting to `luau` and `roblox`.

With a binary:
```sh
multitarget build --output ./path/to/output --roblox --luau --lune --build-files [..build_files] # You can set targets manually. Roblox target with luau project will require `darklua` to convert requires.

multitarget build --output ./path/to/output --build-files [..build_files] # If none of target argument is given, This will set available targets automatically.

multitarget build -o ./path/to/output --build-files [..build_files] # Shorter arguments are supported.

multitarget build ./path/to/pesde.toml -o ./path/to/output --build-files [..build_files] # You can pass pesde.toml optionally.

multitarget build -w -a --build-files src # Build for every(-a --all) targets with workspace(-w --workspace) pesde project (luau, lune, roblox)
```
With `pesde x`:
```sh
pesde x ewdev/multitarget -- build ...
```
