# AGENTS.md

Guidance for agents and contributors making the `evolve` server-side admin tools mod in this Luanti workspace.

## Project Goal

Create `mods/evolve`, a server-side Luanti mod compatible with `games/mineclonia/`. "Evolve" is the loose theme: admins should be able to evolve terrain, settlements, treasure, events, and exploration spaces over time. The mod should give trusted admins tools to make the server more fun, including:

- Terraforming land safely and reversibly.
- Creating villages, cities, ruins, roads, arenas, landmarks, and event spaces.
- Placing treasure chests and reward structures.
- Spawning controlled encounters, NPCs, mobs, and points of interest.
- Running server events without requiring client-side mods.

Use the Luanti / Minetest Modding Book as a general reference:

`https://rubenwardy.com/minetest_modding_book/en/index.html`

Prefer local examples before generic online examples:

- Use `mods/` for external mod structure, style, settings, screenshots, textures, and server-side implementation examples.
- Use `games/mineclonia/mods/` for game-specific item names, node names, entities, loot APIs, and structure patterns.

## Compatibility Target

- Game: `games/mineclonia/`
- Engine baseline: Mineclonia declares `min_minetest_version = 5.10` in `games/mineclonia/game.conf`.
- Runtime: server-side only. Do not require client-side mods.
- Mod location: create and update the admin tools mod under `mods/evolve/`.
- Reference mods: use existing mods under `mods/` as examples, especially `mods/terraform/` and `mods/sky_islands/`.

Do not assume Minetest Game node names such as `default:dirt`, `default:stone`, or `default:chest`. Mineclonia uses names such as `mcl_core:dirt`, `mcl_core:stone`, `mcl_chests:chest`, and `mobs_mc:*`.

## Expected Mod Shape

Use this focused mod directory:

```text
mods/evolve/
  mod.conf
  init.lua
  settingtypes.txt
  README.md
  api.lua
  commands.lua
  terraform.lua
  structures.lua
  treasure.lua
  villages.lua
  schematics/
  textures/
```

Recommended `mod.conf` baseline:

```ini
name = evolve
title = Evolve
description = Admin-only tools for terraforming, schematics, villages, treasures, and server events.
depends = mcl_core, mcl_chests, mcl_loot
optional_depends = mcl_structures, mcl_villages, mcl_mobs, mobs_mc, mcl_farming, mcl_doors, mcl_beds
```

Keep hard dependencies minimal. Put Mineclonia integrations behind `core.get_modpath("modname")` checks when possible.

## API Style

Luanti code in this tree uses both `minetest` and `core`; they are aliases. Follow nearby code style. If starting a new mod, use one consistently. `core` matches much of Mineclonia, while `minetest` matches many external mod examples.

Expose one global namespace only:

```lua
evolve = {}
local S = core.get_translator("evolve")
```

Avoid polluting globals. Use `local` for helpers, tables, and constants.

## Admin Safety

All destructive or high-impact tools must be protected by a dedicated privilege:

```lua
core.register_privilege("evolve", {
	description = "Use Evolve admin tools",
	give_to_singleplayer = false,
})
```

Every command and tool callback must check privileges before acting:

```lua
if not core.check_player_privs(name, { evolve = true }) then
	return false, "Missing evolve privilege."
end
```

Do not silently allow use by `server`, `creative`, `give`, or `privs` privilege alone. Those can be broader than intended.

## Command Design

Use chat commands for server-side admin workflows:

- `/sft help`
- `/sft undo`
- `/sft terraform <shape> <radius> <material>`
- `/sft smooth <radius>`
- `/sft road <length> <width> <material>`
- `/sft village <small|medium|large>`
- `/sft city <style> <size>`
- `/sft treasure <tier>`
- `/sft landmark <name>`
- `/sft event <name>`

The command prefix may remain `/sft` if already implemented, but new work should prefer an Evolve-branded prefix such as `/evolve` or `/ev`. Keep aliases thin and route all behavior through one command dispatcher.

Command handlers should validate all input:

- Clamp radii, heights, widths, and counts.
- Reject unknown node names, entity names, and schematic names.
- Require explicit confirmation for very large operations.
- Return clear messages to the invoking admin.
- Log destructive operations with player name, position, parameters, and affected volume.

## Terraforming Rules

Use VoxelManip for large terrain edits. Use direct node APIs only for small edits or callbacks that must trigger normal node behavior.

Required behavior:

- Capture undo data before writing.
- Clamp operation volume with settings.
- Never write outside the requested bounding box.
- Call lighting updates or use appropriate write flags after bulk edits.
- Avoid running huge edits synchronously in one globalstep.
- Prefer queued chunked work for cities, roads, caves, and large terrain changes.

Recommended settings:

```text
evolve.max_radius (Max terraform radius) int 3000 1 5000
evolve.max_volume (Max nodes changed per operation) int 1000000 1 2000000
evolve.terraform_sync_radius (Max undoable terraform radius) int 64 1 256
evolve.terraform_chunk_size (Terraform chunk size) int 32 8 80
evolve.terraform_chunks_per_step (Terraform chunks per server step) int 1 1 16
evolve.time_enable (Enable Evolve time controller) bool true
evolve.time_day_start (Daylight start time-of-day) float 0.23 0 1
evolve.time_night_start (Night start time-of-day) float 0.77 0 1
evolve.time_day_speed (Daylight speed multiplier) float 0.5 0 10
evolve.time_night_speed (Night speed multiplier) float 4.0 0 20
evolve.max_villager_radius (Max villager assignment radius) int 128 8 256
evolve.max_villager_count (Max villagers per command) int 64 1 128
evolve.max_charm_scatter_radius (Max Wonder Charm collectible scatter radius) int 256 8 1000
evolve.max_charm_scatter_count (Max Wonder Charm collectible scatter count) int 256 1 1000
evolve.undo_depth (Undo entries per player) int 20 0 100
evolve.require_confirm_volume (Confirm above this volume) int 20000 1 1000000
evolve.max_structure_size (Max generated structure size) int 128 8 256
evolve_magic_collectibles (Enable charm powers from collected items) bool true
evolve_magic_consume_collectibles (Consume collectible trigger items) bool true
evolve_magic_collectible_items (Extra collectible item mappings) string
```

Use Mineclonia node groups when choosing materials, but write exact node names in commands. Examples:

- Stone: `mcl_core:stone`
- Dirt: `mcl_core:dirt`
- Grass dirt: check the local registered node name before using it.
- Oak planks, stairs, doors, beds, crops, and lamps: inspect `games/mineclonia/mods/ITEMS/*` first.

## Structures, Villages, and Cities

For reusable buildings, prefer `.mts` schematics in `schematics/`. Use `core.place_schematic` for simple placement unless Mineclonia's `mcl_structures` API is needed and available.

When integrating with Mineclonia structures:

- Inspect `games/mineclonia/mods/MAPGEN/mcl_structures/` before calling internal APIs.
- Treat `mcl_structures` and `mcl_levelgen` APIs as game-specific and subject to change.
- Gate integrations with optional dependency checks.
- Keep a fallback path using standard Luanti APIs.

City and village placement should be staged:

1. Survey the area and reject unsafe placements.
2. Flatten or terrace only the required footprint.
3. Place roads and anchors.
4. Place buildings from schematics.
5. Add chests, lights, doors, beds, farms, wells, and decorations.
6. Spawn mobs or NPCs last.
7. Save an undo record or structure manifest.

Do not overwrite player builds by default. Before placing large structures, scan for protected areas and non-natural blocks. If protection mods are present, use protection checks.

## Treasure and Loot

Use Mineclonia loot helpers when available:

- `mcl_loot.get_loot`
- `mcl_loot.get_multi_loot`
- `mcl_loot.fill_inventory`

Place Mineclonia chests using `mcl_chests:chest` unless local code shows a better node for the intended use. After placing a chest, get its metadata inventory and fill the `main` list.

Treasure tiers should be configured in Lua tables or settings, not scattered across command handlers. Keep rewards fun but server-safe:

- Avoid giving admin-only or crash-prone items.
- Avoid unlimited high-value loot from repeatable commands.
- Log treasure placement.
- Consider cooldowns or per-event manifests for public events.

## Mobs and Encounters

Use Mineclonia entity names, usually `mobs_mc:*`, and confirm names in `games/mineclonia/mods/ENTITIES/`.

When spawning encounters:

- Clamp mob counts.
- Avoid spawning in unloaded or unsafe positions.
- Keep hostile spawns away from protected spawn unless explicitly requested.
- Store spawned object refs only temporarily; persist positions and event IDs instead.
- Provide a cleanup command for event mobs and temporary structures.

## Persistence

Use mod storage for persistent data:

```lua
local storage = core.get_mod_storage()
```

Persist only compact manifests:

- Operation ID
- Admin name
- Timestamp
- Bounds
- Tool name and parameters
- Schematic names
- Treasure/event IDs

Do not store huge undo node arrays in mod storage unless there is a strong reason. Large undo histories should stay in memory or be bounded aggressively.

## Performance

Server fun tools can destroy tick time if they are careless. Follow these limits:

- Bound every area operation.
- Use queues for multi-building and large terrain jobs.
- Process large jobs incrementally with `core.after` or globalstep scheduling.
- Cache content IDs inside VoxelManip operations.
- Avoid repeated `core.get_node` calls over large volumes.
- Avoid ABMs for admin tools unless there is no simpler event-driven option.

Default to boring, predictable performance over clever procedural generation.

## Security

Do not use insecure APIs, shell commands, file writes outside the mod directory, or dynamic Lua loading for normal gameplay features.

Never trust chat command parameters. Validate:

- Numbers
- Node names
- Entity names
- Schematic names
- Direction and rotation values
- Player names

If a command affects another player, require a clear privilege check and log it.

## Testing and Verification

Before calling work done:

1. Run Luanti with Mineclonia selected and the mod enabled.
2. Start a test world, grant `evolve` to an admin account, and verify non-privileged players cannot use tools.
3. Test each command with valid input, bad input, missing input, and oversized input.
4. Test undo after terraforming and structure placement.
5. Place at least one treasure chest and verify the inventory contains Mineclonia-valid items.
6. Confirm no command references `default:*` nodes.
7. Check `debug.txt` for warnings or Lua errors.

Useful local searches:

```bash
rg "default:" mods/evolve
rg "mcl_loot|mcl_chests|mcl_structures|mobs_mc" games/mineclonia/mods mods/evolve
rg "register_chatcommand|register_privilege" mods/evolve games/mineclonia/mods mods
```

## Existing Local References

- `mods/` is the local reference area for external mods. Check it before inventing layout, settings, texture naming, README style, or command/tool patterns.
- `mods/terraform/` is an existing external terraforming mod. It shows privilege checks, tool callbacks, VoxelManip usage, and undo history ideas. Do not copy it blindly; adapt patterns and add stronger bounds and Mineclonia-specific validation.
- `mods/sky_islands/` is a compact external mod example. Use it for simple mod shape and mapgen-oriented patterns.
- `games/mineclonia/mods/CORE/mcl_loot/` contains Mineclonia loot helpers.
- `games/mineclonia/mods/MAPGEN/mcl_structures/` contains Mineclonia structure placement patterns.
- `games/mineclonia/mods/PLAYER/mcl_bonus_chest/` shows a simple chest placement and loot-fill workflow.
- `games/mineclonia/mods/ENTITIES/mobs_mc/` contains Mineclonia mob/entity definitions.

## Development Principles

- Keep the mod server-side and admin-focused.
- Prefer explicit, reversible operations.
- Keep Mineclonia compatibility ahead of generic Minetest Game compatibility.
- Add settings for every risky limit.
- Log anything destructive, valuable, or player-affecting.
- Build fun features as composable primitives: select area, terraform, place schematic, fill loot, spawn encounter, cleanup.
- Keep public APIs small and documented in the mod README.
