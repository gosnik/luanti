local S = evolve.S

local function first_registered(candidates, fallback)
	for _, name in ipairs(candidates) do
		if core.registered_nodes[name] then
			return name
		end
	end
	return fallback or "air"
end

local N = {}

local function refresh_nodes()
	N.air = "air"
	N.stone = first_registered({ "mcl_core:stone", "mcl_core:cobble" }, "mcl_core:dirt")
	N.grass = first_registered({ "mcl_core:dirt_with_grass", "mcl_core:grass_path" }, "mcl_core:dirt")
	N.dirt = first_registered({ "mcl_core:dirt" }, N.grass)
	N.cobble = first_registered({ "mcl_core:cobble", "mcl_core:stone" }, N.stone)
	N.brick = first_registered({ "mcl_core:stonebrick", "mcl_core:cobble", "mcl_core:stone" }, N.stone)
	N.floor = first_registered({ "mcl_core:quartzblock", "mcl_core:stonebrick", "mcl_core:stone" }, N.brick)
	N.gold = first_registered({ "mcl_core:goldblock", "mcl_core:stone_with_gold" }, N.floor)
	N.water = first_registered({ "mcl_core:water_source" }, N.air)
	N.bridge = first_registered({ "mcl_trees:wood_oak", "mcl_core:cobble" }, N.cobble)
	N.hedge = first_registered({ "mcl_trees:leaves_oak", "mcl_trees:leaves_dark_oak", "mcl_wool:green" }, N.cobble)
	N.red = first_registered({ "mcl_wool:red", "mcl_wool:magenta", "mcl_core:goldblock" }, N.gold)
	N.blue = first_registered({ "mcl_wool:blue", "mcl_wool:light_blue", "mcl_core:glass_blue" }, N.floor)
	N.glass_red = first_registered({ "mcl_core:glass_red", "mcl_core:glass_magenta", "mcl_core:glass" }, "mcl_core:glass")
	N.glass_blue = first_registered({ "mcl_core:glass_blue", "mcl_core:glass_light_blue", "mcl_core:glass" }, "mcl_core:glass")
	N.glass_yellow = first_registered({ "mcl_core:glass_yellow", "mcl_core:glass_orange", "mcl_core:glass" }, "mcl_core:glass")
	N.torch = first_registered({ "mcl_torches:torch" }, nil)
	N.chest = first_registered({ "mcl_chests:chest" }, N.cobble)
	N.flower_a = first_registered({ "mcl_flowers:poppy", "mcl_flowers:tulip_red", "mcl_flowers:dandelion" }, nil)
	N.flower_b = first_registered({ "mcl_flowers:blue_orchid", "mcl_flowers:cornflower", "mcl_flowers:allium" }, N.flower_a)
	N.flower_c = first_registered({ "mcl_flowers:dandelion", "mcl_flowers:tulip_orange", "mcl_flowers:pink_petals_1" }, N.flower_b)
end

local sizes = {
	small = { r = 15, wall = 8, tower = 19 },
	medium = { r = 20, wall = 10, tower = 25 },
	large = { r = 25, wall = 12, tower = 31 },
}

local function set(pos, node, param2)
	if node and core.registered_nodes[node] then
		core.set_node(pos, { name = node, param2 = param2 or 0 })
	end
end

local function fill_box(minp, maxp, node)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				set(vector.new(x, y, z), node)
			end
		end
	end
end

local function hollow_box(minp, maxp, wall_node, air_node)
	fill_box(minp, maxp, wall_node)
	fill_box(vector.offset(minp, 1, 1, 1), vector.offset(maxp, -1, -1, -1), air_node or N.air)
end

local function hash_noise(x, z, seed)
	local h = (x * 734287 + z * 912931 + seed * 19349663) % 100000
	return h / 100000
end

local function hull_radius_at(angle, cfg, seed)
	local wobble = math.sin(angle * 3 + seed * 0.013) * 0.10
		+ math.sin(angle * 5 - seed * 0.021) * 0.07
		+ math.sin(angle * 8 + seed * 0.005) * 0.045
	return cfg.r * (1 + wobble)
end

local function hull_value(x, z, cfg, seed)
	local angle = math.atan2(z, x)
	local r = hull_radius_at(angle, cfg, seed)
	local stretch = 1 + 0.08 * math.sin(angle * 2 + seed)
	return math.sqrt((x * x) + (z * z) * stretch) - r
end

local function inside_hull(x, z, cfg, seed)
	return hull_value(x, z, cfg, seed) <= 0
end

local function near_hull(x, z, cfg, seed, band)
	local value = hull_value(x, z, cfg, seed)
	return value > 0 and value <= band
end

local function hull_boundary(x, z, cfg, seed)
	if not inside_hull(x, z, cfg, seed) then
		return false
	end
	return not inside_hull(x + 1, z, cfg, seed)
		or not inside_hull(x - 1, z, cfg, seed)
		or not inside_hull(x, z + 1, cfg, seed)
		or not inside_hull(x, z - 1, cfg, seed)
end

local function terraform_site(center, cfg, seed)
	local range = cfg.r + 14
	for z = -range, range do
		for x = -range, range do
			local dist = math.sqrt(x * x + z * z)
			if dist <= range then
				local blend = 1 - math.min(dist / range, 1)
				local natural = math.floor((hash_noise(center.x + x, center.z + z, seed) - 0.5) * 4)
				local target_y = center.y - 1 + math.floor(blend * 3) + natural
				if inside_hull(x, z, cfg, seed) or near_hull(x, z, cfg, seed, 4) then
					target_y = center.y - 1
				end
				for y = center.y - 10, target_y - 4 do
					set(vector.offset(center, x, y - center.y, z), N.stone)
				end
				for y = target_y - 3, target_y - 1 do
					set(vector.new(center.x + x, y, center.z + z), N.dirt)
				end
				set(vector.new(center.x + x, target_y, center.z + z), N.grass)
				for y = target_y + 1, center.y + 10 do
					set(vector.new(center.x + x, y, center.z + z), N.air)
				end
			end
		end
	end
end

local function tower(center, radius, height)
	for y = 0, height do
		for z = -radius, radius do
			for x = -radius, radius do
				local edge = math.abs(x) == radius or math.abs(z) == radius
				local inside = math.abs(x) < radius and math.abs(z) < radius
				local p = vector.offset(center, x, y, z)
				if edge then
					set(p, N.brick)
				elseif inside then
					set(p, N.air)
				end
			end
		end
	end

	for z = -radius - 1, radius + 1 do
		for x = -radius - 1, radius + 1 do
			if math.abs(x) == radius + 1 or math.abs(z) == radius + 1 or (x + z) % 2 == 0 then
				set(vector.offset(center, x, height + 1, z), N.brick)
			end
		end
	end

	set(vector.offset(center, 0, math.floor(height / 2), -radius), N.glass_blue)
	set(vector.offset(center, 0, math.floor(height / 2) + 1, -radius), N.glass_yellow)
	set(vector.offset(center, radius, math.floor(height / 2), 0), N.glass_red)
	set(vector.offset(center, radius, math.floor(height / 2) + 1, 0), N.glass_blue)
	if N.torch then
		set(vector.offset(center, 0, 1, 0), N.torch)
	end
end

local function walls(center, cfg, seed)
	for z = -cfg.r - 4, cfg.r + 4 do
		for x = -cfg.r - 4, cfg.r + 4 do
			if hull_boundary(x, z, cfg, seed) then
				for y = 0, cfg.wall do
					set(vector.offset(center, x, y, z), N.brick)
				end
				if (x + z + seed) % 3 ~= 0 then
					set(vector.offset(center, x, cfg.wall + 1, z), N.brick)
				end
			elseif inside_hull(x, z, cfg, seed) then
				set(vector.offset(center, x, -1, z), N.floor)
			end
		end
	end

	fill_box(vector.offset(center, -2, 0, -cfg.r), vector.offset(center, 2, 4, -cfg.r + 2), N.air)
end

local function main_keep(center)
	local minp = vector.offset(center, -7, 0, -4)
	local maxp = vector.offset(center, 7, 11, 8)
	hollow_box(minp, maxp, N.brick, N.air)
	fill_box(vector.offset(center, -6, 0, -3), vector.offset(center, 6, 0, 7), N.floor)
	fill_box(vector.offset(center, -6, 6, -3), vector.offset(center, 6, 6, 7), N.floor)

	for y = 3, 8, 3 do
		set(vector.offset(center, -7, y, 1), N.glass_red)
		set(vector.offset(center, -7, y + 1, 1), N.glass_blue)
		set(vector.offset(center, 7, y, 1), N.glass_yellow)
		set(vector.offset(center, 7, y + 1, 1), N.glass_blue)
		set(vector.offset(center, 0, y, 8), N.glass_red)
		set(vector.offset(center, 0, y + 1, 8), N.glass_yellow)
	end

	fill_box(vector.offset(center, -2, 1, -4), vector.offset(center, 2, 4, -4), N.air)
end

local function throne_room(center)
	local throne = vector.offset(center, 0, 1, 6)
	fill_box(vector.offset(center, -3, 1, 4), vector.offset(center, 3, 1, 6), N.red)
	set(throne, N.gold)
	set(vector.offset(throne, 0, 1, 0), N.gold)
	set(vector.offset(throne, -1, 0, 0), N.gold)
	set(vector.offset(throne, 1, 0, 0), N.gold)
	if N.torch then
		set(vector.offset(center, -4, 2, 5), N.torch)
		set(vector.offset(center, 4, 2, 5), N.torch)
	end
end

local function ballroom(center)
	for z = -2, 2 do
		for x = -5, 5 do
			local node = ((x + z) % 2 == 0) and N.blue or N.floor
			set(vector.offset(center, x, 7, z), node)
		end
	end
	for x = -5, 5, 5 do
		set(vector.offset(center, x, 8, -2), N.glass_yellow)
		set(vector.offset(center, x, 9, -2), N.glass_red)
	end
end

local function moat_and_bridge(center, cfg, seed)
	for z = -cfg.r - 8, cfg.r + 8 do
		for x = -cfg.r - 8, cfg.r + 8 do
			if near_hull(x, z, cfg, seed, 5) then
				set(vector.offset(center, x, -1, z), N.water)
				set(vector.offset(center, x, 0, z), N.air)
			end
		end
	end

	fill_box(vector.offset(center, -3, -1, -cfg.r - 8), vector.offset(center, 3, 0, -cfg.r + 2), N.bridge)
	for z = -cfg.r - 8, -cfg.r + 2 do
		set(vector.offset(center, -3, 1, z), N.hedge)
		set(vector.offset(center, 3, 1, z), N.hedge)
	end
end

local function gardens(center, r)
	local spots = {
		vector.offset(center, -r + 5, 0, -r + 5),
		vector.offset(center, r - 5, 0, -r + 5),
		vector.offset(center, -r + 5, 0, r - 5),
		vector.offset(center, r - 5, 0, r - 5),
	}
	for _, spot in ipairs(spots) do
		fill_box(vector.offset(spot, -3, 0, -3), vector.offset(spot, 3, 0, 3), first_registered({ "mcl_core:dirt_with_grass" }, N.floor))
		for z = -3, 3 do
			for x = -3, 3 do
				if math.abs(x) == 3 or math.abs(z) == 3 then
					set(vector.offset(spot, x, 1, z), N.hedge)
				elseif (x * 11 + z * 7) % 3 == 0 then
					local flower = ({ N.flower_a, N.flower_b, N.flower_c })[((x + z) % 3) + 1]
					set(vector.offset(spot, x, 1, z), flower)
				end
			end
		end
	end
end

local function secret_passages(center, r)
	fill_box(vector.offset(center, -1, -4, 3), vector.offset(center, 1, -2, r + 6), N.air)
	fill_box(vector.offset(center, -2, -5, r + 3), vector.offset(center, 2, -2, r + 7), N.brick)
	fill_box(vector.offset(center, -1, -4, r + 4), vector.offset(center, 1, -3, r + 6), N.air)
	local chest_pos = vector.offset(center, 0, -4, r + 5)
	core.place_node(chest_pos, { name = N.chest })
	evolve.fill_treasure_chest(chest_pos, 3)
	if N.torch then
		set(vector.offset(center, 0, -3, 5), N.torch)
		set(vector.offset(center, 0, -3, r + 4), N.torch)
	end
end

function evolve.fairy_tale_castle(name, size)
	local player_pos = evolve.player_pos(name)
	if not player_pos then
		return false, S("Player not found.")
	end

	size = sizes[size] and size or "medium"
	local cfg = sizes[size]
	refresh_nodes()

	local dir = evolve.facing_dir(name)
	local center = vector.add(player_pos, vector.multiply(dir, cfg.r + 8))
	center.y = player_pos.y - 1
	local seed = core.hash_node_position(center)

	local minp = vector.offset(center, -cfg.r - 14, -10, -cfg.r - 14)
	local maxp = vector.offset(center, cfg.r + 14, cfg.tower + 4, cfg.r + 14)
	local ok, err = evolve.capture(name, minp, maxp, "fairy-tale castle")
	if not ok then
		return false, err
	end

	terraform_site(center, cfg, seed)
	moat_and_bridge(center, cfg, seed)
	walls(center, cfg, seed)

	for _, offset in ipairs({
		vector.new(-cfg.r - 1, 0, -cfg.r + 2),
		vector.new(cfg.r - 2, 0, -cfg.r - 1),
		vector.new(-cfg.r + 3, 0, cfg.r),
		vector.new(cfg.r + 1, 0, cfg.r - 3),
	}) do
		tower(vector.add(center, offset), 2, cfg.tower)
	end

	main_keep(center)
	throne_room(center)
	ballroom(center)
	gardens(center, cfg.r)
	secret_passages(center, cfg.r)

	core.fix_light(minp, maxp)
	evolve.log_action(name, "castle", minp, maxp, ("size=%s"):format(size))
	return true, S("Generated @1 fairy-tale castle.", size)
end
