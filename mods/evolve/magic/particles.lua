local function particle(pos, texture, amount, spread, velocity, glow)
	if not evolve.magic.settings.particles then
		return
	end
	core.add_particlespawner({
		amount = amount or 8,
		time = 0.2,
		minpos = vector.offset(pos, -spread, 0, -spread),
		maxpos = vector.offset(pos, spread, spread * 2, spread),
		minvel = vector.new(-velocity, 0.2, -velocity),
		maxvel = vector.new(velocity, velocity + 0.5, velocity),
		minacc = vector.new(0, 0.1, 0),
		maxacc = vector.new(0, 0.4, 0),
		minexptime = 0.4,
		maxexptime = 1.2,
		minsize = 1,
		maxsize = 3,
		texture = texture,
		glow = glow or 5,
	})
end

function evolve.magic.spawn_sparkles(pos, amount)
	particle(pos, "mcl_particles_effect.png^[colorize:#ffd6ff:180", amount or 8, 0.5, 0.8, 8)
end

function evolve.magic.spawn_bubbles(pos, amount)
	particle(pos, "mcl_particles_bubble.png", amount or 8, 0.45, 0.4, 4)
end

function evolve.magic.spawn_petals(pos, amount)
	particle(pos, "mcl_flowers_tulip_pink.png", amount or 8, 0.7, 0.5, 5)
end

function evolve.magic.spawn_stars(pos, amount)
	particle(pos, "mcl_core_gold_nugget.png^[colorize:#fff4a8:120", amount or 30, 1.2, 1.5, 10)
end

function evolve.magic.spawn_rainbow(pos)
	local colors = { "#ff5555", "#ffaa00", "#ffff66", "#55ff55", "#55aaff", "#aa66ff" }
	for _, color in ipairs(colors) do
		particle(pos, "mcl_particles_effect.png^[colorize:" .. color .. ":180", 2, 0.25, 0.45, 8)
	end
end

function evolve.magic.sound(target, sound_name)
	if type(target) == "userdata" and target:is_player() then
		core.sound_play(sound_name, { to_player = target:get_player_name(), gain = 0.25 }, true)
	else
		core.sound_play(sound_name, { pos = target, gain = 0.25, max_hear_distance = 16 }, true)
	end
end
