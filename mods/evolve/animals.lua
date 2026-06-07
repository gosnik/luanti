local S = evolve.S

local animal_pool = {
	{ name = "mobs_mc:cow", weight = 10 },
	{ name = "mobs_mc:pig", weight = 10 },
	{ name = "mobs_mc:sheep", weight = 10 },
	{ name = "mobs_mc:chicken", weight = 10 },
	{ name = "mobs_mc:rabbit", weight = 8 },
	{ name = "mobs_mc:horse", weight = 4 },
	{ name = "mobs_mc:donkey", weight = 3 },
	{ name = "mobs_mc:mule", weight = 2 },
	{ name = "mobs_mc:llama", weight = 3 },
	{ name = "mobs_mc:cat", weight = 3 },
	{ name = "mobs_mc:ocelot", weight = 2 },
	{ name = "mobs_mc:parrot", weight = 2 },
	{ name = "mobs_mc:mooshroom", weight = 1 },
}

local function available_animals()
	local animals = {}
	local total = 0
	for _, entry in ipairs(animal_pool) do
		if core.registered_entities[entry.name] then
			total = total + entry.weight
			table.insert(animals, {
				name = entry.name,
				weight = entry.weight,
				cumulative = total,
			})
		end
	end
	return animals, total
end

local function choose_animal(animals, total, pr)
	if total <= 0 then
		return nil
	end
	local roll = pr:next(1, total)
	for _, entry in ipairs(animals) do
		if roll <= entry.cumulative then
			return entry.name
		end
	end
	return animals[#animals] and animals[#animals].name
end

local function can_modify(name, pos)
	return not core.is_protected(pos, name)
end

local function is_safe_floor(node_name)
	if not node_name then
		return false
	end
	local def = core.registered_nodes[node_name]
	if not def or not def.walkable then
		return false
	end
	if core.get_item_group(node_name, "water") > 0 or core.get_item_group(node_name, "lava") > 0 then
		return false
	end
	return true
end

local function surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local ground_pos = vector.new(x, y, z)
		local ground = core.get_node_or_nil(ground_pos)
		local feet = core.get_node_or_nil(vector.offset(ground_pos, 0, 1, 0))
		local head = core.get_node_or_nil(vector.offset(ground_pos, 0, 2, 0))
		if ground and feet and head and is_safe_floor(ground.name) and feet.name == "air" and head.name == "air" then
			return y
		end
	end
end

local function protected_spawn_area(name, pos)
	for y = 0, 2 do
		if not can_modify(name, vector.offset(pos, 0, y, 0)) then
			return true
		end
	end
	return false
end

local function make_candidates(center, radius)
	local noise = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(16, radius * 0.34), y = math.max(16, radius * 0.34), z = math.max(16, radius * 0.34) },
		seed = 77839 + core.hash_node_position(center),
		octaves = 4,
		persist = 0.54,
		lacunarity = 2,
	})
	local detail = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(8, radius * 0.14), y = math.max(8, radius * 0.14), z = math.max(8, radius * 0.14) },
		seed = 11927 + core.hash_node_position(center),
		octaves = 3,
		persist = 0.5,
		lacunarity = 2,
	})
	local candidates = {}
	local step = math.max(3, math.floor(radius / 10))
	for z = center.z - radius, center.z + radius, step do
		for x = center.x - radius, center.x + radius, step do
			local dx = x - center.x
			local dz = z - center.z
			local d2 = dx * dx + dz * dz
			if d2 <= radius * radius then
				local dist = math.sqrt(d2)
				local n = noise:get_2d({ x = x, y = z })
				local d = detail:get_2d({ x = x, y = z })
				table.insert(candidates, {
					x = x,
					z = z,
					score = n * 0.75 + d * 0.25 - (dist / radius) * 0.05,
				})
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	return candidates
end

local function far_enough(pos, placed)
	for _, existing in ipairs(placed) do
		if vector.distance(pos, existing) < 3.5 then
			return false
		end
	end
	return true
end

local function default_count(radius)
	return math.max(4, math.min(evolve.settings.max_animal_count or 80, math.floor(radius * radius / 220)))
end

local function area_bounds(center, radius)
	return vector.offset(center, -radius, -96, -radius), vector.offset(center, radius, 96, radius)
end

function evolve.populate_animals(name, radius, count)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end

	radius = evolve.clamp_number(radius, 4, evolve.settings.max_animal_radius or 160)
	if not radius then
		return false, S("Invalid radius.")
	end

	count = evolve.clamp_number(count or default_count(radius), 1, evolve.settings.max_animal_count or 80)
	if not count then
		return false, S("Invalid animal count.")
	end

	local animals, total_weight = available_animals()
	if #animals == 0 then
		return false, S("No compatible Mineclonia animal entities are registered.")
	end

	local minp, maxp = area_bounds(center, radius)
	core.load_area(minp, maxp)

	local pr = PcgRandom(65011 + core.hash_node_position(center) + radius * 31 + count)
	local candidates = make_candidates(center, radius)
	local placed = {}
	local spawned = 0
	local attempts = 0

	for _, candidate in ipairs(candidates) do
		if spawned >= count then
			break
		end
		attempts = attempts + 1
		local x = candidate.x + pr:next(-1, 1)
		local z = candidate.z + pr:next(-1, 1)
		local y = surface_y(x, z, center.y - 96, center.y + 96)
		if y then
			local spawn_pos = vector.new(x + 0.5, y + 1.06, z + 0.5)
			local node_pos = vector.new(x, y + 1, z)
			if not protected_spawn_area(name, node_pos) and far_enough(spawn_pos, placed) then
				local animal = choose_animal(animals, total_weight, pr)
				local object = animal and core.add_entity(spawn_pos, animal, core.serialize({ persistent = true }))
				if object then
					local entity = object:get_luaentity()
					if entity then
						entity._evolve_area = {
							owner = name,
							center = evolve.round_pos(center),
							radius = radius,
						}
					end
					table.insert(placed, spawn_pos)
					spawned = spawned + 1
				end
			end
		end
	end

	evolve.log_action(name, "animals", minp, maxp, ("radius=%d requested=%d spawned=%d attempts=%d"):format(radius, count, spawned, attempts))
	return true, S("Populated radius @1 with @2 random animals.", radius, spawned)
end
