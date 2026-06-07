local S = evolve.S

local function first_registered(names, fallback)
	for _, name in ipairs(names) do
		if core.registered_nodes[name] or core.registered_items[name] then
			return name
		end
	end
	return fallback
end

local nodes = {
	chest = first_registered({ "mcl_chests:chest" }, "mcl_chests:chest"),
	torch = first_registered({ "mcl_torches:torch" }, nil),
	stone = first_registered({ "mcl_core:stonebrick", "mcl_core:stone", "mcl_core:cobble" }, "mcl_core:stone"),
	mossy = first_registered({ "mcl_core:mossycobble", "mcl_core:mossystonebrick", "mcl_core:cobble" }, "mcl_core:cobble"),
	planks = first_registered({ "mcl_trees:wood_oak", "mcl_core:wood" }, "mcl_trees:wood_oak"),
	gold = first_registered({ "mcl_core:goldblock", "mcl_core:gold_block" }, nil),
	emerald = first_registered({ "mcl_core:emeraldblock", "mcl_core:emerald_block" }, nil),
	leaves = first_registered({ "mcl_trees:leaves_oak", "mcl_core:leaves" }, nil),
	grass = first_registered({ "mcl_core:dirt_with_grass", "mcl_core:dirt" }, "mcl_core:dirt"),
}

local loot = {
	[1] = {
		{
			stacks_min = 2,
			stacks_max = 4,
			items = {
				{ itemstring = "mcl_core:apple", amount_min = 2, amount_max = 6, weight = 3 },
				{ itemstring = "mcl_farming:bread", amount_min = 1, amount_max = 3, weight = 3 },
				{ itemstring = "mcl_core:stick", amount_min = 4, amount_max = 16, weight = 2 },
				{ itemstring = "mcl_trees:wood_oak", amount_min = 4, amount_max = 12, weight = 2 },
			},
		},
	},
	[2] = {
		{
			stacks_min = 3,
			stacks_max = 6,
			items = {
				{ itemstring = "mcl_core:iron_ingot", amount_min = 1, amount_max = 5, weight = 3 },
				{ itemstring = "mcl_core:gold_ingot", amount_min = 1, amount_max = 4, weight = 2 },
				{ itemstring = "mcl_tools:pick_iron", weight = 1 },
				{ itemstring = "mcl_torches:torch", amount_min = 8, amount_max = 24, weight = 3 },
				{ itemstring = "mcl_farming:bread", amount_min = 2, amount_max = 6, weight = 3 },
			},
		},
	},
	[3] = {
		{
			stacks_min = 4,
			stacks_max = 8,
			items = {
				{ itemstring = "mcl_core:diamond", amount_min = 1, amount_max = 3, weight = 1 },
				{ itemstring = "mcl_core:emerald", amount_min = 2, amount_max = 8, weight = 2 },
				{ itemstring = "mcl_core:gold_ingot", amount_min = 3, amount_max = 10, weight = 3 },
				{ itemstring = "mcl_tools:sword_diamond", weight = 1 },
				{ itemstring = "mcl_armor:chestplate_iron", weight = 1 },
			},
		},
	},
}

local function registered_item(itemstring)
	local name = ItemStack(itemstring):get_name()
	return name ~= "" and core.registered_items[name] ~= nil
end

local function sanitize_loot(defs)
	local clean = {}
	for _, group in ipairs(defs) do
		local items = {}
		for _, item in ipairs(group.items) do
			if item.nothing or registered_item(item.itemstring or "") then
				table.insert(items, item)
			end
		end
		if #items > 0 then
			table.insert(clean, {
				stacks_min = group.stacks_min,
				stacks_max = group.stacks_max,
				items = items,
			})
		end
	end
	return clean
end

local function is_clear(pos)
	local node = core.get_node_or_nil(pos)
	if not node then
		return false
	end
	local def = core.registered_nodes[node.name]
	return node.name == "air" or (def and def.buildable_to and not def.walkable)
end

local function is_safe_ground(pos)
	local node = core.get_node_or_nil(pos)
	if not node then
		return false
	end
	local def = core.registered_nodes[node.name]
	if not def or not def.walkable then
		return false
	end
	if def.liquidtype and def.liquidtype ~= "none" then
		return false
	end
	return true
end

local function surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local ground = vector.new(x, y, z)
		if is_safe_ground(ground) and is_clear(vector.offset(ground, 0, 1, 0)) and is_clear(vector.offset(ground, 0, 2, 0)) then
			return y
		end
	end
	return nil
end

local function can_modify(name, minp, maxp)
	for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
			for z = minp.z, maxp.z do
				if core.is_protected(vector.new(x, y, z), name) then
					return false
				end
			end
		end
	end
	return true
end

local function place_if_clear(pos, node_name)
	if not node_name or not core.registered_nodes[node_name] or not is_clear(pos) then
		return false
	end
	core.place_node(pos, { name = node_name })
	return true
end

local function set_if_clear(pos, node_name)
	if not node_name or not core.registered_nodes[node_name] or not is_clear(pos) then
		return false
	end
	core.set_node(pos, { name = node_name })
	return true
end

local function add_torches(pos)
	if not nodes.torch then
		return
	end
	local offsets = {
		vector.new(1, 0, 0),
		vector.new(-1, 0, 0),
		vector.new(0, 0, 1),
		vector.new(0, 0, -1),
	}
	for _, offset in ipairs(offsets) do
		place_if_clear(vector.add(pos, offset), nodes.torch)
	end
end

local function place_chest(pos, tier)
	core.place_node(pos, { name = nodes.chest })
	return evolve.fill_treasure_chest(pos, tier)
end

local function place_surface_cache(pos, tier)
	local item_count = place_chest(pos, tier)
	add_torches(pos)
	return item_count
end

local function place_buried_cache(pos, tier)
	local item_count = place_chest(pos, tier)
	for dx = -1, 1 do
			for dz = -1, 1 do
				if math.abs(dx) + math.abs(dz) == 1 then
					core.set_node(vector.offset(pos, dx, -1, dz), { name = nodes.grass })
				end
			end
		end
	if nodes.torch then
		place_if_clear(vector.offset(pos, 0, 0, 1), nodes.torch)
	end
	return item_count
end

local function place_stone_shrine(pos, tier)
	local item_count = place_chest(pos, tier)
	for dx = -1, 1 do
		for dz = -1, 1 do
			if math.abs(dx) == 1 or math.abs(dz) == 1 then
				set_if_clear(vector.offset(pos, dx, -1, dz), nodes.mossy)
			end
		end
	end
	set_if_clear(vector.offset(pos, -1, 0, -1), nodes.stone)
	set_if_clear(vector.offset(pos, 1, 0, -1), nodes.stone)
	set_if_clear(vector.offset(pos, -1, 0, 1), nodes.stone)
	set_if_clear(vector.offset(pos, 1, 0, 1), nodes.stone)
	add_torches(pos)
	return item_count
end

local function place_woodland_cache(pos, tier)
	local item_count = place_chest(pos, tier)
	for dx = -1, 1 do
		for dz = -1, 1 do
			if math.abs(dx) + math.abs(dz) == 1 then
				set_if_clear(vector.offset(pos, dx, -1, dz), nodes.planks)
			elseif nodes.leaves and math.abs(dx) == 1 and math.abs(dz) == 1 then
				set_if_clear(vector.offset(pos, dx, 0, dz), nodes.leaves)
			end
		end
	end
	return item_count
end

local function place_gem_pedestal(pos, tier)
	local pedestal = nodes.emerald or nodes.gold or nodes.stone
	core.set_node(vector.offset(pos, 0, -1, 0), { name = pedestal })
	local item_count = place_chest(pos, tier)
	if nodes.torch then
		place_if_clear(vector.offset(pos, -1, 0, 0), nodes.torch)
		place_if_clear(vector.offset(pos, 1, 0, 0), nodes.torch)
	end
	return item_count
end

local treasure_styles = {
	{ name = "surface cache", radius = 1, below = 1, above = 2, place = place_surface_cache },
	{ name = "buried cache", radius = 1, below = 2, above = 2, place = place_buried_cache },
	{ name = "stone shrine", radius = 2, below = 1, above = 2, place = place_stone_shrine },
	{ name = "woodland cache", radius = 2, below = 1, above = 2, place = place_woodland_cache },
	{ name = "gem pedestal", radius = 1, below = 1, above = 2, place = place_gem_pedestal },
}

local function style_region(pos, style)
	return {
		minp = vector.offset(pos, -style.radius, -style.below, -style.radius),
		maxp = vector.offset(pos, style.radius, style.above, style.radius),
	}
end

local function region_clear_for_style(pos, style)
	for x = pos.x - style.radius, pos.x + style.radius do
		for y = pos.y, pos.y + style.above do
			for z = pos.z - style.radius, pos.z + style.radius do
				if not is_clear(vector.new(x, y, z)) then
					return false
				end
			end
		end
	end
	return true
end

function evolve.fill_treasure_chest(pos, tier)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	local pr = PcgRandom(core.hash_node_position(pos) + os.time())
	local items = mcl_loot.get_multi_loot(sanitize_loot(loot[tier] or loot[1]), pr)
	mcl_loot.fill_inventory(inv, "main", items, pr)
	return #items
end

function evolve.place_treasure(name, tier)
	tier = evolve.clamp_number(tier or 1, 1, math.min(3, evolve.settings.max_treasure_tier))
	if not tier then
		return false, S("Invalid treasure tier.")
	end

	local pos = evolve.player_pos(name)
	if not pos then
		return false, S("Player not found.")
	end
	pos = vector.offset(pos, 0, -1, 0)
	local minp = vector.offset(pos, -1, -1, -1)
	local maxp = vector.offset(pos, 1, 2, 1)

	local ok, err = evolve.capture(name, minp, maxp, "treasure")
	if not ok then
		return false, err
	end

	core.place_node(pos, { name = "mcl_chests:chest" })
	local item_count = evolve.fill_treasure_chest(pos, tier)

	local torch = core.registered_nodes["mcl_torches:torch"] and "mcl_torches:torch" or nil
	if torch then
		local adj = {
			vector.new(1, 0, 0),
			vector.new(-1, 0, 0),
			vector.new(0, 0, 1),
			vector.new(0, 0, -1),
		}
		for _, offset in ipairs(adj) do
			local tpos = vector.add(pos, offset)
			local def = core.registered_nodes[core.get_node(tpos).name]
			if def and def.buildable_to then
				core.place_node(tpos, { name = torch })
			end
		end
	end

	evolve.log_action(name, "treasure", minp, maxp, ("tier=%d items=%d"):format(tier, item_count))
	return true, S("Placed tier @1 treasure.", tier)
end

function evolve.scatter_treasure(name, radius, amount, tier)
	radius = evolve.clamp_number(radius, 1, evolve.settings.max_treasure_radius)
	if not radius then
		return false, S("Invalid treasure radius.")
	end
	amount = evolve.clamp_number(amount, 1, evolve.settings.max_treasure_count)
	if not amount then
		return false, S("Invalid treasure amount.")
	end

	local max_tier = math.min(3, evolve.settings.max_treasure_tier)
	if tier and tier ~= "" and tier ~= "random" then
		tier = evolve.clamp_number(tier, 1, max_tier)
		if not tier then
			return false, S("Invalid treasure tier.")
		end
	else
		tier = nil
	end

	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end

	local pr = PcgRandom(os.time() + core.hash_node_position(center))
	local candidates = {}
	local attempts = math.max(amount * 24, 80)
	for _ = 1, attempts do
		local angle = pr:next(0, 62831) / 10000
		local distance = math.sqrt(pr:next(0, 1000000) / 1000000) * radius
		local x = math.floor(center.x + math.cos(angle) * distance + 0.5)
		local z = math.floor(center.z + math.sin(angle) * distance + 0.5)
		local y = surface_y(x, z, center.y - 96, center.y + 96)
		if y then
			local pos = vector.new(x, y + 1, z)
			local score = pr:next(1, 1000000)
			table.insert(candidates, { pos = pos, score = score })
		end
	end

	table.sort(candidates, function(a, b)
		return a.score < b.score
	end)

	local plan = {}
	local occupied = {}
	for _, candidate in ipairs(candidates) do
		if #plan >= amount then
			break
		end
		local style = treasure_styles[pr:next(1, #treasure_styles)]
		local chosen_tier = tier or pr:next(1, max_tier)
		local pos = candidate.pos
		local key = pos.x .. "," .. pos.z
		local too_close = false
		for other_key in pairs(occupied) do
			local ox, oz = other_key:match("^(-?%d+),(-?%d+)$")
			ox, oz = tonumber(ox), tonumber(oz)
			if ox and oz and math.abs(pos.x - ox) <= 5 and math.abs(pos.z - oz) <= 5 then
				too_close = true
				break
			end
		end
		if not too_close and region_clear_for_style(pos, style) then
			local region = style_region(pos, style)
			if can_modify(name, region.minp, region.maxp) then
				table.insert(plan, {
					pos = pos,
					style = style,
					tier = chosen_tier,
					region = region,
				})
				occupied[key] = true
			end
		end
	end

	if #plan == 0 then
		return false, S("No safe ground found for treasure.")
	end

	local regions = {}
	for _, entry in ipairs(plan) do
		table.insert(regions, entry.region)
	end
	local ok, err = evolve.capture_regions(name, regions, "random treasure")
	if not ok then
		return false, err
	end

	local placed = 0
	local items = 0
	local style_counts = {}
	for _, entry in ipairs(plan) do
		items = items + entry.style.place(entry.pos, entry.tier)
		placed = placed + 1
		style_counts[entry.style.name] = (style_counts[entry.style.name] or 0) + 1
	end

	local minp = vector.offset(center, -radius, -96, -radius)
	local maxp = vector.offset(center, radius, 96, radius)
	local detail = {}
	for style_name, count in pairs(style_counts) do
		table.insert(detail, ("%s=%d"):format(style_name, count))
	end
	table.sort(detail)
	evolve.log_action(name, "treasure_scatter", minp, maxp,
		("radius=%d requested=%d placed=%d items=%d %s"):format(radius, amount, placed, items, table.concat(detail, " ")))

	if placed < amount then
		return true, S("Placed @1 of @2 random treasures; some locations were not safe.", placed, amount)
	end
	return true, S("Placed @1 random treasures.", placed)
end
