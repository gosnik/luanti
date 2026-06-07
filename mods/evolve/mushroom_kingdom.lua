local S = evolve.S

local function first_registered(candidates, fallback)
	for _, name in ipairs(candidates) do
		if core.registered_nodes[name] then
			return name
		end
	end
	return fallback
end

local N = {}

local function refresh_nodes()
	N.air = "air"
	N.grass = first_registered({ "mcl_core:dirt_with_grass", "mcl_core:grass_path" }, "mcl_core:dirt")
	N.mycelium = first_registered({ "mcl_core:mycelium" }, N.grass)
	N.dirt = first_registered({ "mcl_core:dirt" }, N.grass)
	N.stone = first_registered({ "mcl_core:stone", "mcl_core:cobble" }, N.dirt)
	N.cobble = first_registered({ "mcl_core:cobble", "mcl_core:stone" }, N.stone)
	N.gold = first_registered({ "mcl_core:goldblock", "mcl_core:stone_with_gold" }, N.cobble)
	N.coin = first_registered({ "mcl_core:goldblock", "mcl_core:stone_with_gold" }, N.gold)
	N.cloud = first_registered({ "mcl_wool:white", "mcl_core:snowblock", "mcl_core:glass" }, "mcl_core:glass")
	N.pipe = first_registered({ "mcl_wool:lime", "mcl_wool:green", "mcl_core:emeraldblock", "mcl_core:slimeblock" }, N.cobble)
	N.pipe_dark = first_registered({ "mcl_wool:green", "mcl_core:emeraldblock", "mcl_core:slimeblock" }, N.pipe)
	N.red_cap = first_registered({ "mcl_mushrooms:red_mushroom_block_cap_111111", "mcl_wool:red" }, N.pipe)
	N.brown_cap = first_registered({ "mcl_mushrooms:brown_mushroom_block_cap_111111", "mcl_trees:wood_oak" }, N.cobble)
	N.stem = first_registered({ "mcl_mushrooms:red_mushroom_block_stem_full", "mcl_mushrooms:brown_mushroom_block_stem_full", "mcl_trees:tree_oak" }, N.cobble)
	N.normal_red = first_registered({ "mcl_mushrooms:mushroom_red" }, nil)
	N.normal_brown = first_registered({ "mcl_mushrooms:mushroom_brown" }, nil)
	N.chest = first_registered({ "mcl_chests:chest" }, N.cobble)
	N.torch = first_registered({ "mcl_torches:torch" }, nil)
	N.ladder = first_registered({ "mcl_ladders:ladder", "mcl_core:ladder" }, nil)
	N.vine = first_registered({ "mcl_core:vine" }, nil)
end

local flowers = {
	"mcl_flowers:poppy",
	"mcl_flowers:dandelion",
	"mcl_flowers:tulip_orange",
	"mcl_flowers:tulip_pink",
	"mcl_flowers:tulip_red",
	"mcl_flowers:allium",
	"mcl_flowers:blue_orchid",
	"mcl_flowers:cornflower",
	"mcl_flowers:wildflowers_1",
	"mcl_flowers:pink_petals_1",
}

local function set(pos, name, param2)
	if name and core.registered_nodes[name] then
		core.set_node(pos, { name = name, param2 = param2 or 0 })
	end
end

local function place_flower(pos, seed)
	local available = {}
	for _, name in ipairs(flowers) do
		if core.registered_nodes[name] then
			table.insert(available, name)
		end
	end
	if #available == 0 then
		return
	end
	local index = (math.abs(seed) % #available) + 1
	set(pos, available[index], seed % 4)
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

local function sphere(center, radius, node)
	local r2 = radius * radius
	for z = center.z - radius, center.z + radius do
		for y = center.y - radius, center.y + radius do
			for x = center.x - radius, center.x + radius do
				local dx = x - center.x
				local dy = y - center.y
				local dz = z - center.z
				if dx * dx + dy * dy + dz * dz <= r2 then
					set(vector.new(x, y, z), node)
				end
			end
		end
	end
end

local function cloud(center)
	sphere(center, 2, N.cloud)
	sphere(vector.offset(center, 3, 0, 0), 2, N.cloud)
	sphere(vector.offset(center, -3, 0, 0), 2, N.cloud)
	sphere(vector.offset(center, 0, 1, 2), 2, N.cloud)
	sphere(vector.offset(center, 0, 1, -2), 1, N.cloud)
end

local function giant_mushroom(base, cap_node, height, cap_radius)
	height = height or 7
	cap_radius = cap_radius or 3
	for y = 0, height do
		set(vector.offset(base, 0, y, 0), N.stem)
	end

	local cap_center = vector.offset(base, 0, height + 1, 0)
	for z = -cap_radius, cap_radius do
		for x = -cap_radius, cap_radius do
			if math.abs(x) + math.abs(z) <= cap_radius * 2 - 1 then
				set(vector.offset(cap_center, x, 0, z), cap_node)
			end
			if x * x + z * z <= cap_radius * cap_radius - 1 then
				set(vector.offset(cap_center, x, 1, z), cap_node)
			end
		end
	end
	set(vector.offset(cap_center, 0, 2, 0), cap_node)
end

local function pipe_entrance(base)
	for y = 0, 2 do
		for z = -1, 1 do
			for x = -1, 1 do
				local edge = math.abs(x) == 1 or math.abs(z) == 1
				set(vector.offset(base, x, y, z), edge and N.pipe_dark or N.air)
			end
		end
	end

	for z = -2, 2 do
		for x = -2, 2 do
			local edge = math.abs(x) == 2 or math.abs(z) == 2
			if edge then
				set(vector.offset(base, x, 3, z), N.pipe)
			else
				set(vector.offset(base, x, 3, z), N.air)
			end
		end
	end
end

local function secret_room(center)
	local room_min = vector.offset(center, -5, -11, -5)
	local room_max = vector.offset(center, 5, -5, 5)

	fill_box(room_min, room_max, N.cobble)
	fill_box(vector.offset(room_min, 1, 1, 1), vector.offset(room_max, -1, -1, -1), N.air)
	fill_box(vector.offset(center, -1, -1, -1), vector.offset(center, 1, -11, 1), N.air)

	if N.ladder then
		for y = center.y - 10, center.y - 1 do
			set(vector.new(center.x - 1, y, center.z), N.ladder, 4)
		end
	elseif N.vine then
		for y = center.y - 10, center.y - 1 do
			set(vector.new(center.x - 1, y, center.z), N.vine, 4)
		end
	end

	local chest_pos = vector.offset(center, 3, -10, 3)
	core.place_node(chest_pos, { name = N.chest })
	evolve.fill_treasure_chest(chest_pos, 3)
	if N.torch then
		set(vector.offset(center, -4, -8, -4), N.torch)
		set(vector.offset(center, 4, -8, -4), N.torch)
		set(vector.offset(center, -4, -8, 4), N.torch)
		set(vector.offset(center, 4, -8, 4), N.torch)
	end
end

local function coin_trail(center, radius)
	for i = -radius + 4, radius - 4, 3 do
		local y = center.y + 5 + ((i % 2 == 0) and 1 or 0)
		set(vector.new(center.x + i, y, center.z - math.floor(radius / 2)), N.coin)
	end
	for i = -radius + 6, radius - 6, 4 do
		set(vector.new(center.x + math.floor(radius / 2), center.y + 5, center.z + i), N.coin)
	end
end

local function seed_from_area(center, radius, salt)
	return math.abs(center.x * 92821 + center.y * 4099 + center.z * 68917 + radius * 137 + salt) % 2147483647
end

local function get_noise(seed, spread, octaves, persist, scale)
	return core.get_perlin({
		offset = 0,
		scale = scale or 1,
		spread = { x = spread, y = spread, z = spread },
		seed = seed,
		octaves = octaves,
		persist = persist,
		lacunarity = 2,
	})
end

local function make_noises(center, radius)
	return {
		terrain = get_noise(seed_from_area(center, radius, 11), math.max(18, radius * 0.85), 4, 0.58, 1),
		detail = get_noise(seed_from_area(center, radius, 23), math.max(8, radius * 0.28), 3, 0.55, 1),
		mushrooms = get_noise(seed_from_area(center, radius, 37), math.max(12, radius * 0.42), 4, 0.62, 1),
		decor = get_noise(seed_from_area(center, radius, 53), math.max(6, radius * 0.18), 3, 0.5, 1),
	}
end

local function height_key(x, z)
	return x .. "," .. z
end

local function top_at(heights, x, z, fallback)
	return heights[height_key(x, z)] or fallback
end

local function edge_weight(dx, dz, radius)
	local dist = math.sqrt(dx * dx + dz * dz)
	return math.max(0, math.min(1, 1 - dist / radius))
end

local function hill_rise(noises, x, z, dx, dz, radius)
	local edge = edge_weight(dx, dz, radius)
	local terrain = noises.terrain:get_2d({ x = x, y = z })
	local detail = noises.detail:get_2d({ x = x, y = z })
	local rolling = 0.5 + terrain * 0.42 + detail * 0.2
	local edge_blend = math.min(1, edge * 3)
	local rise = (2 + rolling * 9) * edge_blend
	return math.max(0, math.floor(rise + 0.5))
end

local function place_normal_mushroom(pos, score)
	local choices = {}
	if N.normal_red then
		table.insert(choices, N.normal_red)
	end
	if N.normal_brown then
		table.insert(choices, N.normal_brown)
	end
	if #choices == 0 then
		return
	end
	local node = choices[(math.floor(math.abs(score) * 1000) % #choices) + 1]
	set(pos, node)
end

local function collect_mushroom_candidates(center, radius, heights, noises, base_y)
	local candidates = {}
	local step = radius >= 48 and 4 or 3
	for dz = -radius + 4, radius - 4, step do
		for dx = -radius + 4, radius - 4, step do
			local dist2 = dx * dx + dz * dz
			if dist2 <= (radius - 4) * (radius - 4) then
				local x = center.x + dx
				local z = center.z + dz
				local edge = edge_weight(dx, dz, radius)
				local score = noises.mushrooms:get_2d({ x = x, y = z }) + edge * 0.25
				if score > 0.18 then
					table.insert(candidates, {
						x = x,
						z = z,
						y = top_at(heights, x, z, base_y) + 1,
						score = score,
					})
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	return candidates
end

local function place_random_giant_mushrooms(center, radius, heights, noises, base_y)
	local pr = PcgRandom(seed_from_area(center, radius, 71))
	local target = math.max(4, math.min(18, math.floor(radius / 5)))
	local placed = {}
	local candidates = collect_mushroom_candidates(center, radius, heights, noises, base_y)

	for _, candidate in ipairs(candidates) do
		if #placed >= target then
			break
		end
		local cap_radius = pr:next(2, radius >= 48 and 5 or 4)
		local height = pr:next(4, math.max(7, math.min(15, math.floor(radius / 5) + 5)))
		local spacing = cap_radius * 3 + 4
		local ok = true
		for _, other in ipairs(placed) do
			local dx = candidate.x - other.x
			local dz = candidate.z - other.z
			if dx * dx + dz * dz < spacing * spacing then
				ok = false
				break
			end
		end
		if ok then
			table.insert(placed, candidate)
			local cap = pr:next(1, 2) == 1 and N.red_cap or N.brown_cap
			giant_mushroom(vector.new(candidate.x, candidate.y, candidate.z), cap, height, cap_radius)
		end
	end
end

function evolve.mushroom_kingdom(name, area)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end

	local max_area = math.min(evolve.settings.max_mushroom_kingdom_area or 64, evolve.settings.max_radius)
	local radius = evolve.clamp_number(area, 12, max_area)
	if not radius then
		return false, S("Invalid area.")
	end

	refresh_nodes()

	local minp = vector.offset(center, -radius - 6, -14, -radius - 6)
	local maxp = vector.offset(center, radius + 6, 34, radius + 6)
	local ok, err = evolve.capture(name, minp, maxp, "mushroom kingdom")
	if not ok then
		return false, err
	end

	local base_y = center.y - 1
	local noises = make_noises(center, radius)
	local heights = {}
	for dz = -radius, radius do
		for dx = -radius, radius do
			local dist2 = dx * dx + dz * dz
			if dist2 <= radius * radius then
				local dist = math.sqrt(dist2)
				local x = center.x + dx
				local z = center.z + dz
				local rise = hill_rise(noises, x, z, dx, dz, radius)
				local top_y = base_y + math.max(0, rise)
				heights[height_key(x, z)] = top_y
				local mushroom_score = noises.mushrooms:get_2d({ x = x, y = z })
				local ground = mushroom_score > 0.22 and N.mycelium or N.grass
				for y = base_y - 4, top_y - 1 do
					set(vector.new(x, y, z), N.dirt)
				end
				set(vector.new(x, top_y, z), ground)
				for y = top_y + 1, top_y + 5 do
					set(vector.new(x, y, z), N.air)
				end
				local decor_score = noises.decor:get_2d({ x = x, y = z })
				local seed = math.floor((dx * 92821 + dz * 68917 + radius) + decor_score * 10000)
				if dist > 3 and decor_score > 0.42 then
					place_normal_mushroom(vector.new(x, top_y + 1, z), decor_score)
				elseif dist > 3 and decor_score > 0.18 then
					place_flower(vector.new(x, top_y + 1, z), seed)
				elseif decor_score < -0.5 and core.registered_nodes["mcl_flowers:tallgrass"] then
					set(vector.new(x, top_y + 1, z), "mcl_flowers:tallgrass")
				end
			end
		end
	end

	place_random_giant_mushrooms(center, radius, heights, noises, base_y)

	cloud(vector.offset(center, -math.floor(radius * 0.45), 18, -math.floor(radius * 0.45)))
	cloud(vector.offset(center, math.floor(radius * 0.35), 21, math.floor(radius * 0.25)))
	coin_trail(center, radius)
	local pipe_base = vector.new(center.x, top_at(heights, center.x, center.z, base_y) + 1, center.z)
	pipe_entrance(pipe_base)
	secret_room(pipe_base)

	core.fix_light(minp, maxp)
	evolve.log_action(name, "mushroom_kingdom", minp, maxp, ("area=%d"):format(radius))
	return true, S("Painted 2D Perlin Mushroom Kingdom area with radius @1.", radius)
end
