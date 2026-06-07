local modpath = core.get_modpath("evolve")

evolve.magic = evolve.magic or {}
evolve.magic.effects = evolve.magic.effects or {}
evolve.magic.players = evolve.magic.players or {}

evolve.magic.settings = {
	enabled = core.settings:get_bool("evolve_magic_enable", true),
	particles = core.settings:get_bool("evolve_magic_particles", true),
	permanent_flowers = core.settings:get_bool("evolve_magic_permanent_flowers", true),
	cloud_wand = core.settings:get_bool("evolve_magic_cloud_wand", true),
	max_clouds_per_player = tonumber(core.settings:get("evolve_magic_max_clouds_per_player")) or 30,
	collectibles = core.settings:get_bool("evolve_magic_collectibles", true),
	consume_collectibles = core.settings:get_bool("evolve_magic_consume_collectibles", true),
	collectible_items = core.settings:get("evolve_magic_collectible_items") or "",
	tiny_collision = core.settings:get_bool("evolve_magic_tiny_collision", false),
	treasure_twinkle = core.settings:get_bool("evolve_magic_treasure_twinkle", true),
	animal_bell = core.settings:get_bool("evolve_magic_animal_bell", true),
}

if not evolve.magic.settings.enabled then
	return
end

dofile(modpath .. "/magic/safety.lua")
dofile(modpath .. "/magic/particles.lua")
dofile(modpath .. "/magic/temporary_nodes.lua")
dofile(modpath .. "/magic/effects.lua")
dofile(modpath .. "/magic/hud.lua")
dofile(modpath .. "/magic/animals.lua")
dofile(modpath .. "/magic/treasure.lua")
dofile(modpath .. "/magic/items.lua")
