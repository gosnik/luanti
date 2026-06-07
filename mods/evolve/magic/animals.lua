core.register_entity("evolve:magic_companion", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		textures = { "heart.png" },
		visual_size = { x = 0.9, y = 0.9 },
		glow = 8,
		static_save = false,
	},
	owner = nil,
	timer = 0,
	on_step = function(self, dtime)
		self.timer = self.timer + dtime
		if not self.owner then
			self.object:remove()
			return
		end
		local player = core.get_player_by_name(self.owner)
		if not player then
			self.object:remove()
			return
		end
		local pos = player:get_pos()
		local target = vector.offset(pos, 1.2, 1.6 + math.sin(self.timer * 3) * 0.25, 0.6)
		self.object:move_to(target, true)
	end,
})

function evolve.magic.summon_companion(player, seconds)
	if not evolve.magic.settings.animal_bell then
		return
	end
	local state = evolve.magic.get_player_state(player)
	if state.state.animal_entity then
		state.state.animal_entity:remove()
	end
	local obj = core.add_entity(vector.offset(player:get_pos(), 1, 1.5, 0), "evolve:magic_companion")
	if obj then
		obj:get_luaentity().owner = player:get_player_name()
		state.state.animal_entity = obj
		evolve.magic.give_effect(player, "friendly_animal", seconds or 180)
	end
end
