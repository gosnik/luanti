function evolve.magic.can_modify_pos(player, pos)
	if not player or not player:is_player() then
		return false
	end
	return not core.is_protected(pos, player:get_player_name())
end

function evolve.magic.is_safe_air(pos)
	local node = core.get_node_or_nil(pos)
	return node and node.name == "air"
end

function evolve.magic.is_natural_ground(pos)
	local node = core.get_node_or_nil(pos)
	if not node then
		return false
	end
	return core.get_item_group(node.name, "soil_flower") > 0
		or core.get_item_group(node.name, "soil_generic_plant") > 0
		or node.name == "mcl_core:dirt"
		or node.name == "mcl_core:dirt_with_grass"
end

function evolve.magic.find_safe_nearby_pos(pos, radius)
	for y = 0, radius do
		for x = -radius, radius do
			for z = -radius, radius do
				local p = vector.offset(pos, x, y, z)
				local feet = core.get_node_or_nil(p)
				local head = core.get_node_or_nil(vector.offset(p, 0, 1, 0))
				local ground = core.get_node_or_nil(vector.offset(p, 0, -1, 0))
				local ground_def = ground and core.registered_nodes[ground.name]
				if feet and head and ground_def
					and feet.name == "air"
					and head.name == "air"
					and ground_def.walkable then
					return p
				end
			end
		end
	end
	return pos
end
