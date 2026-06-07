local S = evolve.S

local nodes = {
	air = "air",
	cobble = "mcl_core:cobble",
	stone = "mcl_core:stone",
	glass = "mcl_core:glass",
	log = "mcl_trees:tree_oak",
	wood = "mcl_trees:wood_oak",
	birch_log = "mcl_trees:tree_birch",
	birch_wood = "mcl_trees:wood_birch",
	spruce_log = "mcl_trees:tree_spruce",
	spruce_wood = "mcl_trees:wood_spruce",
	chest = "mcl_chests:chest",
	torch = "mcl_torches:torch",
	fence = "mcl_fences:oak_fence",
	farmland = "mcl_farming:soil",
	wheat = "mcl_farming:wheat_7",
	water = "mcl_core:water_source",
}

local function node(name, fallback)
	if core.registered_nodes[name] then
		return name
	end
	return fallback or "air"
end

local function set(pos, name, param2)
	core.swap_node(pos, { name = node(name), param2 = param2 or 0 })
end

local function maybe_set(pos, name, param2)
	if core.registered_nodes[name] then
		core.swap_node(pos, { name = name, param2 = param2 or 0 })
	end
end

local function fill_box(minp, maxp, name)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				set(vector.new(x, y, z), name)
			end
		end
	end
end

local function surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local pos = vector.new(x, y, z)
		local def = core.registered_nodes[core.get_node(pos).name]
		local above = core.get_node(vector.offset(pos, 0, 1, 0)).name
		if def and def.walkable and above == "air" then
			return y
		end
	end
	return min_y
end

local function foundation_y(center)
	return surface_y(center.x, center.z, center.y - 32, center.y + 32) + 1
end

local function region_for(center, footprint, height)
	local y = foundation_y(center)
	return {
		minp = vector.new(center.x - footprint - 2, y - 3, center.z - footprint - 2),
		maxp = vector.new(center.x + footprint + 2, y + height + 3, center.z + footprint + 2),
	}
end

local function flatten_floor(cx, y, cz, rx, rz, material)
	material = material or nodes.cobble
	for z = cz - rz, cz + rz do
		for x = cx - rx, cx + rx do
			local gy = surface_y(x, z, y - 18, y + 18)
			for yy = gy + 1, y - 1 do
				set(vector.new(x, yy, z), nodes.cobble)
			end
			for yy = y, y + 7 do
				set(vector.new(x, yy, z), nodes.air)
			end
			set(vector.new(x, y, z), material)
		end
	end
end

local function place_shell_house(origin, def)
	local x0, y0, z0 = origin.x, origin.y, origin.z
	local rx, rz = def.rx, def.rz
	local wall = def.wall or nodes.wood
	local post = def.post or nodes.log
	local roof = def.roof or nodes.wood
	local tier = def.tier or 1

	flatten_floor(x0, y0, z0, rx + 1, rz + 1, nodes.cobble)
	fill_box(vector.new(x0 - rx, y0 + 1, z0 - rz), vector.new(x0 + rx, y0 + 4, z0 + rz), nodes.air)

	for y = y0 + 1, y0 + 4 do
		for x = x0 - rx, x0 + rx do
			set(vector.new(x, y, z0 - rz), wall)
			set(vector.new(x, y, z0 + rz), wall)
		end
		for z = z0 - rz, z0 + rz do
			set(vector.new(x0 - rx, y, z), wall)
			set(vector.new(x0 + rx, y, z), wall)
		end
	end

	for _, p in ipairs({
		vector.new(x0 - rx, y0 + 1, z0 - rz),
		vector.new(x0 + rx, y0 + 1, z0 - rz),
		vector.new(x0 - rx, y0 + 1, z0 + rz),
		vector.new(x0 + rx, y0 + 1, z0 + rz),
	}) do
		fill_box(p, vector.offset(p, 0, 3, 0), post)
	end

	for step = 0, math.min(rx, rz) + 1 do
		fill_box(vector.new(x0 - rx - 1 + step, y0 + 5 + step, z0 - rz - 1 + step),
			vector.new(x0 + rx + 1 - step, y0 + 5 + step, z0 + rz + 1 - step), roof)
	end

	set(vector.new(x0, y0 + 1, z0 - rz), nodes.air)
	set(vector.new(x0, y0 + 2, z0 - rz), nodes.air)
	set(vector.new(x0 - math.max(1, rx - 1), y0 + 2, z0 - rz), nodes.glass)
	set(vector.new(x0 + math.max(1, rx - 1), y0 + 2, z0 + rz), nodes.glass)
	set(vector.new(x0 - rx, y0 + 2, z0), nodes.glass)
	set(vector.new(x0 + rx, y0 + 2, z0), nodes.glass)

	set(vector.new(x0 + rx - 1, y0 + 1, z0 + rz - 1), nodes.chest)
	evolve.fill_treasure_chest(vector.new(x0 + rx - 1, y0 + 1, z0 + rz - 1), tier)
	maybe_set(vector.new(x0 - rx + 1, y0 + 1, z0 + rz - 1), nodes.torch)
	maybe_set(vector.new(x0 + rx - 1, y0 + 1, z0 - rz + 1), nodes.torch)
end

local function place_tower(origin, def)
	local x0, y0, z0 = origin.x, origin.y, origin.z
	local r = def.rx or 4
	local height = def.height or 11

	flatten_floor(x0, y0, z0, r + 1, r + 1, nodes.stone)
	fill_box(vector.new(x0 - r + 1, y0 + 1, z0 - r + 1), vector.new(x0 + r - 1, y0 + height - 1, z0 + r - 1), nodes.air)
	for y = y0 + 1, y0 + height do
		for x = x0 - r, x0 + r do
			set(vector.new(x, y, z0 - r), nodes.stone)
			set(vector.new(x, y, z0 + r), nodes.stone)
		end
		for z = z0 - r, z0 + r do
			set(vector.new(x0 - r, y, z), nodes.stone)
			set(vector.new(x0 + r, y, z), nodes.stone)
		end
	end
	fill_box(vector.new(x0 - r - 1, y0 + height + 1, z0 - r - 1), vector.new(x0 + r + 1, y0 + height + 1, z0 + r + 1), nodes.wood)
	set(vector.new(x0, y0 + 1, z0 - r), nodes.air)
	set(vector.new(x0, y0 + 2, z0 - r), nodes.air)
	for y = y0 + 3, y0 + height - 2, 3 do
		set(vector.new(x0 - r, y, z0), nodes.glass)
		set(vector.new(x0 + r, y, z0), nodes.glass)
	end
	maybe_set(vector.new(x0, y0 + height + 2, z0), nodes.torch)
end

local function place_barn(origin, def)
	place_shell_house(origin, {
		rx = def.rx or 5,
		rz = def.rz or 7,
		wall = nodes.spruce_wood,
		post = nodes.spruce_log,
		roof = nodes.cobble,
		tier = def.tier or 1,
	})
	for z = origin.z - 2, origin.z + 2 do
		set(vector.new(origin.x, origin.y + 1, z), nodes.fence)
	end
end

local function place_market(origin, def)
	local x0, y0, z0 = origin.x, origin.y, origin.z
	local r = def.rx or 4
	flatten_floor(x0, y0, z0, r + 1, r + 1, nodes.cobble)
	for _, p in ipairs({
		vector.new(x0 - r, y0 + 1, z0 - r),
		vector.new(x0 + r, y0 + 1, z0 - r),
		vector.new(x0 - r, y0 + 1, z0 + r),
		vector.new(x0 + r, y0 + 1, z0 + r),
	}) do
		fill_box(p, vector.offset(p, 0, 3, 0), nodes.fence)
	end
	fill_box(vector.new(x0 - r - 1, y0 + 5, z0 - r - 1), vector.new(x0 + r + 1, y0 + 5, z0 + r + 1), nodes.wood)
	fill_box(vector.new(x0 - r + 1, y0 + 1, z0 - 1), vector.new(x0 + r - 1, y0 + 1, z0 + 1), nodes.wood)
	set(vector.new(x0, y0 + 2, z0), nodes.chest)
	evolve.fill_treasure_chest(vector.new(x0, y0 + 2, z0), def.tier or 1)
end

local function place_farm(origin, def)
	local x0, y0, z0 = origin.x, origin.y, origin.z
	local rx, rz = def.rx or 6, def.rz or 5
	flatten_floor(x0, y0, z0, rx, rz, nodes.farmland)
	for z = z0 - rz + 1, z0 + rz - 1 do
		for x = x0 - rx + 1, x0 + rx - 1 do
			if x == x0 then
				set(vector.new(x, y0, z), nodes.water)
			else
				maybe_set(vector.new(x, y0 + 1, z), nodes.wheat)
			end
		end
	end
end

local function place_well(origin)
	local x0, y0, z0 = origin.x, origin.y, origin.z
	flatten_floor(x0, y0, z0, 3, 3, nodes.cobble)
	fill_box(vector.new(x0 - 1, y0, z0 - 1), vector.new(x0 + 1, y0, z0 + 1), nodes.water)
	for _, p in ipairs({
		vector.new(x0 - 2, y0 + 1, z0 - 2),
		vector.new(x0 + 2, y0 + 1, z0 - 2),
		vector.new(x0 - 2, y0 + 1, z0 + 2),
		vector.new(x0 + 2, y0 + 1, z0 + 2),
	}) do
		fill_box(p, vector.offset(p, 0, 3, 0), nodes.fence)
	end
	fill_box(vector.new(x0 - 3, y0 + 5, z0 - 3), vector.new(x0 + 3, y0 + 5, z0 + 3), nodes.wood)
end

local building_types = {
	{
		name = "cottage",
		footprint = 7,
		height = 10,
		place = function(origin, tier)
			place_shell_house(origin, { rx = 3, rz = 4, wall = nodes.wood, post = nodes.log, roof = nodes.birch_wood, tier = tier })
		end,
	},
	{
		name = "farmhouse",
		footprint = 9,
		height = 10,
		place = function(origin, tier)
			place_shell_house(origin, { rx = 5, rz = 4, wall = nodes.birch_wood, post = nodes.log, roof = nodes.wood, tier = tier })
		end,
	},
	{
		name = "barn",
		footprint = 10,
		height = 11,
		place = function(origin, tier)
			place_barn(origin, { rx = 5, rz = 6, tier = tier })
		end,
	},
	{
		name = "market",
		footprint = 7,
		height = 8,
		place = function(origin, tier)
			place_market(origin, { rx = 4, tier = tier })
		end,
	},
	{
		name = "farm",
		footprint = 10,
		height = 4,
		place = function(origin)
			place_farm(origin, { rx = 7, rz = 5 })
		end,
	},
	{
		name = "watchtower",
		footprint = 8,
		height = 17,
		place = function(origin)
			place_tower(origin, { rx = 4, height = 12 })
		end,
	},
}

local sizes = {
	small = { radius = 42, buildings = 9, tier = 1 },
	medium = { radius = 68, buildings = 16, tier = 2 },
	large = { radius = 92, buildings = 28, tier = 3 },
}

local city_sizes = {
	small = { radius = 58, buildings = 15, tier = 2 },
	medium = { radius = 86, buildings = 26, tier = 3 },
	large = { radius = 120, buildings = 42, tier = 3 },
}

local function settlement_bounds(center, radius)
	return vector.offset(center, -radius - 4, -36, -radius - 4), vector.offset(center, radius + 4, 36, radius + 4)
end

local function choose_building(noise_value, index, city)
	local shifted = math.floor(math.abs(noise_value * 1000) + index * 7)
	if city and shifted % 7 == 0 then
		return building_types[6]
	end
	return building_types[(shifted % #building_types) + 1]
end

local function build_candidates(center, radius)
	local noise = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(radius * 0.38, 24), y = math.max(radius * 0.38, 24), z = math.max(radius * 0.38, 24) },
		seed = 7331 + core.hash_node_position(center),
		octaves = 4,
		persist = 0.56,
		lacunarity = 2.0,
	})
	local detail = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(radius * 0.16, 12), y = math.max(radius * 0.16, 12), z = math.max(radius * 0.16, 12) },
		seed = 9919 + core.hash_node_position(center),
		octaves = 3,
		persist = 0.5,
		lacunarity = 2.0,
	})
	local candidates = {}
	local step = 6
	for z = center.z - radius, center.z + radius, step do
		for x = center.x - radius, center.x + radius, step do
			local dx, dz = x - center.x, z - center.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist > 10 and dist < radius - 8 then
				local n = noise:get_2d({ x = x, y = z })
				local d = detail:get_2d({ x = x, y = z })
				local score = n * 0.75 + d * 0.25 - (dist / radius) * 0.08
				local jx = math.floor(d * 4)
				local jz = math.floor(n * 4)
				table.insert(candidates, {
					x = x + jx,
					z = z + jz,
					score = score,
					noise = n,
					dist = dist,
				})
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	return candidates
end

local function far_enough(pos, footprint, placed, gap)
	gap = gap or 3
	for _, other in ipairs(placed) do
		local dx = pos.x - other.pos.x
		local dz = pos.z - other.pos.z
		local required = footprint + other.footprint + gap
		if dx * dx + dz * dz < required * required then
			return false
		end
	end
	return true
end

local function make_plan(center, size, city)
	local cfg = (city and city_sizes[size] or sizes[size]) or sizes.small
	local radius = math.min(cfg.radius, evolve.settings.max_structure_size)
	local candidates = build_candidates(center, radius)
	local placed = {}

	table.insert(placed, {
		pos = vector.new(center.x, foundation_y(center), center.z),
		type = { name = "well", footprint = 6, height = 8, place = place_well },
		footprint = 6,
	})

	for index, candidate in ipairs(candidates) do
		if #placed >= cfg.buildings then
			break
		end
		local btype = choose_building(candidate.noise, index, city)
		local pos = vector.new(candidate.x, foundation_y(vector.new(candidate.x, center.y, candidate.z)), candidate.z)
		if far_enough(pos, btype.footprint, placed, 3) then
			table.insert(placed, {
				pos = pos,
				type = btype,
				footprint = btype.footprint,
			})
		end
	end

	if #placed < cfg.buildings then
		for index, candidate in ipairs(candidates) do
			if #placed >= cfg.buildings then
				break
			end
			local btype = choose_building(candidate.noise, index + 37, city)
			local pos = vector.new(candidate.x, foundation_y(vector.new(candidate.x, center.y, candidate.z)), candidate.z)
			if far_enough(pos, btype.footprint, placed, -2) then
				table.insert(placed, {
					pos = pos,
					type = btype,
					footprint = btype.footprint,
				})
			end
		end
	end

	return {
		cfg = cfg,
		radius = radius,
		buildings = placed,
	}
end

local function road_between(a, b)
	local points = {}
	local dx, dz = b.x - a.x, b.z - a.z
	local steps = math.max(math.abs(dx), math.abs(dz))
	if steps < 1 then
		return points
	end
	for i = 0, steps do
		local t = i / steps
		table.insert(points, {
			x = math.floor(a.x + dx * t + 0.5),
			z = math.floor(a.z + dz * t + 0.5),
		})
	end
	return points
end

local function road_regions(center, plan)
	local regions = {}
	for _, building in ipairs(plan.buildings) do
		if building.pos.x ~= center.x or building.pos.z ~= center.z then
			for _, p in ipairs(road_between(center, building.pos)) do
				local y = surface_y(p.x, p.z, center.y - 36, center.y + 36) + 1
				table.insert(regions, {
					minp = vector.new(p.x - 1, y - 2, p.z - 1),
					maxp = vector.new(p.x + 1, y + 2, p.z + 1),
				})
			end
		end
	end
	return regions
end

local function capture_plan(name, center, plan, label)
	local regions = {}
	for _, building in ipairs(plan.buildings) do
		table.insert(regions, region_for(building.pos, building.footprint, building.type.height or 10))
	end
	for _, region in ipairs(road_regions(center, plan)) do
		table.insert(regions, region)
	end
	return evolve.capture_regions(name, regions, label)
end

local function place_roads(center, plan)
	for _, building in ipairs(plan.buildings) do
		if building.pos.x ~= center.x or building.pos.z ~= center.z then
			for _, p in ipairs(road_between(center, building.pos)) do
				local y = surface_y(p.x, p.z, center.y - 36, center.y + 36) + 1
				for z = p.z - 1, p.z + 1 do
					for x = p.x - 1, p.x + 1 do
						local gy = surface_y(x, z, y - 12, y + 12)
						for yy = gy + 1, y - 1 do
							set(vector.new(x, yy, z), nodes.cobble)
						end
						set(vector.new(x, y, z), nodes.cobble)
						set(vector.new(x, y + 1, z), nodes.air)
						set(vector.new(x, y + 2, z), nodes.air)
					end
				end
			end
		end
	end
end

local function build_settlement(center, size, city)
	local plan = make_plan(center, size, city)
	place_roads(center, plan)
	for _, building in ipairs(plan.buildings) do
		building.type.place(building.pos, plan.cfg.tier)
	end
	local minp, maxp = settlement_bounds(center, plan.radius)
	return minp, maxp, #plan.buildings, plan
end

function evolve.place_hut(name)
	local pos = evolve.player_pos(name)
	if not pos then
		return false, S("Player not found.")
	end

	local center = vector.offset(pos, 0, 0, 6)
	local origin = vector.new(center.x, foundation_y(center), center.z)
	local minp, maxp = settlement_bounds(origin, 10)
	local ok, err = evolve.capture(name, minp, maxp, "hut")
	if not ok then
		return false, err
	end

	place_shell_house(origin, { rx = 3, rz = 4, wall = nodes.wood, post = nodes.log, roof = nodes.birch_wood, tier = 1 })
	core.fix_light(minp, maxp)
	evolve.log_action(name, "hut", minp, maxp)
	return true, S("Built hut.")
end

function evolve.place_village(name, size)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end
	size = sizes[size] and size or "small"
	local plan = make_plan(center, size, false)

	local ok, err = capture_plan(name, center, plan, "village")
	if not ok then
		return false, err
	end

	local minp, maxp, count = build_settlement(center, size, false)
	core.fix_light(minp, maxp)
	evolve.log_action(name, "village", minp, maxp, ("size=%s buildings=%d radius=%d"):format(size, count, plan.radius))
	return true, S("Built @1 village with @2 varied buildings.", size, count)
end

function evolve.place_city(name, size)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end
	size = city_sizes[size] and size or "small"
	local plan = make_plan(center, size, true)

	local ok, err = capture_plan(name, center, plan, "city")
	if not ok then
		return false, err
	end

	local minp, maxp, count = build_settlement(center, size, true)
	core.fix_light(minp, maxp)
	evolve.log_action(name, "city", minp, maxp, ("size=%s buildings=%d radius=%d"):format(size, count, plan.radius))
	return true, S("Built @1 city with @2 varied buildings.", size, count)
end
