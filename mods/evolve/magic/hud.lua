function evolve.magic.update_hud(player)
	local state = evolve.magic.get_player_state(player)
	local parts = {}
	local now = core.get_gametime()
	for effect_name, active in pairs(state.effects) do
		local def = evolve.magic.registered_effects[effect_name] or {}
		table.insert(parts, (def.description or effect_name) .. " " .. math.max(0, math.ceil(active.expires - now)) .. "s")
	end
	table.sort(parts)
	local text = table.concat(parts, " | ")
	if text == "" then
		if state.hud.status_id then
			player:hud_remove(state.hud.status_id)
			state.hud.status_id = nil
		end
		return
	end
	if not state.hud.status_id then
		state.hud.status_id = player:hud_add({
			hud_elem_type = "text",
			position = { x = 0.5, y = 0.08 },
			alignment = { x = 0, y = 0 },
			text = text,
			number = 0xFFE6FF,
			scale = { x = 100, y = 20 },
		})
	else
		player:hud_change(state.hud.status_id, "text", text)
	end
end

function evolve.magic.update_all_huds()
	for _, player in ipairs(core.get_connected_players()) do
		evolve.magic.update_hud(player)
	end
end
