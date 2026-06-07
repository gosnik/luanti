local storage = core.get_mod_storage()
evolve.magic.treasure_points = core.deserialize(storage:get_string("magic_treasure_points"), true) or {}

local function save()
	storage:set_string("magic_treasure_points", core.serialize(evolve.magic.treasure_points))
end

function evolve.magic.add_treasure_point(pos, name)
	table.insert(evolve.magic.treasure_points, {
		pos = vector.round(pos),
		name = name,
		radius = 80,
	})
	save()
end

function evolve.magic.remove_nearest_treasure(pos)
	local best_i
	local best_d = math.huge
	for i, point in ipairs(evolve.magic.treasure_points) do
		local d = vector.distance(pos, point.pos)
		if d < best_d then
			best_i = i
			best_d = d
		end
	end
	if best_i then
		local removed = table.remove(evolve.magic.treasure_points, best_i)
		save()
		return removed
	end
	return nil
end

function evolve.magic.twinkle_to_treasure(player)
	if not evolve.magic.settings.treasure_twinkle then
		return false
	end
	local pos = player:get_pos()
	local nearest
	local nearest_d = math.huge
	for _, point in ipairs(evolve.magic.treasure_points) do
		local d = vector.distance(pos, point.pos)
		if d <= (point.radius or 80) and d < nearest_d then
			nearest = point
			nearest_d = d
		end
	end
	if not nearest then
		core.chat_send_player(player:get_player_name(), "No treasure twinkles nearby.")
		return false
	end
	local dir = vector.normalize(vector.subtract(nearest.pos, pos))
	for i = 1, math.min(12, math.floor(nearest_d / 2)) do
		evolve.magic.spawn_stars(vector.add(pos, vector.multiply(dir, i * 2)), 4)
	end
	core.chat_send_player(player:get_player_name(), "Sparkles point toward " .. nearest.name .. "!")
	return true
end
