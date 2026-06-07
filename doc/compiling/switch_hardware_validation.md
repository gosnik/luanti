# Nintendo Switch Hardware Validation

Use this checklist after `util/switch/verify_docker.sh` passes locally. Record the Switch model, firmware, homebrew entry point, controller type, and whether the app was launched from SD card or `nxlink`.

## Smoke App

1. Send with `nxlink`:

   ```sh
   util/switch/run_smoke_nxlink.sh --ip 192.168.1.50 --log-file build/switch-smoke-nxlink.log
   ```

   Or install to SD card:

   ```sh
   util/switch/install_smoke_to_sd.sh /path/to/sdcard build/switch-docker/package-smoke
   ```

2. Expected screen result:
   - hbmenu shows `Luanti Smoke` with the Luanti icon.
   - The app opens fullscreen.
   - The screen clears to an animated green-blue color for about 20 seconds.
   - Plus/Start or B/East exits early.

3. Expected `nxlink -s` output:
   - socket initialization result is printed.
   - SDL initialization details are printed.
   - GLES renderer and version are printed.
   - Controller discovery is printed.
   - Button presses and large axis movements are printed.

## Full Client

1. Send with `nxlink`:

   ```sh
   util/switch/run_nxlink.sh --build-dir build/switch-docker --package-dir build/switch-docker/package --ip 192.168.1.50 --log-file build/switch-client-nxlink.log
   ```

   Or install to SD card:

   ```sh
   util/switch/install_to_sd.sh /path/to/sdcard build/switch-docker/package
   ```

2. Expected launch result:
   - hbmenu shows `Luanti` with the Luanti icon.
   - The app opens fullscreen at 1280x720.
   - The main menu renders without missing-font or missing-shader errors.
   - `sdmc:/switch/luanti/debug.txt` is created.

3. Expected local game result:
   - Create or select a `devtest` world.
   - The world loads without crashing.
   - Left stick moves the player.
   - Right stick moves the camera.
   - Jump, sneak, dig, place, inventory, and hotbar next/previous have usable mappings.
   - The game exits cleanly back to hbmenu.

## Failure Notes

If a test fails, keep the `nxlink -s` output or the `--log-file` output,
`sdmc:/switch/luanti/debug.txt`, and `sdmc:/switch/luanti/switch_boot.txt`.
To copy the SD-card logs after removing or mounting the SD card:

```sh
util/switch/collect_debug_log.sh /path/to/sdcard
```

To create a report with artifact hashes, package validation, and any captured logs:

```sh
util/switch/create_validation_report.sh \
  --nxlink-log build/switch-client-nxlink.log \
  --smoke-log build/switch-smoke-nxlink.log \
  --debug-log build/switch-YYYYmmdd-HHMMSS-debug.txt \
  --boot-log build/switch-YYYYmmdd-HHMMSS-boot.txt
```

Note whether the smoke app passed; that separates SDL/GLES/input setup issues from full-client asset, main-menu, or game-runtime issues.
