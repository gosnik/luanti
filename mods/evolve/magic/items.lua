core.register_privilege("evolve_magic_admin", {
	description = "Can configure evolve magical power-up features",
	give_to_singleplayer = true,
})

evolve.magic.charms = evolve.magic.charms or {}
evolve.magic.collectible_items = evolve.magic.collectible_items or {}

local function tex(base, color)
	return base .. (color and ("^[colorize:" .. color .. ":120") or "")
end

function evolve.magic.activate_charm(player, charm_name, pointed_thing)
	local def = evolve.magic.charms[charm_name]
	if not def then
		return false
	end
	if def.on_use then
		return def.on_use(ItemStack("evolve:" .. charm_name), player, pointed_thing) ~= false
	end
	if def.effect then
		return evolve.magic.activate_effect_item(player, def.effect)
	end
	return false
end

function evolve.magic.register_charm(item_name, def)
	evolve.magic.charms[item_name] = def
	local function activate(itemstack, user, pointed_thing)
		if not user or not user:is_player() then
			return itemstack
		end
		evolve.magic.activate_charm(user, item_name, pointed_thing)
		return itemstack
	end
	core.register_craftitem("evolve:" .. item_name, {
		description = def.description,
		inventory_image = def.inventory_image or tex("default_diamond.png", "#ffccff"),
		wield_image = def.inventory_image or tex("default_diamond.png", "#ffccff"),
		stack_max = 1,
		on_use = activate,
		on_place = activate,
		on_secondary_use = activate,
	})
end

function evolve.magic.register_collectible_item(item_name, charm_name)
	if item_name and evolve.magic.charms[charm_name] then
		evolve.magic.collectible_items[item_name] = charm_name
	end
end

local function flower_step(player)
	local pos = vector.round(player:get_pos())
	local below = vector.offset(pos, 0, -1, 0)
	local place = vector.offset(pos, 0, 0, 0)
	if not evolve.magic.can_modify_pos(player, place) or not evolve.magic.is_safe_air(place) then
		return
	end
	if not evolve.magic.is_natural_ground(below) then
		return
	end
	local flowers = { "mcl_flowers:poppy", "mcl_flowers:dandelion", "mcl_flowers:tulip_pink", "mcl_flowers:blue_orchid" }
	local f = flowers[(core.hash_node_position(pos) % #flowers) + 1]
	if core.registered_nodes[f] then
		core.set_node(place, { name = f })
		if not evolve.magic.settings.permanent_flowers then
			evolve.magic.temporary_nodes[core.pos_to_string(place)] = {
				pos = vector.new(place),
				node = f,
				restore = "air",
				expires = core.get_gametime() + 20,
				owner = player:get_player_name(),
			}
		end
	end
end

evolve.magic.register_effect("fairy_wings", {
	description = "Fairy Wings",
	duration = 30,
	cooldown = 5,
	on_start = function(player) evolve.magic.spawn_sparkles(player:get_pos(), 18) end,
	on_step = function(player) if math.random(1, 5) == 1 then evolve.magic.spawn_sparkles(player:get_pos(), 4) end end,
})

evolve.magic.register_effect("rainbow_trail", {
	description = "Rainbow Ribbon",
	duration = 20,
	cooldown = 5,
	on_step = function(player)
		local vel = player:get_velocity()
		if vel and vector.length(vel) > 0.3 then
			evolve.magic.spawn_rainbow(player:get_pos())
		end
	end,
})

evolve.magic.register_effect("flower_steps", {
	description = "Blossom Wand",
	duration = 30,
	cooldown = 10,
	on_step = function(player, _, params)
		params.timer = (params.timer or 0) + 0.1
		if params.timer >= 0.5 then
			params.timer = 0
			flower_step(player)
			evolve.magic.spawn_petals(player:get_pos(), 4)
		end
	end,
})

evolve.magic.register_effect("twinkle_light", {
	description = "Twinkle Lantern",
	duration = 120,
	cooldown = 5,
	on_start = function(player)
		local state = evolve.magic.get_player_state(player)
		if state.state.light_entity then state.state.light_entity:remove() end
		local obj = core.add_entity(vector.offset(player:get_pos(), 0, 2, 0), "evolve:magic_companion")
		if obj then
			obj:get_luaentity().owner = player:get_player_name()
			obj:set_properties({ textures = { "mcl_particles_effect.png^[colorize:#ffffaa:180" }, visual_size = { x = 0.45, y = 0.45 } })
			state.state.light_entity = obj
		end
	end,
	on_stop = function(player)
		local state = evolve.magic.get_player_state(player)
		if state.state.light_entity then state.state.light_entity:remove(); state.state.light_entity = nil end
	end,
})

evolve.magic.register_effect("bubble_bounce", {
	description = "Bubble Boots",
	duration = 30,
	cooldown = 5,
	on_start = function(player) evolve.magic.spawn_bubbles(player:get_pos(), 14) end,
	on_step = function(player) if math.random(1, 10) == 1 then evolve.magic.spawn_bubbles(player:get_pos(), 4) end end,
})

evolve.magic.register_effect("tiny_mode", {
	description = "Tiny Charm",
	duration = 30,
	cooldown = 10,
	on_start = function(player)
		local state = evolve.magic.get_player_state(player)
		state.state.original_properties = state.state.original_properties or player:get_properties()
		player:set_properties({ visual_size = { x = 0.45, y = 0.45 } })
		evolve.magic.spawn_sparkles(player:get_pos(), 20)
	end,
	on_stop = function(player)
		local state = evolve.magic.get_player_state(player)
		if state.state.original_properties then
			player:set_pos(evolve.magic.find_safe_nearby_pos(player:get_pos(), 3))
			player:set_properties(state.state.original_properties)
			state.state.original_properties = nil
		end
	end,
})

evolve.magic.register_effect("mermaid_bubble", {
	description = "Mermaid Pearl",
	duration = 120,
	cooldown = 5,
	on_step = function(player)
		if player.set_breath then player:set_breath(11) end
		if math.random(1, 8) == 1 then evolve.magic.spawn_bubbles(player:get_pos(), 5) end
	end,
})

evolve.magic.register_effect("friendly_animal", {
	description = "Animal Friend",
	duration = 180,
	on_stop = function(player)
		local state = evolve.magic.get_player_state(player)
		if state.state.animal_entity then state.state.animal_entity:remove(); state.state.animal_entity = nil end
	end,
})

local charms = {
	fairy_wings = { description = "Fairy Wings", texture = tex("mcl_armor_inv_elytra.png", "#ffccff"), effect = "fairy_wings" },
	rainbow_ribbon = { description = "Rainbow Ribbon", texture = tex("wool_magenta.png", "#ffffff"), effect = "rainbow_trail" },
	blossom_wand = { description = "Blossom Wand", texture = tex("mcl_flowers_tulip_pink.png"), effect = "flower_steps" },
	twinkle_lantern = { description = "Twinkle Lantern", texture = tex("default_torch_on_floor.png", "#ffffaa"), effect = "twinkle_light" },
	bubble_boots = { description = "Bubble Boots", texture = tex("mcl_potions_potion_overlay.png", "#99ddff"), effect = "bubble_bounce" },
	tiny_charm = { description = "Tiny Teacup Charm", texture = tex("mcl_core_emerald.png", "#ffddff"), effect = "tiny_mode" },
	mermaid_pearl = { description = "Mermaid Pearl", texture = tex("mcl_mobitems_nautilus_shell.png", "#99ffff"), effect = "mermaid_bubble" },
}

for name, def in pairs(charms) do
	evolve.magic.register_charm(name, {
		description = def.description,
		inventory_image = def.texture,
		effect = def.effect,
	})
end

evolve.magic.register_charm("star_popper", {
	description = "Star Popper",
	inventory_image = tex("mcl_fireworks_rocket.png", "#fff4aa"),
	on_use = function(_, player)
		local ok, remaining = evolve.magic.can_use(player, "star_popper")
		if not ok then core.chat_send_player(player:get_player_name(), "Stars are resting for " .. remaining .. "s."); return false end
		evolve.magic.spawn_stars(vector.offset(player:get_pos(), 0, 1.5, 0), 45)
		evolve.magic.set_cooldown(player, "star_popper", 2)
		return true
	end,
})

evolve.magic.register_charm("cloud_wand", {
	description = "Cloud Wand",
	inventory_image = tex("default_snow.png", "#ffffff"),
	on_use = function(_, player)
		local ok, remaining = evolve.magic.can_use(player, "cloud_wand")
		if not ok then core.chat_send_player(player:get_player_name(), "Clouds are resting for " .. remaining .. "s."); return false end
		local dir = player:get_look_dir()
		local base = vector.add(player:get_pos(), vector.multiply(dir, 3))
		for x = -1, 1 do
			for z = -1, 1 do
				evolve.magic.add_temporary_cloud(player, vector.offset(base, x, -0.5, z), 10)
			end
		end
		evolve.magic.spawn_sparkles(base, 12)
		evolve.magic.set_cooldown(player, "cloud_wand", 3)
		return true
	end,
})

evolve.magic.register_charm("animal_bell", {
	description = "Animal Bell",
	inventory_image = tex("mcl_bells_bell.png", "#ffeeaa"),
	on_use = function(_, player)
		local ok, remaining = evolve.magic.can_use(player, "animal_bell")
		if not ok then core.chat_send_player(player:get_player_name(), "Animal friends are resting for " .. remaining .. "s."); return false end
		evolve.magic.summon_companion(player, 180)
		evolve.magic.spawn_sparkles(player:get_pos(), 16)
		evolve.magic.set_cooldown(player, "animal_bell", 20)
		return true
	end,
})

evolve.magic.register_charm("treasure_twinkle", {
	description = "Treasure Twinkle",
	inventory_image = tex("mcl_core_gold_nugget.png", "#ffffaa"),
	on_use = function(_, player)
		local ok, remaining = evolve.magic.can_use(player, "treasure_twinkle")
		if not ok then core.chat_send_player(player:get_player_name(), "Treasure twinkles are resting for " .. remaining .. "s."); return false end
		evolve.magic.twinkle_to_treasure(player)
		evolve.magic.set_cooldown(player, "treasure_twinkle", 10)
		return true
	end,
})

evolve.magic.register_charm("wishing_star", {
	description = "Wishing Star",
	inventory_image = tex("mcl_mobitems_nether_star.png", "#ffffaa"),
	on_use = function(_, player)
		local ok, remaining = evolve.magic.can_use(player, "wishing_star")
		if not ok then core.chat_send_player(player:get_player_name(), "Wishes are resting for " .. remaining .. "s."); return false end
		local choices = { "fairy_wings", "rainbow_trail", "bubble_bounce", "twinkle_light" }
		local effect = choices[math.random(1, #choices)]
		evolve.magic.give_effect(player, effect, math.min(15, (evolve.magic.registered_effects[effect] or {}).duration or 10), {})
		evolve.magic.spawn_stars(player:get_pos(), 20)
		core.chat_send_player(player:get_player_name(), "Your wish became " .. ((evolve.magic.registered_effects[effect] or {}).description or effect) .. "!")
		evolve.magic.set_cooldown(player, "wishing_star", 10)
		return true
	end,
})

local default_collectibles = {
	["mcl_mobitems:feather"] = "fairy_wings",
	["mcl_dyes:magenta"] = "rainbow_ribbon",
	["mcl_flowers:poppy"] = "blossom_wand",
	["mcl_amethyst:amethyst_shard"] = "twinkle_lantern",
	["mcl_mobitems:slimeball"] = "bubble_boots",
	["mcl_core:emerald"] = "tiny_charm",
	["mcl_mobitems:nautilus_shell"] = "mermaid_pearl",
	["mcl_fireworks:rocket_1"] = "star_popper",
	["mcl_core:snow"] = "cloud_wand",
	["mcl_mobitems:rabbit_foot"] = "animal_bell",
	["mcl_core:gold_nugget"] = "treasure_twinkle",
	["mcl_core:diamond"] = "wishing_star",
}

local function register_default_collectibles()
	for item_name, charm_name in pairs(default_collectibles) do
		evolve.magic.register_collectible_item(item_name, charm_name)
	end
	for mapping in evolve.magic.settings.collectible_items:gmatch("[^,%s]+") do
		local item_name, charm_name = mapping:match("^([^=]+)=([^=]+)$")
		if item_name and charm_name then
			evolve.magic.register_collectible_item(item_name, charm_name)
		end
	end
end

register_default_collectibles()

local function collectible_item_list()
	local items = {}
	for item_name in pairs(evolve.magic.collectible_items) do
		if core.registered_items[item_name] then
			table.insert(items, item_name)
		end
	end
	table.sort(items)
	return items
end

local function ground_drop_pos(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local ground = vector.new(x, y, z)
		local def = core.registered_nodes[core.get_node(ground).name]
		local feet = core.get_node(vector.offset(ground, 0, 1, 0)).name
		local head = core.get_node(vector.offset(ground, 0, 2, 0)).name
		if def and def.walkable and feet == "air" and head == "air" then
			return vector.new(x + 0.5, y + 1.15, z + 0.5)
		end
	end
end

function evolve.magic.scatter_collectibles(name, radius, count)
	local center = evolve.player_pos(name)
	if not center then
		return false, evolve.S("Player not found.")
	end
	radius = evolve.clamp_number(radius, 4, evolve.settings.max_charm_scatter_radius)
	count = evolve.clamp_number(count, 1, evolve.settings.max_charm_scatter_count)
	if not radius or not count then
		return false, evolve.S("Usage: /ev charm_scatter <radius> <count>")
	end

	local items = collectible_item_list()
	if #items == 0 then
		return false, evolve.S("No registered Wonder Charm collectible items are available.")
	end

	local minp = vector.offset(center, -radius, -96, -radius)
	local maxp = vector.offset(center, radius, 96, radius)
	core.load_area(minp, maxp)

	local pr = PcgRandom(core.hash_node_position(center) + count * 7919 + radius * 313)
	local placed = 0
	local attempts = math.max(count * 12, 64)
	for _ = 1, attempts do
		if placed >= count then
			break
		end
		local angle = pr:next(0, 62831) / 10000
		local dist = math.sqrt(pr:next(0, 10000) / 10000) * radius
		local x = math.floor(center.x + math.cos(angle) * dist + 0.5)
		local z = math.floor(center.z + math.sin(angle) * dist + 0.5)
		local pos = ground_drop_pos(x, z, center.y - 96, center.y + 96)
		if pos then
			local item_name = items[pr:next(1, #items)]
			local obj = core.add_item(pos, ItemStack(item_name))
			if obj then
				obj:set_velocity(vector.new(pr:next(-20, 20) / 100, 0.15, pr:next(-20, 20) / 100))
				placed = placed + 1
			end
		end
	end

	evolve.log_action(name, "charm_scatter", minp, maxp, ("radius=%d requested=%d placed=%d"):format(radius, count, placed))
	return true, evolve.S("Scattered @1 Wonder Charm collectibles.", placed)
end

local function handle_collectible_pickup(itemstack, picker)
	if not evolve.magic.settings.collectibles or not picker or not picker:is_player() then
		return nil
	end
	itemstack = ItemStack(itemstack)
	local item_name = itemstack:get_name()
	local charm_name = evolve.magic.collectible_items[item_name]
	if not charm_name then
		return nil
	end
	if not evolve.magic.activate_charm(picker, charm_name) then
		return nil
	end
	evolve.magic.spawn_sparkles(picker:get_pos(), 8)
	core.chat_send_player(picker:get_player_name(), "Collected magic: " .. (evolve.magic.charms[charm_name].description or charm_name))
	if not evolve.magic.settings.consume_collectibles then
		return nil
	end
	local remainder = ItemStack(itemstack)
	remainder:take_item(1)
	return remainder
end

local old_item_pickup = core.item_pickup
function core.item_pickup(itemstack, picker, pointed_thing, ...)
	local result = handle_collectible_pickup(itemstack, picker)
	if result then
		return result
	end
	return old_item_pickup(itemstack, picker, pointed_thing, ...)
end

core.register_chatcommand("evolve_magic_give", {
	params = "<player> <charm>",
	privs = { evolve_magic_admin = true },
	func = function(_, param)
		local args = evolve.parse_args(param)
		local player = core.get_player_by_name(args[1] or "")
		local item = args[2] and ("evolve:" .. args[2])
		if not player or not item or not core.registered_items[item] then
			return false, "Usage: /evolve_magic_give <player> <charm>"
		end
		player:get_inventory():add_item("main", item)
		return true, "Gave " .. item .. "."
	end,
})

core.register_chatcommand("evolve_magic_collectibles", {
	privs = { evolve_magic_admin = true },
	func = function()
		local rows = {}
		for item_name, charm_name in pairs(evolve.magic.collectible_items) do
			table.insert(rows, item_name .. "=" .. charm_name)
		end
		table.sort(rows)
		return true, #rows > 0 and table.concat(rows, ", ") or "No collectible charm items are registered."
	end,
})

core.register_chatcommand("evolve_magic_give_collectible", {
	params = "<player> <charm> [count]",
	privs = { evolve_magic_admin = true },
	func = function(_, param)
		local args = evolve.parse_args(param)
		local player = core.get_player_by_name(args[1] or "")
		local charm_name = args[2]
		local count = evolve.clamp_number(args[3] or 1, 1, 99) or 1
		if not player or not charm_name then
			return false, "Usage: /evolve_magic_give_collectible <player> <charm> [count]"
		end
		for item_name, mapped_charm in pairs(evolve.magic.collectible_items) do
			if mapped_charm == charm_name then
				player:get_inventory():add_item("main", item_name .. " " .. count)
				return true, "Gave " .. item_name .. " for " .. charm_name .. "."
			end
		end
		return false, "No collectible item is mapped to " .. charm_name .. "."
	end,
})

core.register_chatcommand("evolve_magic_clear", {
	params = "<player>",
	privs = { evolve_magic_admin = true },
	func = function(_, param)
		local player = core.get_player_by_name(param)
		if not player then return false, "Player not found." end
		evolve.magic.clear_all_effects(player)
		return true, "Cleared magic."
	end,
})

core.register_chatcommand("evolve_magic_resetme", {
	func = function(name)
		local player = core.get_player_by_name(name)
		if player then evolve.magic.clear_all_effects(player) end
		return true, "Magic reset."
	end,
})

core.register_chatcommand("evolve_add_treasure", {
	params = "<name>",
	privs = { evolve_magic_admin = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player or param == "" then return false, "Usage: /evolve_add_treasure <name>" end
		evolve.magic.add_treasure_point(player:get_pos(), param)
		return true, "Added treasure point."
	end,
})

core.register_chatcommand("evolve_remove_nearest_treasure", {
	privs = { evolve_magic_admin = true },
	func = function(name)
		local player = core.get_player_by_name(name)
		local removed = player and evolve.magic.remove_nearest_treasure(player:get_pos())
		return removed ~= nil, removed and ("Removed " .. removed.name) or "No treasure points."
	end,
})

core.register_chatcommand("evolve_list_treasure", {
	privs = { evolve_magic_admin = true },
	func = function()
		local names = {}
		for _, point in ipairs(evolve.magic.treasure_points) do
			table.insert(names, point.name)
		end
		return true, #names > 0 and table.concat(names, ", ") or "No treasure points."
	end,
})
