evolve.magic.registered_effects = evolve.magic.registered_effects or {}

function evolve.magic.get_player_state(player)
	local name = player:get_player_name()
	evolve.magic.players[name] = evolve.magic.players[name] or {
		effects = {},
		cooldowns = {},
		hud = {},
		state = {},
	}
	return evolve.magic.players[name]
end

function evolve.magic.register_effect(name, def)
	evolve.magic.registered_effects[name] = def
end

function evolve.magic.has_effect(player, effect_name)
	local state = evolve.magic.get_player_state(player)
	local effect = state.effects[effect_name]
	return effect and effect.expires > core.get_gametime()
end

function evolve.magic.can_use(player, effect_name)
	local state = evolve.magic.get_player_state(player)
	local expires = state.cooldowns[effect_name] or 0
	if expires > core.get_gametime() then
		return false, math.ceil(expires - core.get_gametime())
	end
	return true
end

function evolve.magic.set_cooldown(player, effect_name, seconds)
	evolve.magic.get_player_state(player).cooldowns[effect_name] = core.get_gametime() + seconds
end

function evolve.magic.give_effect(player, effect_name, duration, params)
	local def = evolve.magic.registered_effects[effect_name]
	if not def then
		return false
	end
	local state = evolve.magic.get_player_state(player)
	if not state.effects[effect_name] and def.on_start then
		def.on_start(player, params or {})
	end
	state.effects[effect_name] = {
		expires = core.get_gametime() + (duration or def.duration or 10),
		params = params or {},
	}
	evolve.magic.update_hud(player)
	return true
end

function evolve.magic.clear_effect(player, effect_name)
	local state = evolve.magic.get_player_state(player)
	local active = state.effects[effect_name]
	if not active then
		return
	end
	local def = evolve.magic.registered_effects[effect_name]
	state.effects[effect_name] = nil
	if def and def.on_stop then
		def.on_stop(player, active.params or {})
	end
	evolve.magic.recompute_physics(player)
	evolve.magic.update_hud(player)
end

function evolve.magic.clear_all_effects(player)
	local state = evolve.magic.get_player_state(player)
	for effect_name in pairs(table.copy(state.effects)) do
		evolve.magic.clear_effect(player, effect_name)
	end
	if state.state.original_properties then
		player:set_properties(state.state.original_properties)
		state.state.original_properties = nil
	end
	if state.state.light_entity then
		state.state.light_entity:remove()
		state.state.light_entity = nil
	end
	if state.state.animal_entity then
		state.state.animal_entity:remove()
		state.state.animal_entity = nil
	end
	evolve.magic.clear_temporary_nodes(player:get_player_name())
	player:set_physics_override({ speed = 1, jump = 1, gravity = 1 })
	evolve.magic.update_hud(player)
end

function evolve.magic.recompute_physics(player)
	local jump = 1
	local gravity = 1
	if evolve.magic.has_effect(player, "bubble_bounce") then
		jump = jump * 1.6
	end
	if evolve.magic.has_effect(player, "fairy_wings") then
		local vel = player:get_velocity()
		if vel and vel.y < 0 then
			gravity = gravity * 0.28
		end
	end
	player:set_physics_override({ speed = 1, jump = jump, gravity = gravity })
end

function evolve.magic.step_effects(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local state = evolve.magic.get_player_state(player)
		local now = core.get_gametime()
		for effect_name, active in pairs(table.copy(state.effects)) do
			if active.expires <= now then
				evolve.magic.clear_effect(player, effect_name)
			else
				local def = evolve.magic.registered_effects[effect_name]
				if def and def.on_step then
					def.on_step(player, dtime, active.params or {})
				end
			end
		end
		evolve.magic.recompute_physics(player)
	end
	evolve.magic.step_temporary_nodes()
end

function evolve.magic.activate_effect_item(player, effect_name)
	local def = evolve.magic.registered_effects[effect_name]
	if not def then
		return false
	end
	local ok, remaining = evolve.magic.can_use(player, effect_name)
	if not ok then
		core.chat_send_player(player:get_player_name(), "Magic is resting for " .. remaining .. "s.")
		return false
	end
	evolve.magic.give_effect(player, effect_name, def.duration, {})
	evolve.magic.set_cooldown(player, effect_name, def.cooldown or 3)
	return true
end

local step_timer = 0
local hud_timer = 0
core.register_globalstep(function(dtime)
	step_timer = step_timer + dtime
	hud_timer = hud_timer + dtime
	if step_timer >= 0.1 then
		step_timer = 0
		evolve.magic.step_effects(0.1)
	end
	if hud_timer >= 1 then
		hud_timer = 0
		evolve.magic.update_all_huds()
	end
end)

core.register_on_leaveplayer(function(player)
	evolve.magic.clear_all_effects(player)
	evolve.magic.players[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
	evolve.magic.clear_all_effects(player)
end)
