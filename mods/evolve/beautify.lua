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
	N.dirt = first_registered({ "mcl_core:dirt" }, N.grass)
	N.bush = first_registered({ "mcl_flowers:bush", "mcl_flowers:firefly_bush", "mcl_flowers:fern" }, nil)
	N.fern = first_registered({ "mcl_flowers:fern", "mcl_flowers:tallgrass" }, nil)
	N.tallgrass = first_registered({ "mcl_flowers:tallgrass", "mcl_flowers:fern" }, nil)
	N.oak_log = first_registered({ "mcl_trees:tree_oak" }, "mcl_core:tree")
	N.oak_leaves = first_registered({ "mcl_trees:leaves_oak" }, "mcl_core:leaves")
	N.oak_leaves_orphan = first_registered({ "mcl_trees:leaves_oak_orphan", "mcl_trees:leaves_oak" }, N.oak_leaves)
	N.birch_log = first_registered({ "mcl_trees:tree_birch" }, N.oak_log)
	N.birch_leaves = first_registered({ "mcl_trees:leaves_birch" }, N.oak_leaves)
	N.spruce_log = first_registered({ "mcl_trees:tree_spruce" }, N.oak_log)
	N.spruce_leaves = first_registered({ "mcl_trees:leaves_spruce" }, N.oak_leaves)
end

local flower_nodes = {
	"mcl_flowers:poppy",
	"mcl_flowers:dandelion",
	"mcl_flowers:oxeye_daisy",
	"mcl_flowers:tulip_orange",
	"mcl_flowers:tulip_pink",
	"mcl_flowers:tulip_red",
	"mcl_flowers:tulip_white",
	"mcl_flowers:allium",
	"mcl_flowers:azure_bluet",
	"mcl_flowers:blue_orchid",
	"mcl_flowers:cornflower",
	"mcl_flowers:lily_of_the_valley",
	"mcl_flowers:wildflowers_1",
	"mcl_flowers:pink_petals_1",
}

local function available_flowers()
	local nodes = {}
	for _, name in ipairs(flower_nodes) do
		if core.registered_nodes[name] then
			table.insert(nodes, name)
		end
	end
	return nodes
end

local function make_noise(center, radius, salt, spread_factor, octaves)
	return core.get_perlin({
		offset = 0,
		scale = 1,
		spread = {
			x = math.max(10, radius * spread_factor),
			y = math.max(10, radius * spread_factor),
			z = math.max(10, radius * spread_factor),
		},
		seed = 30011 + core.hash_node_position(center) + salt,
		octaves = octaves or 4,
		persist = 0.55,
		lacunarity = 2,
	})
end

local function surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local pos = vector.new(x, y, z)
		local node = core.get_node_or_nil(pos)
		if node then
			local def = core.registered_nodes[node.name]
			local above = core.get_node_or_nil(vector.offset(pos, 0, 1, 0))
			if def and def.walkable and above and above.name == "air" then
				return y, node.name
			end
		end
	end
	return nil
end

local function is_natural_ground(node_name)
	if not node_name then
		return false
	end
	if core.get_item_group(node_name, "grass_block") > 0 or core.get_item_group(node_name, "soil") > 0 then
		return true
	end
	return node_name == "mcl_core:dirt"
		or node_name == "mcl_core:coarse_dirt"
		or node_name == "mcl_core:podzol"
		or node_name == "mcl_core:mycelium"
		or node_name == "mcl_core:moss"
end

local function is_air(pos)
	local node = core.get_node_or_nil(pos)
	return node and node.name == "air"
end

local function can_modify(name, pos)
	return not core.is_protected(pos, name)
end

local function add_node(plan, pos, node, param2)
	if node and core.registered_nodes[node] then
		table.insert(plan.nodes, { pos = vector.new(pos), name = node, param2 = param2 or 0 })
	end
end

local function add_region(plan, minp, maxp)
	table.insert(plan.regions, { minp = vector.new(minp), maxp = vector.new(maxp) })
end

local function clear_volume(name, minp, maxp)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local pos = vector.new(x, y, z)
				if not can_modify(name, pos) then
					return false
				end
				if not is_air(pos) then
					return false
				end
			end
		end
	end
	return true
end

local function occupied_near(list, x, z, spacing)
	for _, item in ipairs(list) do
		local dx = x - item.x
		local dz = z - item.z
		local required = spacing + item.spacing
		if dx * dx + dz * dz < required * required then
			return true
		end
	end
	return false
end

local function choose_tree(noise_value)
	if noise_value < -0.22 and N.spruce_log and N.spruce_leaves then
		return { log = N.spruce_log, leaves = N.spruce_leaves, kind = "spruce" }
	elseif noise_value > 0.26 and N.birch_log and N.birch_leaves then
		return { log = N.birch_log, leaves = N.birch_leaves, kind = "round" }
	end
	return { log = N.oak_log, leaves = N.oak_leaves, kind = "round" }
end

local function plan_round_tree(name, plan, base, tree, pr)
	local height = pr:next(4, 7)
	local minp = vector.offset(base, -3, 1, -3)
	local maxp = vector.offset(base, 3, height + 3, 3)
	if not clear_volume(name, minp, maxp) then
		return false
	end

	add_region(plan, minp, maxp)
	for y = 1, height do
		add_node(plan, vector.offset(base, 0, y, 0), tree.log)
	end
	local top = base.y + height
	for y = top - 2, top + 1 do
		local radius = y == top + 1 and 1 or 2
		for z = -radius, radius do
			for x = -radius, radius do
				if not (x == 0 and z == 0 and y <= top)
					and not (math.abs(x) == radius and math.abs(z) == radius and pr:next(1, 3) == 1) then
					add_node(plan, vector.new(base.x + x, y, base.z + z), tree.leaves)
				end
			end
		end
	end
	add_node(plan, vector.new(base.x, top + 2, base.z), tree.leaves)
	return true
end

local function plan_spruce_tree(name, plan, base, tree, pr)
	local height = pr:next(6, 9)
	local minp = vector.offset(base, -3, 1, -3)
	local maxp = vector.offset(base, 3, height + 2, 3)
	if not clear_volume(name, minp, maxp) then
		return false
	end

	add_region(plan, minp, maxp)
	for y = 1, height do
		add_node(plan, vector.offset(base, 0, y, 0), tree.log)
	end
	for y = 3, height + 1 do
		local from_top = height + 1 - y
		local radius = math.max(1, math.min(3, math.floor(from_top / 2) + 1))
		for z = -radius, radius do
			for x = -radius, radius do
				if not (x == 0 and z == 0 and y <= height)
					and math.abs(x) + math.abs(z) <= radius + 1 then
					add_node(plan, vector.new(base.x + x, base.y + y, base.z + z), tree.leaves)
				end
			end
		end
	end
	add_node(plan, vector.new(base.x, base.y + height + 2, base.z), tree.leaves)
	return true
end

local function plan_shrub(name, plan, pos, pr)
	local minp = vector.offset(pos, -1, 0, -1)
	local maxp = vector.offset(pos, 1, 1, 1)
	if not clear_volume(name, minp, maxp) then
		return false
	end

	add_region(plan, minp, maxp)
	if N.bush and pr:next(1, 3) ~= 1 then
		add_node(plan, pos, N.bush, pr:next(0, 3))
		return true
	end

	add_node(plan, pos, N.oak_leaves_orphan)
	if pr:next(1, 2) == 1 then
		add_node(plan, vector.offset(pos, 1, 0, 0), N.oak_leaves_orphan)
	end
	if pr:next(1, 2) == 1 then
		add_node(plan, vector.offset(pos, 0, 0, 1), N.oak_leaves_orphan)
	end
	if pr:next(1, 4) == 1 then
		add_node(plan, vector.offset(pos, 0, 1, 0), N.oak_leaves_orphan)
	end
	return true
end

local function plan_flower(plan, pos, flowers, seed)
	if #flowers == 0 or not is_air(pos) then
		return false
	end
	local node = flowers[(math.abs(seed) % #flowers) + 1]
	add_region(plan, pos, pos)
	add_node(plan, pos, node, seed % 4)
	return true
end

local function make_plan(name, center, radius)
	local pr = PcgRandom(9109 + core.hash_node_position(center) + radius)
	local flowers = available_flowers()
	local tree_noise = make_noise(center, radius, 17, 0.55, 4)
	local shrub_noise = make_noise(center, radius, 31, 0.28, 3)
	local flower_noise = make_noise(center, radius, 47, 0.18, 3)
	local plan = { regions = {}, nodes = {}, counts = { trees = 0, shrubs = 0, flowers = 0 } }
	local placed = {}
	local min_y = center.y - 48
	local max_y = center.y + 48

	local tree_candidates = {}
	for z = center.z - radius, center.z + radius, 5 do
		for x = center.x - radius, center.x + radius, 5 do
			local dx = x - center.x
			local dz = z - center.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= radius - 3 then
				local n = tree_noise:get_2d({ x = x, y = z })
				local score = n - (dist / radius) * 0.08
				if score > 0.18 then
					table.insert(tree_candidates, { x = x, z = z, score = score, noise = n })
				end
			end
		end
	end
	table.sort(tree_candidates, function(a, b)
		return a.score > b.score
	end)

	local max_trees = math.max(3, math.min(40, math.floor(radius * radius / 180)))
	for _, candidate in ipairs(tree_candidates) do
		if plan.counts.trees >= max_trees then
			break
		end
		if not occupied_near(placed, candidate.x, candidate.z, 6) then
			local y, ground = surface_y(candidate.x, candidate.z, min_y, max_y)
			if y and is_natural_ground(ground) and can_modify(name, vector.new(candidate.x, y + 1, candidate.z)) then
				local tree = choose_tree(candidate.noise)
				local base = vector.new(candidate.x, y, candidate.z)
				local ok = tree.kind == "spruce"
					and plan_spruce_tree(name, plan, base, tree, pr)
					or plan_round_tree(name, plan, base, tree, pr)
				if ok then
					plan.counts.trees = plan.counts.trees + 1
					table.insert(placed, { x = candidate.x, z = candidate.z, spacing = 8 })
				end
			end
		end
	end

	for z = center.z - radius, center.z + radius, 3 do
		for x = center.x - radius, center.x + radius, 3 do
			local dx = x - center.x
			local dz = z - center.z
			if dx * dx + dz * dz <= radius * radius and not occupied_near(placed, x, z, 3) then
				local n = shrub_noise:get_2d({ x = x, y = z })
				if n > 0.24 then
					local y, ground = surface_y(x, z, min_y, max_y)
					if y and is_natural_ground(ground) and plan_shrub(name, plan, vector.new(x, y + 1, z), pr) then
						plan.counts.shrubs = plan.counts.shrubs + 1
						table.insert(placed, { x = x, z = z, spacing = 3 })
					end
				end
			end
		end
	end

	for z = center.z - radius, center.z + radius, 2 do
		for x = center.x - radius, center.x + radius, 2 do
			local dx = x - center.x
			local dz = z - center.z
			if dx * dx + dz * dz <= radius * radius and not occupied_near(placed, x, z, 1) then
				local n = flower_noise:get_2d({ x = x, y = z })
				if n > 0.16 or pr:next(1, 100) <= 3 then
					local y, ground = surface_y(x, z, min_y, max_y)
					if y and is_natural_ground(ground) and can_modify(name, vector.new(x, y + 1, z)) then
						local seed = math.floor(x * 92821 + z * 68917 + n * 10000)
						if plan_flower(plan, vector.new(x, y + 1, z), flowers, seed) then
							plan.counts.flowers = plan.counts.flowers + 1
						end
					end
				end
			end
		end
	end

	return plan
end

function evolve.beautify(name, radius)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end

	radius = evolve.clamp_number(radius, 4, evolve.settings.max_beautify_radius or 80)
	if not radius then
		return false, S("Invalid radius.")
	end

	refresh_nodes()
	local plan = make_plan(name, center, radius)
	if #plan.nodes == 0 then
		return false, S("No safe natural ground found to beautify.")
	end

	local ok, err = evolve.capture_regions(name, plan.regions, "beautify")
	if not ok then
		return false, err
	end

	for _, entry in ipairs(plan.nodes) do
		core.swap_node(entry.pos, { name = entry.name, param2 = entry.param2 or 0 })
	end

	local minp = vector.offset(center, -radius, -48, -radius)
	local maxp = vector.offset(center, radius, 64, radius)
	core.fix_light(minp, maxp)
	evolve.log_action(name, "beautify", minp, maxp, ("radius=%d trees=%d shrubs=%d flowers=%d"):format(radius, plan.counts.trees, plan.counts.shrubs, plan.counts.flowers))
	return true, S("Beautified radius @1 with @2 trees, @3 shrubs, and @4 flowers.", radius, plan.counts.trees, plan.counts.shrubs, plan.counts.flowers)
end
