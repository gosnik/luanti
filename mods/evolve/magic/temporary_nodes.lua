evolve.magic.temporary_nodes = evolve.magic.temporary_nodes or {}

core.register_node("evolve:temporary_cloud", {
	description = "Temporary Cloud",
	tiles = { "default_glass.png^[colorize:#ffffff:120" },
	drawtype = "glasslike",
	use_texture_alpha = "blend",
	sunlight_propagates = true,
	paramtype = "light",
	walkable = true,
	pointable = false,
	diggable = false,
	buildable_to = false,
	groups = { not_in_creative_inventory = 1 },
})

local function key(pos)
	return core.pos_to_string(vector.round(pos))
end

local function count_owner(owner)
	local count = 0
	for _, rec in pairs(evolve.magic.temporary_nodes) do
		if rec.owner == owner then
			count = count + 1
		end
	end
	return count
end

function evolve.magic.add_temporary_cloud(player, pos, seconds)
	if not evolve.magic.settings.cloud_wand then
		return false
	end
	local name = player:get_player_name()
	if count_owner(name) >= evolve.magic.settings.max_clouds_per_player then
		return false
	end
	pos = vector.round(pos)
	if not evolve.magic.can_modify_pos(player, pos) or not evolve.magic.is_safe_air(pos) then
		return false
	end
	core.set_node(pos, { name = "evolve:temporary_cloud" })
	evolve.magic.temporary_nodes[key(pos)] = {
		pos = vector.new(pos),
		node = "evolve:temporary_cloud",
		restore = "air",
		expires = core.get_gametime() + (seconds or 10),
		owner = name,
	}
	return true
end

function evolve.magic.step_temporary_nodes()
	local now = core.get_gametime()
	for id, rec in pairs(evolve.magic.temporary_nodes) do
		if rec.expires <= now then
			local node = core.get_node_or_nil(rec.pos)
			if node and node.name == rec.node then
				core.set_node(rec.pos, { name = rec.restore or "air" })
			end
			evolve.magic.temporary_nodes[id] = nil
		end
	end
end

function evolve.magic.clear_temporary_nodes(owner)
	for id, rec in pairs(evolve.magic.temporary_nodes) do
		if not owner or rec.owner == owner then
			local node = core.get_node_or_nil(rec.pos)
			if node and node.name == rec.node then
				core.set_node(rec.pos, { name = rec.restore or "air" })
			end
			evolve.magic.temporary_nodes[id] = nil
		end
	end
end
