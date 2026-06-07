local S = evolve.S

local villager_entity = "mobs_mc:villager"
local bell_nodes = {
	"mcl_bells:bell",
	"mcl_bells:bell_wall",
	"mcl_bells:bell_ceiling",
}

local function has_villager_support()
	return core.registered_entities[villager_entity] ~= nil
end

local function surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local pos = vector.new(x, y, z)
		local def = core.registered_nodes[core.get_node(pos).name]
		local feet = core.get_node(vector.offset(pos, 0, 1, 0)).name
		local head = core.get_node(vector.offset(pos, 0, 2, 0)).name
		if def and def.walkable and feet == "air" and head == "air" then
			return y
		end
	end
end

local function find_safe_spawn(pos)
	local y = surface_y(pos.x, pos.z, pos.y - 96, pos.y + 96)
	if not y then
		return nil
	end
	return vector.new(pos.x + 0.5, y + 1.06, pos.z + 0.5)
end

local function area_bounds(center, radius)
	return vector.offset(center, -radius, -96, -radius), vector.offset(center, radius, 96, radius)
end

local function is_bed_bottom(pos)
	local node = core.get_node(pos)
	return core.get_item_group(node.name, "bed_bottom") > 0
		or core.get_item_group(node.name, "bed") == 1
end

local function collect_beds(minp, maxp)
	local beds = {}
	for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, { "group:bed", "group:bed_bottom" })) do
		if is_bed_bottom(pos) then
			table.insert(beds, vector.new(pos))
		end
	end
	return beds
end

local function collect_jobsites(minp, maxp)
	if not mobs_mc or not mobs_mc.jobsites or #mobs_mc.jobsites == 0 then
		return {}
	end
	local jobs = {}
	for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, mobs_mc.jobsites)) do
		table.insert(jobs, vector.new(pos))
	end
	return jobs
end

local function collect_bells(minp, maxp)
	local bells = {}
	for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, bell_nodes)) do
		table.insert(bells, vector.new(pos))
	end
	return bells
end

local function nearest(pos, list)
	local best
	local best_dist
	for _, candidate in ipairs(list) do
		local dist = vector.distance(pos, candidate)
		if not best_dist or dist < best_dist then
			best = candidate
			best_dist = dist
		end
	end
	return best
end

local function collect_existing_villagers(center, radius)
	local villagers = {}
	for _, object in ipairs(core.get_objects_inside_radius(center, radius)) do
		local entity = object:get_luaentity()
		if entity and entity.name == villager_entity then
			table.insert(villagers, object)
		end
	end
	return villagers
end

local function make_spawn_points(center, radius, count)
	local noise = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(radius * 0.35, 18), y = math.max(radius * 0.35, 18), z = math.max(radius * 0.35, 18) },
		seed = 52891 + core.hash_node_position(center),
		octaves = 4,
		persist = 0.54,
		lacunarity = 2.0,
	})
	local candidates = {}
	local step = math.max(4, math.floor(radius / 8))
	for z = center.z - radius, center.z + radius, step do
		for x = center.x - radius, center.x + radius, step do
			local dx = x - center.x
			local dz = z - center.z
			local d2 = dx * dx + dz * dz
			if d2 <= radius * radius then
				table.insert(candidates, {
					pos = vector.new(x, center.y, z),
					score = noise:get_2d({ x = x, y = z }) - math.sqrt(d2) / radius * 0.08,
				})
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)

	local points = {}
	for _, candidate in ipairs(candidates) do
		if #points >= count then
			break
		end
		local spawn = find_safe_spawn(candidate.pos)
		if spawn then
			local ok = true
			for _, existing in ipairs(points) do
				if vector.distance(spawn, existing) < 4 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(points, spawn)
			end
		end
	end
	return points
end

local function assign_villager(object, center, radius, beds, bells, jobs, area_name, owner)
	local entity = object and object:get_luaentity()
	if not entity then
		return false
	end

	local pos = object:get_pos()
	entity._evolve_area = {
		name = area_name,
		center = evolve.round_pos(center),
		radius = radius,
		owner = owner,
	}

	local assigned = false
	local bed = table.remove(beds, 1)
	if bed and entity.claim_home then
		assigned = entity:claim_home(bed) or assigned
	end

	local bell = nearest(pos, bells)
	if bell and entity.claim_bell then
		assigned = entity:claim_bell(bell) or assigned
	end

	local job = table.remove(jobs, 1)
	if job and entity.claim_poi then
		entity:claim_poi(job, nil)
		assigned = true
	end

	if entity.happy_villager_effect then
		entity:happy_villager_effect()
	end
	return assigned
end

function evolve.assign_villagers(name, radius, count, area_name)
	if not has_villager_support() then
		return false, S("Mineclonia villager entity is not available.")
	end

	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end

	radius = evolve.clamp_number(radius or 48, 8, evolve.settings.max_villager_radius)
	count = evolve.clamp_number(count or 8, 1, evolve.settings.max_villager_count)
	area_name = area_name or ("area_" .. core.pos_to_string(center))

	local minp, maxp = area_bounds(center, radius)
	core.load_area(minp, maxp)

	local beds = collect_beds(minp, maxp)
	local bells = collect_bells(minp, maxp)
	local jobs = collect_jobsites(minp, maxp)
	local existing = collect_existing_villagers(center, radius)
	local spawned = 0
	local assigned = 0

	for _, object in ipairs(existing) do
		if assigned >= count then
			break
		end
		if assign_villager(object, center, radius, beds, bells, jobs, area_name, name) then
			assigned = assigned + 1
		else
			assigned = assigned + 1
		end
	end

	local remaining = count - assigned
	if remaining > 0 then
		for _, spawn_pos in ipairs(make_spawn_points(center, radius, remaining)) do
			local object = core.add_entity(spawn_pos, villager_entity, core.serialize({ persistent = true }))
			if object then
				spawned = spawned + 1
				assign_villager(object, center, radius, beds, bells, jobs, area_name, name)
				assigned = assigned + 1
			end
			if assigned >= count then
				break
			end
		end
	end

	evolve.log_action(name, "villagers", minp, maxp, ("radius=%d requested=%d assigned=%d spawned=%d"):format(radius, count, assigned, spawned))
	return true, S("Assigned @1 villagers to area @2. Spawned @3 new villagers.", assigned, area_name, spawned)
end
