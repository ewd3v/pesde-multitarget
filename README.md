# pesde-multitarget
Build your pure pesde project easier targeting both `luau` and `roblox` targets at the same time

## How to use
### `pesde add` (recommended)
Add & Install this pesde package and darklua as a dev_dependency:
```sh
pesde add pesde/darklua --dev -t lune # Pass if darklua is installed already.

pesde add jiwonz/multitarget --dev -t lune

pesde install
```
Use as a binary:
```sh
multitarget help
```
Use a library in a lune script:
```luau
-- lune/build.luau

local multitarget = require("../lune_packages/multitarget")

multitarget.build(nil, "./path/to/output", { -- pesde project file path defaults to "pesde.toml"
	luau = true,
	roblox = true,
}, {
	"build files path" -- files/directories to be built
}, true) -- if this is true, it will create a pesde workspace project in dist folder (this is helpful when publish them at the same time faster)
```

### `pesde x`
Execute directly without installation:
```sh
pesde x jiwonz/multitarget -- --help
```

## Usage
Check the [example code](lune/example.luau) out.

### `setup`
Setups your project before building.

With a binary:
```sh
multitarget setup
```
With `pesde x`:
```sh
pesde x jiwonz/multitarget setup
```

### `build`
Builds your pesde project targeting to `luau` and `roblox`.

With a binary:
```sh
multitarget build --output ./path/to/output --roblox --luau --lune --build-files [..build_files] # You can set targets manually. Roblox target with luau project will require `darklua` to convert requires.

multitarget build --output ./path/to/output --build-files [..build_files] # If none of target argument is given, This will set available targets automatically.

multitarget build -o ./path/to/output --build-files [..build_files] # Shorter arguments are supported.

multitarget build ./path/to/pesde.toml -o ./path/to/output --build-files [..build_files] # You can pass pesde.toml optionally.
```
With `pesde x`:
```sh
pesde x jiwonz/multitarget -- build ...
```
