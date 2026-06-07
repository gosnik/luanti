# Nintendo Switch Homebrew Client Plan

Goal: produce a Switch homebrew `.nro` client build of Luanti, initially minimal and offline-capable, then iterate toward networking, audio, and polish.

Current status:

- Implemented the initial Switch build scaffold, toolchain file, packaging scripts, and Switch platform layer.
- Verified in the `devkitpro/devkita64` container that the minimal client config compiles and links to `build/switch-docker/bin/luanti.elf`.
- Verified `util/switch/package.sh` produces `build/switch-docker/package/switch/luanti/luanti.nro` with the expected runtime asset layout.
- Verified the Switch SDL2/OpenGL ES smoke target builds.
- Not yet verified on physical Switch hardware. Launch, rendering, input, filesystem logging, and local `devtest` startup remain hardware validation tasks.

## Phase 1: Toolchain Bootstrap

1. Add `util/switch/install_devkitpro.sh`.
   - Status: implemented.
   - Detect Linux, macOS, and MSYS2.
   - Install or verify devkitPro pacman.
   - Install Switch packages:
     - `switch-dev`
     - `devkitA64`
     - `libnx`
     - `switch-tools`
     - `switch-cmake`
     - `switch-pkg-config` if available; otherwise use host `pkg-config`
     - `switch-sdl2`
     - `switch-mesa`
     - `switch-zlib`
     - `switch-zstd`
     - `switch-sqlite3` or source-built SQLite fallback
     - `switch-freetype`
     - `switch-libpng`
     - `switch-libjpeg-turbo`
   - Optional later packages:
     - `switch-curl`
     - Switch audio packages, once the audio backend path is chosen.
   - Verify:
     - `DEVKITPRO`
     - `DEVKITA64`
     - `aarch64-none-elf-gcc`
     - `elf2nro`
     - `nxlink`

devkitPro's current guidance is to use pacman-managed toolchains and install `switch-dev` for Switch development:

- https://devkitpro.org/wiki/Getting_Started
- https://switchbrew.org/wiki/Setting_up_Development_Environment

## Phase 2: Build Entry Points

2. Add `util/switch/env.sh`.
   - Status: implemented.
   - Source `/opt/devkitpro/switchvars.sh` if present.
   - Export `DEVKITPRO`, `DEVKITA64`, `PATH`, and `PKG_CONFIG_PATH`.
   - Fail clearly if the devkitPro environment is missing.

3. Add `util/switch/build.sh`.
   - Status: implemented and verified in the devkitPro container.
   - Configure CMake with a Switch toolchain file.
   - Use the initial minimal client flags:

     ```sh
     cmake -S . -B build/switch \
       -DCMAKE_TOOLCHAIN_FILE=cmake/Toolchains/Switch.cmake \
       -DBUILD_CLIENT=1 \
       -DBUILD_SERVER=0 \
       -DBUILD_UNITTESTS=0 \
       -DBUILD_BENCHMARKS=0 \
       -DBUILD_DOCUMENTATION=0 \
       -DENABLE_SOUND=0 \
       -DENABLE_GETTEXT=0 \
       -DENABLE_CURL=0 \
       -DENABLE_UPDATE_CHECKER=0 \
       -DENABLE_LTO=0 \
       -DENABLE_LUAJIT=0 \
       -DENABLE_POSTGRESQL=0 \
       -DENABLE_LEVELDB=0 \
       -DENABLE_REDIS=0 \
       -DENABLE_PROMETHEUS=0 \
       -DENABLE_SPATIAL=0 \
       -DENABLE_OPENSSL=0 \
       -DENABLE_SYSTEM_GMP=0 \
       -DENABLE_SYSTEM_JSONCPP=0 \
       -DENABLE_OPENGL=0 \
       -DENABLE_OPENGL3=0 \
       -DENABLE_GLES2=1 \
       -DRUN_IN_PLACE=1
     ```

   - Build with:

     ```sh
     cmake --build build/switch
     ```

4. Add `cmake/Toolchains/Switch.cmake`.
   - Status: implemented.
   - Set `CMAKE_SYSTEM_NAME` for devkitA64 cross-compilation.
   - Use `aarch64-none-elf-gcc` and `aarch64-none-elf-g++`.
   - Point CMake and pkg-config at `$DEVKITPRO/portlibs/switch` and `$DEVKITPRO/libnx`.
   - Add required libnx compile and link flags.
   - Prefer package discovery through devkitPro portlibs.

## Phase 3: Switch Platform Layer

5. Add `src/porting_switch.cpp`.
   - Status: implemented.
   - Similar role to `src/porting_android.cpp`, but libnx/SDL-oriented.
   - Implement `porting::osSpecificInit()`.
   - Set paths:
     - `path_share = "sdmc:/switch/luanti"`
     - `path_user = "sdmc:/switch/luanti"`
     - `path_cache = "sdmc:/switch/luanti/cache"`
   - Ensure directories exist.
   - Set a sane locale fallback.
   - Add graceful shutdown hooks.

6. Update CMake platform conditionals.
   - Status: implemented.
   - Append `porting_switch.cpp` when building for Switch.
   - Treat Switch like Android for direct SDL2 linking where needed.
   - Disable install rules that assume desktop Unix paths.
   - Add a compile definition such as `__SWITCH__` or `LUANTI_SWITCH`.

## Phase 4: Graphics and Windowing

7. Get IrrlichtMt compiling for Switch.
   - Status: implemented enough for the minimal client to compile and link with SDL2/OpenGL ES.
   - Use the SDL2 backend.
   - Use OpenGL ES through `switch-mesa`.
   - Audit IrrlichtMt CMake for desktop-only OpenGL/X11 assumptions.
   - Ensure shader paths resolve under `sdmc:/switch/luanti/client/shaders/Irrlicht`.

8. Add a first-render smoke target.
   - Status: implemented as `luanti_switch_smoke`, verified to build and package, with `util/switch/build_smoke.sh`, `util/switch/package_smoke.sh`, `util/switch/install_smoke_to_sd.sh`, and `util/switch/run_smoke_nxlink.sh` for hardware testing.
   - Build a small Switch-only test app if needed before the full client.
   - Confirm SDL window creation, GLES context creation, clear screen rendering, and input events.
   - Emit `nxlink -s` diagnostics for SDL init, GLES renderer/version, controller discovery, button presses, and large axis motion.
   - Use this to isolate graphics and toolchain problems from full engine problems.

## Phase 5: `.nro` Packaging

9. Add `util/switch/package.sh`.
   - Status: implemented and verified to produce `luanti.nro`; `util/switch/validate_package.sh` checks the runtime asset layout.
   - Convert the ELF to `.nro` with `elf2nro`.
   - Include icon, name, author, and version metadata.
   - Create deploy layout:

     ```text
     build/switch/package/
       switch/luanti/luanti.nro
       switch/luanti/builtin/
       switch/luanti/client/
       switch/luanti/fonts/
       switch/luanti/games/
       switch/luanti/textures/
     ```

   - Copy the minimum runtime assets needed for the main menu and `devtest`.
   - Provide `util/switch/install_to_sd.sh` to copy the validated package to a mounted SD-card root.

10. Add `util/switch/run_nxlink.sh`.
    - Status: implemented, pending hardware validation.
    - Use `nxlink build/switch/package/switch/luanti/luanti.nro`.
    - Accept an optional Switch IP argument for faster testing.
    - Accept optional `--build-dir`, `--package-dir`, `--ip`, and `--log-file` arguments for non-default build trees, hostnames, and captured hardware logs.

## Phase 6: Input

11. Start with SDL controller input.
    - Status: implemented with a deterministic Switch joystick layout and default `joystick_type=switch`; pending hardware validation.
    - Enable `enable_joysticks=true` by default on Switch.
    - Map Joy-Con and Pro Controller buttons to Luanti actions.
    - Verify analog stick movement and camera controls.
    - Decide later whether touch controls should be enabled in handheld mode.

12. Add Switch-specific defaults.
    - Status: implemented.
    - Fullscreen true.
    - Reasonable resolution handling.
    - Lower default view range and texture settings for first boot.
    - Disable update checker and content browser while cURL is off.

## Phase 7: Dependencies and Feature Recovery

13. Bring features back one by one.
    - Status: pending after the minimal offline client is validated on hardware.
    - cURL, server list, and content browser after the core client runs.
    - gettext after packaging paths are stable.
    - Sound after confirming available Switch OpenAL/Vorbis-compatible packages or replacing the backend.
    - Remote media after cURL works.
    - Keep PostgreSQL, LevelDB, Redis, and Prometheus off for Switch.
    - Keep SQLite WAL disabled for the source-built Switch SQLite fallback until libnx-compatible WAL/mmap support is validated.

14. Prefer bundled Lua over LuaJIT initially.
    - Status: implemented for the Switch build scripts.
    - The current CMake already falls back to bundled Lua when LuaJIT is unavailable.
    - This avoids JIT/platform issues during the first port.

## Phase 8: Validation Checklist

15. Define milestone tests.
    - Done: configure completes in the devkitPro container.
    - Done: full client links.
    - Done: `.nro` is produced.
    - Done: package layout includes the runtime assets needed for main menu and `devtest`.
    - Done: `util/switch/verify_docker.sh` reproduces the full local build/package and smoke build/package checks.
    - Pending hardware: smoke app launches and displays the animated GLES clear screen.
    - Pending hardware: app launches from hbmenu.
    - Pending hardware: main menu renders.
    - Pending hardware: `devtest` starts locally.
    - Pending hardware: player can move, look, and interact.
    - Pending hardware: game exits cleanly.
    - Pending hardware: logs are written under `sdmc:/switch/luanti/debug.txt` and can be collected with `util/switch/collect_debug_log.sh`.
    - Pending hardware: validation evidence can be summarized with `util/switch/create_validation_report.sh`.

16. Document the workflow.
    - Status: implemented in `doc/compiling/switch.md`.
    - Add `doc/compiling/switch.md`.
    - Include setup, build, package, deploy, known limitations, troubleshooting, and the hardware checklist in `doc/compiling/switch_hardware_validation.md`.

## Main Risks

- IrrlichtMt may need Switch-specific CMake and GLES fixes.
- SDL2 on Switch may expose input quirks, especially button ordering.
- File paths must avoid desktop assumptions.
- Audio may require a separate backend decision.
- Memory and performance will likely need tuning after first launch.

## Recommended First Milestone

Target a minimal `.nro` that launches to the Luanti main menu with no sound, no cURL, no gettext, bundled Lua, SDL2 input, GLES rendering, and assets loaded from `sdmc:/switch/luanti`.

This keeps the first port focused on the hard platform issues: toolchain, linking, graphics, input, and filesystem.
