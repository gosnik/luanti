local S = core.get_translator("evolve")
evolve.S = S

evolve.settings = {
	max_radius = tonumber(core.settings:get("evolve.max_radius")) or 3000,
	max_volume = tonumber(core.settings:get("evolve.max_volume")) or 1000000,
	terraform_sync_radius = tonumber(core.settings:get("evolve.terraform_sync_radius")) or 64,
	terraform_chunk_size = tonumber(core.settings:get("evolve.terraform_chunk_size")) or 32,
	terraform_chunks_per_step = tonumber(core.settings:get("evolve.terraform_chunks_per_step")) or 1,
	time_enable = core.settings:get_bool("evolve.time_enable", true),
	time_day_start = tonumber(core.settings:get("evolve.time_day_start")) or 0.23,
	time_night_start = tonumber(core.settings:get("evolve.time_night_start")) or 0.77,
	time_day_speed = tonumber(core.settings:get("evolve.time_day_speed")) or 0.5,
	time_night_speed = tonumber(core.settings:get("evolve.time_night_speed")) or 4.0,
	max_villager_radius = tonumber(core.settings:get("evolve.max_villager_radius")) or 128,
	max_villager_count = tonumber(core.settings:get("evolve.max_villager_count")) or 64,
	max_evolve_villager_radius = tonumber(core.settings:get("evolve.max_evolve_villager_radius")) or 128,
	max_evolve_villager_count = tonumber(core.settings:get("evolve.max_evolve_villager_count")) or 64,
	evolve_villagers_ambient_enable = core.settings:get_bool("evolve.evolve_villagers_ambient_enable", true),
	evolve_villagers_ambient_interval = tonumber(core.settings:get("evolve.evolve_villagers_ambient_interval")) or 75,
	evolve_villagers_ambient_nearby_limit = tonumber(core.settings:get("evolve.evolve_villagers_ambient_nearby_limit")) or 2,
	evolve_villagers_teleport_min_time = tonumber(core.settings:get("evolve.evolve_villagers_teleport_min_time")) or 90,
	evolve_villagers_teleport_max_time = tonumber(core.settings:get("evolve.evolve_villagers_teleport_max_time")) or 180,
	max_charm_scatter_radius = tonumber(core.settings:get("evolve.max_charm_scatter_radius")) or 256,
	max_charm_scatter_count = tonumber(core.settings:get("evolve.max_charm_scatter_count")) or 256,
	max_mushroom_kingdom_area = tonumber(core.settings:get("evolve.max_mushroom_kingdom_area")) or 64,
	max_beautify_radius = tonumber(core.settings:get("evolve.max_beautify_radius")) or 80,
	max_animal_radius = tonumber(core.settings:get("evolve.max_animal_radius")) or 160,
	max_animal_count = tonumber(core.settings:get("evolve.max_animal_count")) or 80,
	undo_depth = tonumber(core.settings:get("evolve.undo_depth")) or 20,
	require_confirm_volume = tonumber(core.settings:get("evolve.require_confirm_volume")) or 20000,
	max_structure_size = tonumber(core.settings:get("evolve.max_structure_size")) or 128,
	max_treasure_tier = tonumber(core.settings:get("evolve.max_treasure_tier")) or 3,
	max_treasure_radius = tonumber(core.settings:get("evolve.max_treasure_radius")) or 256,
	max_treasure_count = tonumber(core.settings:get("evolve.max_treasure_count")) or 80,
}
evolve.undo_hooks = evolve.undo_hooks or {}

core.register_privilege("evolve", {
	description = S("Use Evolve admin tools"),
	give_to_singleplayer = false,
})

local history = {}

local function player_history(name)
	history[name] = history[name] or {}
	return history[name]
end

local function capture_region(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local snapshot = {}

	for index in area:iter(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z) do
		table.insert(snapshot, data[index])
	end

	return {
		minp = vector.new(minp),
		maxp = vector.new(maxp),
		data = snapshot,
	}
end

local function restore_region(region)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(region.minp, region.maxp)
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local cursor = 1

	for index in area:iter(region.minp.x, region.minp.y, region.minp.z, region.maxp.x, region.maxp.y, region.maxp.z) do
		data[index] = region.data[cursor]
		cursor = cursor + 1
	end

	vm:set_data(data)
	vm:write_to_map(false)
	core.fix_light(region.minp, region.maxp)
end

function evolve.has_priv(name)
	return core.check_player_privs(name, { evolve = true })
end

function evolve.require_priv(name)
	if evolve.has_priv(name) then
		return true
	end
	return false, S("Missing evolve privilege.")
end

function evolve.round_pos(pos)
	return vector.new(math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
end

function evolve.player_pos(name)
	local player = core.get_player_by_name(name)
	if not player then
		return nil
	end
	return evolve.round_pos(player:get_pos())
end

function evolve.facing_dir(name)
	local player = core.get_player_by_name(name)
	if not player then
		return vector.new(0, 0, 1)
	end
	local yaw = player:get_look_horizontal()
	local dir = core.yaw_to_dir(yaw)
	if math.abs(dir.x) > math.abs(dir.z) then
		return vector.new(dir.x > 0 and 1 or -1, 0, 0)
	end
	return vector.new(0, 0, dir.z > 0 and 1 or -1)
end

function evolve.parse_args(param)
	local args = {}
	for arg in param:gmatch("%S+") do
		table.insert(args, arg)
	end
	return args
end

function evolve.clamp_number(value, min_value, max_value)
	local n = tonumber(value)
	if not n then
		return nil
	end
	n = math.floor(n)
	if n < min_value then
		return min_value
	end
	if n > max_value then
		return max_value
	end
	return n
end

function evolve.validate_node(name)
	if name == "air" or core.registered_nodes[name] then
		return name
	end
	return nil
end

function evolve.volume(minp, maxp)
	return (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) * (maxp.z - minp.z + 1)
end

function evolve.sort_bounds(a, b)
	return vector.new(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
		vector.new(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
end

function evolve.capture(name, minp, maxp, label)
	local volume = evolve.volume(minp, maxp)
	if volume > evolve.settings.max_volume then
		return false, S("Operation volume @1 exceeds limit @2.", volume, evolve.settings.max_volume)
	end

	local list = player_history(name)
	local op = capture_region(minp, maxp)
	op.label = label or "operation"
	table.insert(list, op)

	while #list > evolve.settings.undo_depth do
		table.remove(list, 1)
	end

	return true
end

function evolve.capture_regions(name, regions, label)
	local total_volume = 0
	for _, region in ipairs(regions) do
		local volume = evolve.volume(region.minp, region.maxp)
		total_volume = total_volume + volume
		if total_volume > evolve.settings.max_volume then
			return false, S("Operation volume @1 exceeds limit @2.", total_volume, evolve.settings.max_volume)
		end
	end

	local captured = {}
	for _, region in ipairs(regions) do
		table.insert(captured, capture_region(region.minp, region.maxp))
	end

	local list = player_history(name)
	table.insert(list, {
		regions = captured,
		label = label or "operation",
	})

	while #list > evolve.settings.undo_depth do
		table.remove(list, 1)
	end

	return true
end

function evolve.register_undo_hook(func)
	table.insert(evolve.undo_hooks, func)
end

function evolve.undo(name)
	local list = player_history(name)
	local op = table.remove(list)
	if not op then
		return false, S("Nothing to undo.")
	end

	if op.regions then
		for _, region in ipairs(op.regions) do
			restore_region(region)
		end
	else
		restore_region(op)
	end
	core.log("action", ("[evolve] %s undid %s at %s -> %s"):format(
		name,
		op.label,
		core.pos_to_string(op.minp or op.regions[1].minp),
		core.pos_to_string(op.maxp or op.regions[#op.regions].maxp)
	))
	for _, hook in ipairs(evolve.undo_hooks) do
		hook(name, op)
	end
	return true, S("Undid @1.", op.label)
end

function evolve.log_action(name, action, minp, maxp, detail)
	core.log("action", ("[evolve] %s %s %s -> %s %s"):format(
		name,
		action,
		core.pos_to_string(minp),
		core.pos_to_string(maxp),
		detail or ""
	))
end

core.register_on_leaveplayer(function(player)
	history[player:get_player_name()] = nil
end)
