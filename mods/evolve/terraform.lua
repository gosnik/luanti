local S = evolve.S

local function first_registered(candidates, fallback)
	for _, node_name in ipairs(candidates) do
		if core.registered_nodes[node_name] then
			return node_name
		end
	end
	return fallback or "air"
end

local function sea_level()
	return tonumber(core.get_mapgen_setting("water_level")) or 0
end

local function smoothstep(value)
	value = math.max(0, math.min(1, value))
	return value * value * (3 - 2 * value)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function terrain_height(noise, detail_noise, edge_heights, center, x, z, radius, max_height)
	local dx = x - center.x
	local dz = z - center.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local n1 = noise:get_2d({ x = x, y = z })
	local n2 = detail_noise:get_2d({ x = x, y = z })
	local rolling = math.max(0, math.min(1, 0.55 + n1 * 0.34 + n2 * 0.16))
	local generated = sea_level() + rolling * max_height

	if edge_heights then
		local blend_width = math.max(8, math.floor(radius * 0.18))
		local from_edge = radius - dist
		if from_edge < blend_width then
			local edge_height = edge_heights[x .. "," .. z] or sea_level()
			local t = smoothstep(from_edge / blend_width)
			generated = lerp(edge_height, generated, t)
		end
	end

	return math.floor(generated + 0.5)
end

local terraform_jobs = {}

local function terrain_nodes()
	local top = first_registered({ "mcl_core:dirt_with_grass", "mcl_core:grass_path" }, "mcl_core:dirt")
	local filler = first_registered({ "mcl_core:dirt" }, top)
	local base = first_registered({ "mcl_core:stone", "mcl_core:cobble" }, filler)
	local water = first_registered({ "mcl_core:water_source" }, "air")
	return {
		top = core.get_content_id(top),
		filler = core.get_content_id(filler),
		base = core.get_content_id(base),
		water = core.get_content_id(water),
		air = core.get_content_id("air"),
	}
end

local function make_noise(center, radius)
	local broad = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(radius * 0.45, 24), y = math.max(radius * 0.45, 24), z = math.max(radius * 0.45, 24) },
		seed = 91741 + core.hash_node_position(center),
		octaves = 5,
		persist = 0.55,
		lacunarity = 2.0,
	})
	local detail = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(radius * 0.16, 12), y = math.max(radius * 0.16, 12), z = math.max(radius * 0.16, 12) },
		seed = 40231 + core.hash_node_position(center),
		octaves = 3,
		persist = 0.48,
		lacunarity = 2.0,
	})
	return broad, detail
end

local function existing_surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local node = core.get_node_or_nil(vector.new(x, y, z))
		if node then
			local def = core.registered_nodes[node.name]
			if def and def.walkable and node.name ~= "air" then
				return y
			end
		end
	end
	return sea_level()
end

local function sample_edge_heights(center, radius, min_y, max_y)
	local edge_heights = {}
	local blend_width = math.max(8, math.floor(radius * 0.18))
	local outer = radius
	local inner = math.max(0, radius - blend_width - 1)
	for z = center.z - radius, center.z + radius do
		for x = center.x - radius, center.x + radius do
			local dx = x - center.x
			local dz = z - center.z
			local d2 = dx * dx + dz * dz
			if d2 <= outer * outer and d2 >= inner * inner then
				edge_heights[x .. "," .. z] = existing_surface_y(x, z, min_y, max_y)
			end
		end
	end
	return edge_heights
end

local function write_chunk(job, cx, cz)
	local r = job.radius
	local minx = math.max(job.center.x - r, cx)
	local maxx = math.min(job.center.x + r, cx + job.chunk_size - 1)
	local minz = math.max(job.center.z - r, cz)
	local maxz = math.min(job.center.z + r, cz + job.chunk_size - 1)
	local minp = vector.new(minx, job.min_y, minz)
	local maxp = vector.new(maxx, job.max_y, maxz)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local changed = 0

	for z = minz, maxz do
		for x = minx, maxx do
			local dx = x - job.center.x
			local dz = z - job.center.z
			if dx * dx + dz * dz <= r * r then
				local target_y = terrain_height(job.noise, job.detail_noise, job.edge_heights, job.center, x, z, r, job.max_height)
				for y = job.min_y, job.max_y do
					local cid
					if y > target_y then
						cid = y <= job.water_level and job.nodes.water or job.nodes.air
					elseif y == target_y then
						cid = job.nodes.top
					elseif y >= target_y - 3 then
						cid = job.nodes.filler
					else
						cid = job.nodes.base
					end
					data[area:index(x, y, z)] = cid
					changed = changed + 1
				end
			end
		end
	end

	vm:set_data(data)
	vm:write_to_map(false)
	core.fix_light(minp, maxp)
	job.changed = job.changed + changed
end

local function start_async_terraform(name, center, radius, max_height)
	local water_level = sea_level()
	local chunk_size = math.max(8, evolve.settings.terraform_chunk_size)
	local min_y = math.min(water_level - 8, center.y - math.min(radius, 128))
	local max_y = math.max(water_level + max_height + 8, center.y + math.min(radius, 128))
	local start_x = center.x - radius
	local end_x = center.x + radius
	local start_z = center.z - radius
	local end_z = center.z + radius
	local chunks = {}

	for z = start_z, end_z, chunk_size do
		for x = start_x, end_x, chunk_size do
			local nearest_x = math.max(x, math.min(center.x, x + chunk_size - 1))
			local nearest_z = math.max(z, math.min(center.z, z + chunk_size - 1))
			local dx = nearest_x - center.x
			local dz = nearest_z - center.z
			if dx * dx + dz * dz <= radius * radius then
				table.insert(chunks, { x = x, z = z })
			end
		end
	end

	terraform_jobs[name] = {
		name = name,
		center = vector.new(center),
		radius = radius,
		max_height = max_height,
		water_level = water_level,
		min_y = min_y,
		max_y = max_y,
		chunk_size = chunk_size,
		chunks = chunks,
		index = 1,
		changed = 0,
		nodes = terrain_nodes(),
		edge_heights = sample_edge_heights(center, radius, min_y, max_y),
	}
	terraform_jobs[name].noise, terraform_jobs[name].detail_noise = make_noise(center, radius)

	core.chat_send_player(name, ("Started large terraform: radius %d, %d chunks. This is not undoable."):format(radius, #chunks))
	evolve.log_action(name, "terraform_async_start", vector.new(start_x, min_y, start_z), vector.new(end_x, max_y, end_z), ("radius=%d max_height=%d chunks=%d"):format(radius, max_height, #chunks))
	return true, S("Started large terraform radius @1 in @2 chunks.", radius, #chunks)
end

function evolve.terraform_status(name)
	local job = terraform_jobs[name]
	if not job then
		return true, S("No terraform job is running.")
	end
	return true, S("Terraform progress: @1/@2 chunks, about @3 nodes changed.",
		math.max(0, job.index - 1),
		#job.chunks,
		job.changed
	)
end

function evolve.terraform_cancel(name)
	local job = terraform_jobs[name]
	if not job then
		return false, S("No terraform job is running.")
	end
	terraform_jobs[name] = nil
	evolve.log_action(name, "terraform_async_cancel", vector.offset(job.center, -job.radius, job.min_y - job.center.y, -job.radius), vector.offset(job.center, job.radius, job.max_y - job.center.y, job.radius), ("radius=%d max_height=%d changed=%d"):format(job.radius, job.max_height, job.changed))
	return true, S("Cancelled terraform job after @1 chunks.", math.max(0, job.index - 1))
end

function evolve.terraform(name, radius, max_height)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end

	radius = evolve.clamp_number(radius, 1, evolve.settings.max_radius)
	if not radius then
		return false, S("Invalid radius.")
	end

	max_height = evolve.clamp_number(max_height, 0, 256)
	if not max_height then
		return false, S("Invalid max height.")
	end

	if terraform_jobs[name] then
		return false, S("You already have a terraform job running.")
	end

	if radius > evolve.settings.terraform_sync_radius then
		return start_async_terraform(name, center, radius, max_height)
	end

	local water_level = sea_level()
	local minp = vector.new(center.x - radius, math.min(water_level - 8, center.y - radius), center.z - radius)
	local maxp = vector.new(center.x + radius, math.max(water_level + max_height + 8, center.y + radius), center.z + radius)
	local volume = evolve.volume(minp, maxp)
	if volume > evolve.settings.max_volume then
		return false, S("Operation volume @1 exceeds limit @2.", volume, evolve.settings.max_volume)
	end

	local ok, err = evolve.capture(name, minp, maxp, "terraform terrain")
	if not ok then
		return false, err
	end

	local nodes = terrain_nodes()
	local edge_heights = sample_edge_heights(center, radius, minp.y, maxp.y)
	local noise, detail_noise = make_noise(center, radius)

	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local changed = 0

	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local dx = x - center.x
			local dz = z - center.z
			if dx * dx + dz * dz <= radius * radius then
				local target_y = terrain_height(noise, detail_noise, edge_heights, center, x, z, radius, max_height)
				for y = minp.y, maxp.y do
					local cid
					if y > target_y then
						cid = y <= water_level and nodes.water or nodes.air
					elseif y == target_y then
						cid = nodes.top
					elseif y >= target_y - 3 then
						cid = nodes.filler
					else
						cid = nodes.base
					end
					data[area:index(x, y, z)] = cid
					changed = changed + 1
				end
			end
		end
	end

	vm:set_data(data)
	vm:write_to_map(false)
	core.fix_light(minp, maxp)
	evolve.log_action(name, "terraform", minp, maxp, ("radius=%d max_height=%d changed=%d"):format(radius, max_height, changed))
	return true, S("Terraformed radius @1 with max height @2 above sea level.", radius, max_height)
end

core.register_globalstep(function()
	for name, job in pairs(terraform_jobs) do
		for _ = 1, evolve.settings.terraform_chunks_per_step do
			local chunk = job.chunks[job.index]
			if not chunk then
				terraform_jobs[name] = nil
				core.chat_send_player(name, ("Finished large terraform: changed about %d nodes."):format(job.changed))
				evolve.log_action(name, "terraform_async", vector.offset(job.center, -job.radius, job.min_y - job.center.y, -job.radius), vector.offset(job.center, job.radius, job.max_y - job.center.y, job.radius), ("radius=%d max_height=%d changed=%d"):format(job.radius, job.max_height, job.changed))
				break
			end
			write_chunk(job, chunk.x, chunk.z)
			job.index = job.index + 1
			if job.index % 100 == 0 then
				core.chat_send_player(name, ("Terraform progress: %d/%d chunks."):format(job.index - 1, #job.chunks))
			end
		end
	end
end)

local function orthogonal(dir)
	if dir.x ~= 0 then
		return vector.new(0, 0, 1)
	end
	return vector.new(1, 0, 0)
end

local function first_solid_below(pos)
	for y = pos.y + 3, pos.y - 8, -1 do
		local p = vector.new(pos.x, y, pos.z)
		local node = core.get_node_or_nil(p)
		if node then
			local def = core.registered_nodes[node.name]
			if def and def.walkable then
				return p
			end
		end
	end
	return vector.new(pos.x, pos.y - 1, pos.z)
end

function evolve.road(name, length, width, node_name)
	local start = evolve.player_pos(name)
	if not start then
		return false, S("Player not found.")
	end

	length = evolve.clamp_number(length, 1, evolve.settings.max_structure_size)
	width = evolve.clamp_number(width, 1, 12)
	if not length or not width then
		return false, S("Invalid road dimensions.")
	end

	node_name = evolve.validate_node(node_name or "mcl_core:cobble")
	if not node_name then
		return false, S("Unknown road node.")
	end

	local dir = evolve.facing_dir(name)
	local side = orthogonal(dir)
	local half = math.floor(width / 2)
	local end_center = vector.add(start, vector.multiply(dir, length - 1))
	local minp, maxp = evolve.sort_bounds(
		vector.add(vector.add(start, vector.multiply(side, -half)), vector.new(0, -2, 0)),
		vector.add(vector.add(end_center, vector.multiply(side, half)), vector.new(0, 4, 0))
	)

	local volume = evolve.volume(minp, maxp)
	if volume > evolve.settings.max_volume then
		return false, S("Operation volume @1 exceeds limit @2.", volume, evolve.settings.max_volume)
	end

	local ok, err = evolve.capture(name, minp, maxp, "road")
	if not ok then
		return false, err
	end

	local changed = 0
	for step = 0, length - 1 do
		local center = vector.add(start, vector.multiply(dir, step))
		for offset = -half, half do
			local target = vector.add(center, vector.multiply(side, offset))
			local ground = first_solid_below(target)
			core.set_node(ground, { name = node_name })
			core.set_node(vector.offset(ground, 0, 1, 0), { name = "air" })
			core.set_node(vector.offset(ground, 0, 2, 0), { name = "air" })
			changed = changed + 3
		end
	end

	core.fix_light(minp, maxp)
	evolve.log_action(name, "road", minp, maxp, ("length=%d width=%d node=%s"):format(length, width, node_name))
	return true, S("Built road, changed about @1 nodes.", changed)
end
