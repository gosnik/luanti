# Compiling for Nintendo Switch Homebrew

This target is experimental. The first milestone is a minimal offline `.nro` client using SDL2, OpenGL ES, bundled Lua, and assets on the SD card at `sdmc:/switch/luanti`.

## Requirements

- A Nintendo Switch capable of running homebrew.
- hbmenu and `nxlink` for deployment during development.
- devkitPro with devkitA64, libnx, Switch tools, SDL2, Mesa, and the required portlibs.

Install devkitPro using the official instructions:

- https://devkitpro.org/wiki/Getting_Started
- https://switchbrew.org/wiki/Setting_up_Development_Environment

For Unix-like systems, Luanti provides a helper that installs the expected Switch packages after devkitPro pacman is available:

```sh
util/switch/install_devkitpro.sh
```

Current devkitPro Switch portlibs may not include SQLite. If no Switch SQLite package is available, the installer falls back to building SQLite from the official amalgamation source. You can run that step directly with:

```sh
util/switch/build_sqlite.sh
```

## Environment

Source the Switch environment before building:

```sh
. util/switch/env.sh
```

The script verifies `DEVKITPRO`, `DEVKITA64`, `aarch64-none-elf-gcc`, `elf2nro`, `nxlink`, and CMake.

## Build

Configure and build the minimal Switch client:

```sh
util/switch/build.sh
```

The build script uses:

- `cmake/Toolchains/Switch.cmake`
- `BUILD_CLIENT=1`
- `BUILD_SERVER=0`
- `BUILD_UNITTESTS=0`
- `BUILD_DOCUMENTATION=0`
- `ENABLE_SOUND=0`
- `ENABLE_GETTEXT=0`
- `ENABLE_CURL=0`
- `ENABLE_LTO=0`
- `ENABLE_LUAJIT=0`
- `RUN_IN_PLACE=1`

To build and package a child-friendly client locked to a private server with Docker, use:

```sh
util/switch/verify_docker.sh build/switch \
	-DLOCKDOWN_CLIENT=1 \
	-DLOCKDOWN_SERVER_NAME=play.example.net \
	-DLOCKDOWN_SERVER_PORT=30000
```

Locked clients save the entered username and password locally so the user can reconnect without retyping credentials.

If you have a local devkitA64 toolchain installed, the same extra CMake options can be passed to `util/switch/build.sh`.

If `${DEVKITPRO}/portlibs/switch/lib/libsqlite3.a` is missing, the build script first runs `util/switch/build_sqlite.sh`.

To build only the first-render smoke app:

```sh
util/switch/build_smoke.sh
```

To package only the smoke app:

```sh
util/switch/package_smoke.sh
```

To reproduce the local Docker verification used for this port:

```sh
util/switch/verify_docker.sh
```

This runs the full Switch client build, full `.nro` package, smoke build, and smoke `.nro` package in the `devkitpro/devkita64` image.

For physical Switch testing, use the hardware checklist in [Nintendo Switch Hardware Validation](switch_hardware_validation.md).

## Package

Create the SD card layout and `.nro`:

```sh
util/switch/package.sh
```

The generated `.nro` embeds the Luanti icon plus name, author, and version metadata for hbmenu.

Validate that the package contains the expected runtime assets:

```sh
util/switch/validate_package.sh
```

The output is:

```text
build/switch/package/
  switch/luanti/luanti.nro
  switch/luanti/builtin/
  switch/luanti/client/
  switch/luanti/clientmods/
  switch/luanti/fonts/
  switch/luanti/games/devtest/
  switch/luanti/textures/
```

Copy `build/switch/package/switch/luanti` to `sdmc:/switch/luanti`, or send the app with `nxlink`.

To install to a mounted SD card root:

```sh
util/switch/install_to_sd.sh /path/to/sdcard
```

For a non-default package directory:

```sh
util/switch/install_to_sd.sh /path/to/sdcard build/switch-docker/package
```

To install the smoke app to a mounted SD card root:

```sh
util/switch/install_smoke_to_sd.sh /path/to/sdcard build/switch-docker/package-smoke
```

## Home Menu NSP Forwarder

The NSP forwarder is a small installed launcher for the Switch home menu. It
does not contain the Luanti runtime files; it hardcodes the SD-card NRO path and
launches `sdmc:/switch/luanti/luanti.nro`. Install the normal package to the SD
card first.

After `util/switch/package.sh` has created `build/switch/package`, prepare and
build the forwarder with:

```sh
util/switch/package_forwarder.sh build/switch/package build/switch/forwarder
```

The script writes `build/switch/forwarder/luanti-forwarder.txt` with the exact
forwarder metadata. If the PC-side `nton` command is available, it also builds
an `.nsp` and copies it into `build/switch/forwarder`.

To override the home-menu title ID:

```sh
util/switch/package_forwarder.sh build/switch/package build/switch/forwarder \
  --title-id 054C55414E544900
```

If `nton` is not available, use the generated metadata with an NRO-to-NSP
forwarder builder. The required NRO path is `sdmc:/switch/luanti/luanti.nro`.
The devkitPro Switch Docker image used by `util/switch/verify_docker.sh` does
not currently include an NSP/NCA packer.

## Run With nxlink

With hbmenu listening for network launch:

```sh
util/switch/run_nxlink.sh
```

To specify the Switch IP address or hostname:

```sh
util/switch/run_nxlink.sh 192.168.1.50
```

To send a package from a non-default build tree:

```sh
util/switch/run_nxlink.sh --build-dir build/switch-docker --package-dir build/switch-docker/package --ip 192.168.1.50
```

To save `nxlink -s` output while testing:

```sh
util/switch/run_nxlink.sh --build-dir build/switch-docker --package-dir build/switch-docker/package --ip 192.168.1.50 --log-file build/switch-client-nxlink.log
```

To launch the smoke app before testing the full client:

```sh
util/switch/run_smoke_nxlink.sh --ip 192.168.1.50 --log-file build/switch-smoke-nxlink.log
```

The smoke app should:

- print SDL initialization details over `nxlink -s`;
- print the GLES renderer and version;
- show an animated green-blue clear screen for about 20 seconds;
- print detected controllers and button/axis events;
- exit early when Plus/Start or B/East is pressed.

## Runtime Paths

The Switch port uses fixed homebrew paths:

- Share data: `sdmc:/switch/luanti`
- User data: `sdmc:/switch/luanti`
- Cache: `sdmc:/switch/luanti/cache`
- Logs: `sdmc:/switch/luanti/debug.txt`
- Early boot trace: `sdmc:/switch/luanti/switch_boot.txt`

After a hardware run, copy the SD-card log with:

```sh
util/switch/collect_debug_log.sh /path/to/sdcard
```

This creates `build/switch-YYYYmmdd-HHMMSS-debug.txt` and
`build/switch-YYYYmmdd-HHMMSS-boot.txt` when those logs exist.

Create a validation report with artifact hashes, package validation, and collected logs:

```sh
util/switch/create_validation_report.sh
```

## Current Limitations

- Sound is disabled.
- cURL, server list, ContentDB, and update checks are disabled.
- gettext is disabled.
- Bundled Lua is used instead of LuaJIT.
- Rendering is expected to use SDL2 and OpenGL ES through Switch Mesa.
- Controller input defaults to the Switch joystick layout. Button labels and axis ordering still need confirmation on Joy-Con and Pro Controller hardware.
- The devkitA64 build and `.nro` packaging path are verified in Docker, but runtime behavior still needs physical Switch validation.

## First Validation Checklist

- Done: CMake configure completes.
- Done: full client links.
- Done: `luanti.nro` is produced.
- Done: package layout includes the runtime assets needed for main menu and `devtest`.
- Done: `util/switch/verify_docker.sh` reproduces the local Docker build/package checks.
- Smoke app launches, displays an animated color clear, and prints SDL/GLES/controller diagnostics over `nxlink -s`.
- App launches from hbmenu.
- Main menu renders.
- `devtest` starts locally.
- Player can move, look, and interact with controller input.
- Game exits cleanly.
- `sdmc:/switch/luanti/debug.txt` is written.
