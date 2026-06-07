local S = evolve.S
local storage = core.get_mod_storage()

local links = core.deserialize(storage:get_string("pipe_links"), true) or {}
local cooldowns = {}
local timer = 0

local function first_registered(candidates, fallback)
	for _, name in ipairs(candidates) do
		if core.registered_nodes[name] then
			return name
		end
	end
	return fallback or "air"
end

local pipe_nodes = {}

local function refresh_nodes()
	pipe_nodes.air = "air"
	pipe_nodes.platform = first_registered({ "mcl_core:cobble", "mcl_core:stone" }, "mcl_core:stone")
	pipe_nodes.pipe = first_registered({ "mcl_wool:lime", "mcl_wool:green", "mcl_core:emeraldblock", "mcl_core:slimeblock" }, pipe_nodes.platform)
	pipe_nodes.pipe_dark = first_registered({ "mcl_wool:green", "mcl_core:emeraldblock", "mcl_core:slimeblock" }, pipe_nodes.pipe)
	pipe_nodes.gold = first_registered({ "mcl_core:goldblock", "mcl_core:stone_with_gold" }, pipe_nodes.platform)
	pipe_nodes.cloud = first_registered({ "mcl_wool:white", "mcl_core:snowblock", "mcl_core:glass" }, "mcl_core:glass")
	pipe_nodes.torch = first_registered({ "mcl_torches:torch" }, nil)
end

local function save_links()
	storage:set_string("pipe_links", core.serialize(links))
end

local function set(pos, name, param2)
	if name and core.registered_nodes[name] then
		core.set_node(pos, { name = name, param2 = param2 or 0 })
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

local function pipe_bounds(center)
	return vector.offset(center, -4, -1, -4), vector.offset(center, 4, 8, 4)
end

local function pipe_region(center)
	local minp, maxp = pipe_bounds(center)
	return { minp = minp, maxp = maxp }
end

local function build_pipe(center, marker_offset)
	fill_box(vector.offset(center, -4, -1, -4), vector.offset(center, 4, -1, 4), pipe_nodes.platform)
	fill_box(vector.offset(center, -1, 0, -1), vector.offset(center, 1, 4, 1), pipe_nodes.pipe_dark)
	fill_box(vector.offset(center, 0, 0, 0), vector.offset(center, 0, 5, 0), pipe_nodes.air)

	for z = -2, 2 do
		for x = -2, 2 do
			local edge = math.abs(x) == 2 or math.abs(z) == 2
			set(vector.offset(center, x, 4, z), edge and pipe_nodes.pipe or pipe_nodes.air)
			if edge then
				set(vector.offset(center, x, 5, z), pipe_nodes.pipe)
			end
		end
	end

	for i = -2, 2 do
		set(vector.offset(center, i, 6, -3), pipe_nodes.gold)
	end

	local marker = vector.add(vector.offset(center, 0, 7, 0), marker_offset)
	set(marker, pipe_nodes.cloud)
	set(vector.offset(marker, 1, 0, 0), pipe_nodes.cloud)
	set(vector.offset(marker, -1, 0, 0), pipe_nodes.cloud)
	if pipe_nodes.torch then
		set(vector.offset(center, -3, 0, -3), pipe_nodes.torch)
		set(vector.offset(center, 3, 0, 3), pipe_nodes.torch)
	end
end

local function entry_contains(pos, center)
	local rounded = evolve.round_pos(pos)
	return rounded.x == center.x
		and rounded.z == center.z
		and rounded.y >= center.y
		and rounded.y <= center.y + 5
end

local function destination_for(pos)
	for _, link in ipairs(links) do
		local a = vector.new(link.a)
		local b = vector.new(link.b)
		if entry_contains(pos, a) then
			return vector.offset(b, 0, 6, 0)
		elseif entry_contains(pos, b) then
			return vector.offset(a, 0, 6, 0)
		end
	end
	return nil
end

local function remove_link_at(center_a, center_b)
	for i = #links, 1, -1 do
		local link = links[i]
		if vector.equals(vector.new(link.a), center_a) or vector.equals(vector.new(link.b), center_a)
			or vector.equals(vector.new(link.a), center_b) or vector.equals(vector.new(link.b), center_b) then
			table.remove(links, i)
		end
	end
end

local function pos_in_region(pos, region)
	return pos.x >= region.minp.x and pos.x <= region.maxp.x
		and pos.y >= region.minp.y and pos.y <= region.maxp.y
		and pos.z >= region.minp.z and pos.z <= region.maxp.z
end

local function link_in_regions(link, regions)
	local a = vector.new(link.a)
	local b = vector.new(link.b)
	for _, region in ipairs(regions) do
		if pos_in_region(a, region) or pos_in_region(b, region) then
			return true
		end
	end
	return false
end

function evolve.create_pipe_link(name, distance)
	local player_pos = evolve.player_pos(name)
	if not player_pos then
		return false, S("Player not found.")
	end

	distance = evolve.clamp_number(distance or 160, 32, 1200)
	if not distance then
		return false, S("Invalid pipe distance.")
	end

	refresh_nodes()

	local dir = evolve.facing_dir(name)
	local near = vector.add(player_pos, vector.multiply(dir, 6))
	near.y = player_pos.y - 1
	local far = vector.add(near, vector.multiply(dir, distance))
	far.y = near.y

	local near_region = pipe_region(near)
	local far_region = pipe_region(far)
	local ok, err = evolve.capture_regions(name, { near_region, far_region }, "teleport pipe link")
	if not ok then
		return false, err
	end

	remove_link_at(near, far)
	build_pipe(near, vector.multiply(dir, -2))
	build_pipe(far, vector.multiply(dir, 2))

	table.insert(links, {
		a = vector.new(near),
		b = vector.new(far),
		owner = name,
		created = os.time(),
	})
	save_links()

	core.fix_light(near_region.minp, near_region.maxp)
	core.fix_light(far_region.minp, far_region.maxp)
	evolve.log_action(name, "pipe_link", near_region.minp, far_region.maxp, ("distance=%d"):format(distance))
	return true, S("Created linked teleport pipes @1 nodes apart.", distance)
end

core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.25 then
		return
	end
	timer = 0

	local now = core.get_gametime()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if (cooldowns[name] or 0) <= now then
			local destination = destination_for(player:get_pos())
			if destination then
				player:set_pos(destination)
				cooldowns[name] = now + 2
			end
		end
	end
end)

evolve.register_undo_hook(function(_, op)
	if op.label ~= "teleport pipe link" then
		return
	end
	local regions = op.regions or { op }
	local removed = false
	for i = #links, 1, -1 do
		if link_in_regions(links[i], regions) then
			table.remove(links, i)
			removed = true
		end
	end
	if removed then
		save_links()
	end
end)
