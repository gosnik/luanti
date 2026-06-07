# Evolve

Admin-only server tools for Mineclonia worlds.

Evolve is intended for live-server world curation: terraforming, roads, simple generated buildings, villages, cities, and treasure chests. It is server-side only and targets `games/mineclonia/`.

It also adjusts the server clock by default: daylight advances at half normal speed, making days twice as long, while night advances at four times normal speed, making nights one quarter as long. Disable or tune this with the `evolve.time_*` settings.

## Privilege

Grant admins the `evolve` privilege:

```text
/grant <name> evolve
```

## Commands

```text
/ev help
/ev undo
/ev terraform <radius> <max_height>
/ev terraform_status
/ev terraform_cancel
/ev road <length> <width> [node]
/ev treasure <area> <amount> [tier]
/ev hut
/ev village <small|medium|large>
/ev city <small|medium|large>
/ev villagers <radius> <count> [area_name]
/ev evolve_villagers <radius> [count]
/ev evolve_villager <role>
/ev animals <radius> [count]
/ev charm_scatter <radius> <count>
/ev beautify <radius>
/ev mushroom_kingdom <area>
/ev pipe_link [distance]
/ev castle [small|medium|large]
```

`/evolve` is an alias for `/ev`.

All large operations are bounded by `settingtypes.txt`.

`/ev terraform` reshapes the circular area around the admin into terrain from sea level up to `max_height` using layered 2D Perlin noise. Use a low max height for levelling and a higher max height for rolling hills. The outer band blends back to the existing terrain height so the perimeter does not form a hard cliff. Radii up to `evolve.terraform_sync_radius` are undoable; larger radii run as chunked background jobs and are not stored in undo history. Use `/ev terraform_status` and `/ev terraform_cancel` for large jobs.

`/ev village` and `/ev city` generate larger settlements with varied cottages, farmhouses, barns, farms, markets, wells, and towers. Building positions are selected from layered 2D Perlin noise so the layout is organic rather than fixed, and each building resolves its own footprint to local ground level before placement.

`/ev treasure <area> <amount> [tier]` scatters random treasure types around the admin at ground height. The area is a radius around the admin. Omit `tier` to mix low, medium, and rare treasure; each cache may appear as a simple chest, buried cache, tiny shrine, woodland cache, or gem pedestal.

`/ev villagers` assigns existing Mineclonia villagers in the radius first, then spawns any remaining requested villagers on safe ground-level positions. It claims available beds, bells, and job-site nodes in the area using Mineclonia's native villager APIs.

`/ev evolve_villagers <radius> [count]` spawns a mix of Evolve NPC villagers: Fairy, Wizard, Builder, Pet Keeper, Princess, Rainbow Trader, Guard, and Gardener. `/ev evolve_villager <role>` places one specific role near the admin. Right-click them for a simple menu with Talk, Give me magic, Build something, Follow me, and Stay here. Evolve villagers can also magically appear near active players, hang around for a short while, then sparkle-teleport elsewhere; tune this with `evolve.evolve_villagers_*` settings.

`/ev animals <radius> [count]` populates safe ground around the admin with random peaceful Mineclonia land animals such as cows, pigs, sheep, chickens, rabbits, horses, llamas, cats, parrots, and occasional mooshrooms. If `count` is omitted, Evolve chooses a count based on area size.

`/ev charm_scatter` drops random Wonder Charm collectible trigger items around the admin at ground height. Players activate the matching charm by picking them up.

`/ev beautify <radius>` decorates safe natural ground around the admin with Perlin-clustered flowers, shrubs, and hand-built trees. It only places into air, skips protected positions, and is undoable with `/ev undo`.

`/ev mushroom_kingdom <area>` paints a bright fantasy biome around the admin with 2D Perlin rolling hills, randomized giant and normal mushroom patches, flowers, blocky clouds, coin trails, pipe entrances, and a secret underground room. The area is a radius around the admin and is undoable with `/ev undo`.

`/ev pipe_link` creates a pair of bright fantasy teleport pipes: one near the admin and one farther in the direction the admin is facing. Players who step into either pipe are teleported to the other.

`/ev castle` generates a fairy-tale castle near the admin with towers, stained glass, throne room, ballroom, gardens, moat, bridge, and secret passageways.

## Wonder Charms

Evolve includes child-friendly magical items for creative play:

```text
evolve:fairy_wings
evolve:rainbow_ribbon
evolve:blossom_wand
evolve:twinkle_lantern
evolve:bubble_boots
evolve:tiny_charm
evolve:mermaid_pearl
evolve:star_popper
evolve:cloud_wand
evolve:animal_bell
evolve:treasure_twinkle
evolve:wishing_star
```

Admin commands:

```text
/evolve_magic_give <player> <charm>
/evolve_magic_collectibles
/evolve_magic_give_collectible <player> <charm> [count]
/evolve_magic_clear <player>
/evolve_magic_resetme
/evolve_add_treasure <name>
/evolve_remove_nearest_treasure
/evolve_list_treasure
```

The charms are designed as safe magical toys: particles, temporary effects, temporary clouds, flowers on safe natural ground, harmless companions, and no fire/explosions/block damage.

Wonder Charms can also activate when a player picks up associated collectible items. By default one collected trigger item is consumed and the matching charm power starts. Use `evolve_magic_collectibles`, `evolve_magic_consume_collectibles`, and `evolve_magic_collectible_items` to enable, tune, or extend the mapping.
