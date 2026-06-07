local S = evolve.S
local F = core.formspec_escape

evolve.villagers = evolve.villagers or {}
evolve.villagers.forms = evolve.villagers.forms or {}

local role_order = {
	"fairy",
	"wizard",
	"builder",
	"pet_keeper",
	"princess",
	"rainbow_trader",
	"guard",
	"gardener",
}

local roles = {
	fairy = {
		title = "Fairy Villager",
		texture = "mcl_core_emerald.png^[colorize:#ff9cff:135",
		talk = "Tiny stars are hiding in ordinary places.",
	},
	wizard = {
		title = "Wizard Villager",
		texture = "mcl_potions_potion_overlay.png^[colorize:#8844ff:150",
		talk = "Magic is best when it is short, bright, and safe.",
	},
	builder = {
		title = "Builder Villager",
		texture = "default_wood.png^[colorize:#d5a15d:85",
		talk = "I can build a cozy little house nearby.",
	},
	pet_keeper = {
		title = "Pet Keeper",
		texture = "mcl_flowers_poppy.png^[colorize:#77ff99:80",
		talk = "Gentle animals make every village happier.",
	},
	princess = {
		title = "Princess Villager",
		texture = "mcl_core_emerald.png^[colorize:#ffd1f2:120",
		talk = "A kind quest is waiting for a brave helper.",
	},
	rainbow_trader = {
		title = "Rainbow Trader",
		texture = "mcl_core_emerald.png^[colorize:#55ddff:120",
		talk = "Bring me an emerald and I will trade something fun.",
	},
	guard = {
		title = "Guard Villager",
		texture = "default_steel_ingot.png^[colorize:#88bbff:90",
		talk = "I will watch this place and chase away monsters.",
	},
	gardener = {
		title = "Gardener Villager",
		texture = "mcl_flowers_tulip_pink.png^[colorize:#99ff99:80",
		talk = "A few flowers can change the whole path.",
	},
}

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
	N.floor = first_registered({ "mcl_core:cobble", "mcl_core:stone" }, "mcl_core:dirt")
	N.wood = first_registered({ "mcl_trees:wood_oak", "mcl_core:wood" }, N.floor)
	N.log = first_registered({ "mcl_trees:tree_oak", "mcl_core:tree" }, N.wood)
	N.glass = first_registered({ "mcl_core:glass" }, N.floor)
	N.torch = first_registered({ "mcl_torches:torch" }, nil)
	N.flower = first_registered({ "mcl_flowers:poppy", "mcl_flowers:dandelion", "mcl_flowers:tulip_pink" }, nil)
end

local function set(pos, node, param2)
	if node and core.registered_nodes[node] then
		core.swap_node(pos, { name = node, param2 = param2 or 0 })
	end
end

local function surface_y(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local pos = vector.new(x, y, z)
		local ground = core.get_node_or_nil(pos)
		local feet = core.get_node_or_nil(vector.offset(pos, 0, 1, 0))
		local head = core.get_node_or_nil(vector.offset(pos, 0, 2, 0))
		local def = ground and core.registered_nodes[ground.name]
		if def and def.walkable and feet and feet.name == "air" and head and head.name == "air" then
			return y
		end
	end
end

local function find_safe_spawn(pos)
	local y = surface_y(pos.x, pos.z, pos.y - 96, pos.y + 96)
	if not y then
		return nil
	end
	return vector.new(pos.x + 0.5, y + 1.01, pos.z + 0.5)
end

local function sparkle(pos, amount)
	core.add_particlespawner({
		amount = amount or 30,
		time = 0.35,
		minpos = vector.offset(pos, -0.45, 0.1, -0.45),
		maxpos = vector.offset(pos, 0.45, 1.8, 0.45),
		minvel = { x = -0.6, y = 0.2, z = -0.6 },
		maxvel = { x = 0.6, y = 1.1, z = 0.6 },
		minacc = { x = 0, y = -0.2, z = 0 },
		maxacc = { x = 0, y = 0.1, z = 0 },
		minexptime = 0.45,
		maxexptime = 1.2,
		minsize = 1.4,
		maxsize = 3.0,
		texture = "mcl_particles_effect.png^[colorize:#ffccff:150",
		glow = 8,
	})
end

local function teleport_delay()
	local min_time = math.max(10, evolve.settings.evolve_villagers_teleport_min_time or 90)
	local max_time = math.max(min_time, evolve.settings.evolve_villagers_teleport_max_time or 180)
	return math.random(math.floor(min_time), math.floor(max_time))
end

local function random_role(pos)
	return role_order[(core.hash_node_position(vector.round(pos)) % #role_order) + 1]
end

local function random_near(pos, min_radius, max_radius)
	local radius = math.random(min_radius, max_radius)
	local angle = math.random() * math.pi * 2
	return vector.new(
		math.floor(pos.x + math.cos(angle) * radius + 0.5),
		math.floor(pos.y + 0.5),
		math.floor(pos.z + math.sin(angle) * radius + 0.5)
	)
end

local function safe_spawn_near_player(player)
	local player_pos = player:get_pos()
	for _ = 1, 18 do
		local candidate = random_near(player_pos, 8, 24)
		local spawn = find_safe_spawn(candidate)
		if spawn and vector.distance(spawn, player_pos) <= 32 then
			return spawn
		end
	end
end

local function safe_spawn_near_any_player()
	local players = core.get_connected_players()
	if #players == 0 then
		return nil
	end
	local start = math.random(1, #players)
	for i = 0, #players - 1 do
		local player = players[((start + i - 1) % #players) + 1]
		local spawn = safe_spawn_near_player(player)
		if spawn then
			return spawn
		end
	end
end

local function add_evolve_villager(pos, role, data)
	data = data or {}
	data.role = role or data.role or random_role(pos)
	data.magical = data.magical ~= false
	data.teleport_after = data.teleport_after or teleport_delay()
	data.arrived_at = data.arrived_at or core.get_gametime()
	local obj = core.add_entity(pos, "evolve:villager", core.serialize(data))
	if obj then
		sparkle(pos, 38)
	end
	return obj
end

local passive_animals = {
	"mobs_mc:cow",
	"mobs_mc:pig",
	"mobs_mc:sheep",
	"mobs_mc:chicken",
	"mobs_mc:rabbit",
	"mobs_mc:cat",
	"mobs_mc:parrot",
}

local function give_item(player, item)
	local inv = player:get_inventory()
	if inv and inv:room_for_item("main", item) then
		inv:add_item("main", item)
		return true
	end
	core.add_item(player:get_pos(), item)
	return false
end

local function show_message(player, text)
	core.chat_send_player(player:get_player_name(), text)
end

local function spawn_pet(pos)
	local available = {}
	for _, name in ipairs(passive_animals) do
		if core.registered_entities[name] then
			table.insert(available, name)
		end
	end
	if #available == 0 then
		return false
	end
	local animal = available[(core.hash_node_position(vector.round(pos)) % #available) + 1]
	local obj = core.add_entity(vector.offset(pos, 1, 0, 1), animal, core.serialize({ persistent = true }))
	return obj ~= nil
end

local function give_wizard_power(player)
	if not evolve.magic or not evolve.magic.give_effect then
		give_item(player, "evolve:sparkle_dust 3")
		return "The magic system is resting, so you received sparkle dust instead."
	end
	local effects = {
		{ name = "fairy_wings", duration = 20 },
		{ name = "rainbow_trail", duration = 20 },
		{ name = "bubble_bounce", duration = 20 },
		{ name = "twinkle_light", duration = 45 },
		{ name = "mermaid_bubble", duration = 45 },
	}
	local choice = effects[math.random(1, #effects)]
	evolve.magic.give_effect(player, choice.name, choice.duration, {})
	return "The Wizard Villager gave you a temporary power."
end

local function plant_flowers(center, owner)
	refresh_nodes()
	if not N.flower then
		return 0
	end
	local count = 0
	for dz = -4, 4 do
		for dx = -4, 4 do
			if dx * dx + dz * dz <= 16 and math.random(1, 3) == 1 then
				local x = math.floor(center.x + dx + 0.5)
				local z = math.floor(center.z + dz + 0.5)
				local y = surface_y(x, z, center.y - 8, center.y + 8)
				if y then
					local pos = vector.new(x, y + 1, z)
					if core.get_node(pos).name == "air" and not core.is_protected(pos, owner) then
						set(pos, N.flower, math.random(0, 3))
						count = count + 1
					end
				end
			end
		end
	end
	return count
end

local function build_small_house(center, owner)
	refresh_nodes()
	local x0 = math.floor(center.x + 0.5)
	local z0 = math.floor(center.z + 0.5)
	local y = surface_y(x0, z0, center.y - 16, center.y + 16)
	if not y then
		return false, "No safe ground found for the house."
	end
	local minp = vector.new(x0 - 3, y, z0 - 3)
	local maxp = vector.new(x0 + 3, y + 5, z0 + 3)
	for z = minp.z, maxp.z do
		for yy = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				if core.is_protected(vector.new(x, yy, z), owner) then
					return false, "That house spot is protected."
				end
			end
		end
	end
	local ok, err = evolve.capture(owner, minp, maxp, "builder villager house")
	if not ok then
		return false, err
	end
	for z = z0 - 3, z0 + 3 do
		for x = x0 - 3, x0 + 3 do
			set(vector.new(x, y, z), N.floor)
			for yy = y + 1, y + 4 do
				set(vector.new(x, yy, z), N.air)
			end
		end
	end
	for yy = y + 1, y + 3 do
		for x = x0 - 3, x0 + 3 do
			set(vector.new(x, yy, z0 - 3), N.wood)
			set(vector.new(x, yy, z0 + 3), N.wood)
		end
		for z = z0 - 3, z0 + 3 do
			set(vector.new(x0 - 3, yy, z), N.wood)
			set(vector.new(x0 + 3, yy, z), N.wood)
		end
	end
	for _, p in ipairs({
		vector.new(x0 - 3, y + 1, z0 - 3),
		vector.new(x0 + 3, y + 1, z0 - 3),
		vector.new(x0 - 3, y + 1, z0 + 3),
		vector.new(x0 + 3, y + 1, z0 + 3),
	}) do
		for yy = 0, 3 do
			set(vector.offset(p, 0, yy, 0), N.log)
		end
	end
	for z = z0 - 4, z0 + 4 do
		for x = x0 - 4, x0 + 4 do
			set(vector.new(x, y + 4, z), N.wood)
		end
	end
	set(vector.new(x0, y + 1, z0 - 3), N.air)
	set(vector.new(x0, y + 2, z0 - 3), N.air)
	set(vector.new(x0 - 2, y + 2, z0 - 3), N.glass)
	set(vector.new(x0 + 2, y + 2, z0 + 3), N.glass)
	if N.torch then
		set(vector.new(x0, y + 2, z0 + 2), N.torch)
	end
	core.fix_light(minp, maxp)
	return true, "The Builder Villager made a small house."
end

local function rainbow_trade(player)
	local inv = player:get_inventory()
	if not inv then
		return "I cannot find your bag."
	end
	local price = ItemStack("mcl_core:emerald")
	if not inv:contains_item("main", price) then
		return "Bring me one emerald and I will trade a fun item."
	end
	inv:remove_item("main", price)
	local items = {
		"evolve:sparkle_dust 8",
		"evolve:star_popper",
		"evolve:rainbow_ribbon",
		"mcl_fireworks:rocket_1 3",
	}
	give_item(player, items[math.random(1, #items)])
	return "The Rainbow Trader swapped one emerald for something fun."
end

local quests = {
	"Quest: Find three flowers and bring them to a garden.",
	"Quest: Visit a castle tower and wave from the top.",
	"Quest: Follow a coin trail and report what you find.",
	"Quest: Help a pet find a cozy home.",
	"Quest: Plant flowers near a path for other players.",
}

local function role_action(entity, player, action)
	local role = roles[entity.role] or roles.fairy
	local pname = player:get_player_name()
	if action == "talk" then
		show_message(player, role.title .. ": " .. role.talk)
	elseif action == "magic" then
		if entity.role == "fairy" then
			give_item(player, "evolve:sparkle_dust 6")
			show_message(player, "The Fairy Villager gave you sparkle dust.")
		elseif entity.role == "wizard" then
			show_message(player, give_wizard_power(player))
		elseif entity.role == "rainbow_trader" then
			show_message(player, rainbow_trade(player))
		elseif entity.role == "pet_keeper" then
			show_message(player, spawn_pet(entity.object:get_pos()) and "The Pet Keeper called a friendly animal." or "No friendly animals are available right now.")
		elseif entity.role == "gardener" then
			show_message(player, ("The Gardener planted %d flowers."):format(plant_flowers(entity.object:get_pos(), pname)))
		elseif entity.role == "guard" then
			entity.guard_center = vector.round(entity.object:get_pos())
			entity.guard_radius = 18
			show_message(player, "The Guard Villager is watching this area.")
		elseif entity.role == "princess" then
			show_message(player, quests[math.random(1, #quests)])
		else
			show_message(player, role.title .. " smiles and gives you sparkle dust.")
			give_item(player, "evolve:sparkle_dust 2")
		end
	elseif action == "build" then
		if entity.role == "builder" then
			local dir = player:get_look_dir()
			local target = vector.add(player:get_pos(), vector.multiply(dir, 6))
			local ok, msg = build_small_house(target, pname)
			show_message(player, msg)
		elseif entity.role == "gardener" then
			show_message(player, ("The Gardener planted %d flowers."):format(plant_flowers(entity.object:get_pos(), pname)))
		elseif entity.role == "pet_keeper" then
			show_message(player, spawn_pet(entity.object:get_pos()) and "The Pet Keeper brought a friendly animal." or "No friendly animals are available right now.")
		else
			show_message(player, role.title .. ": I do not build, but I can still help.")
		end
	elseif action == "follow" then
		entity.follow_player = pname
		entity.stay_here = false
		show_message(player, role.title .. " will follow you.")
	elseif action == "stay" then
		entity.follow_player = nil
		entity.stay_here = true
		entity.home = vector.round(entity.object:get_pos())
		if entity.role == "guard" then
			entity.guard_center = vector.new(entity.home)
			entity.guard_radius = 18
		end
		show_message(player, role.title .. " will stay here.")
	end
end

local function formspec_for(entity)
	local role = roles[entity.role] or roles.fairy
	return table.concat({
		"formspec_version[4]",
		"size[8,5.4]",
		"label[0.4,0.35;", F(role.title), "]",
		"textarea[0.4,0.8;7.2,1.1;;;", F(role.talk), "]",
		"button[0.5,2.0;2.1,0.8;talk;Talk]",
		"button[2.9,2.0;2.1,0.8;magic;Give me magic]",
		"button[5.3,2.0;2.1,0.8;build;Build something]",
		"button[1.6,3.2;2.1,0.8;follow;Follow me]",
		"button[4.1,3.2;2.1,0.8;stay;Stay here]",
		"button_exit[2.9,4.3;2.1,0.7;close;Close]",
	})
end

local function apply_role_visual(entity)
	local role = roles[entity.role] or roles.fairy
	entity.object:set_properties({
		textures = { role.texture },
		nametag = role.title,
		nametag_color = "#ffffff",
	})
end

core.register_craftitem("evolve:sparkle_dust", {
	description = "Sparkle Dust",
	inventory_image = "mcl_mobitems_blaze_powder.png^[colorize:#ffb7ff:125",
	stack_max = 64,
})

core.register_entity("evolve:villager", {
	name = "evolve:villager",
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = { -0.3, 0, -0.3, 0.3, 1.8, 0.3 },
		selectionbox = { -0.35, 0, -0.35, 0.35, 1.9, 0.35 },
		visual = "upright_sprite",
		visual_size = { x = 1, y = 2 },
		textures = { "mcl_core_emerald.png^[colorize:#ff9cff:135" },
		hp_max = 20,
		static_save = true,
	},
	role = "fairy",
	stay_here = true,
	timer = 0,
	guard_timer = 0,

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		self.role = data.role or self.role or "fairy"
		self.follow_player = data.follow_player
		self.stay_here = data.stay_here ~= false
		self.home = data.home
		self.guard_center = data.guard_center
		self.guard_radius = data.guard_radius or 18
		self.magical = data.magical ~= false
		self.arrived_at = data.arrived_at or core.get_gametime()
		self.teleport_after = data.teleport_after or teleport_delay()
		apply_role_visual(self)
		if self.magical then
			sparkle(self.object:get_pos(), 22)
		end
	end,

	get_staticdata = function(self)
		return core.serialize({
			role = self.role,
			follow_player = self.follow_player,
			stay_here = self.stay_here,
			home = self.home,
			guard_center = self.guard_center,
			guard_radius = self.guard_radius,
			magical = self.magical,
			arrived_at = self.arrived_at,
			teleport_after = self.teleport_after,
		})
	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end
		local name = clicker:get_player_name()
		evolve.villagers.forms[name] = self
		core.show_formspec(name, "evolve:villager_menu", formspec_for(self))
	end,

	on_step = function(self, dtime)
		self.timer = self.timer + dtime
		if self.timer >= 0.4 then
			self.timer = 0
			if self.follow_player then
				local player = core.get_player_by_name(self.follow_player)
				local pos = self.object:get_pos()
				local target = player and player:get_pos()
				if target then
					local dist = vector.distance(pos, target)
					if dist > 2 and dist < 24 then
						local dir = vector.direction(pos, target)
						self.object:set_velocity({ x = dir.x * 1.8, y = self.object:get_velocity().y, z = dir.z * 1.8 })
						self.object:set_yaw(math.atan2(dir.z, dir.x) - math.pi / 2)
					else
						self.object:set_velocity({ x = 0, y = self.object:get_velocity().y, z = 0 })
					end
				end
			elseif self.stay_here then
				local vel = self.object:get_velocity()
				self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
			end
		end

		if self.role == "guard" then
			self.guard_timer = self.guard_timer + dtime
			if self.guard_timer >= 2 then
				self.guard_timer = 0
				local center = self.guard_center or vector.round(self.object:get_pos())
				for _, obj in ipairs(core.get_objects_inside_radius(center, self.guard_radius or 18)) do
					local ent = obj:get_luaentity()
					if ent and ent.name ~= "evolve:villager" and (ent.type == "monster" or ent._spawn_category == "monster") then
						obj:remove()
					end
				end
			end
		end

		if self.magical and self.arrived_at and core.get_gametime() - self.arrived_at >= self.teleport_after then
			local old_pos = self.object:get_pos()
			local new_pos = safe_spawn_near_any_player()
			if new_pos then
				sparkle(old_pos, 34)
				self.object:set_pos(new_pos)
				self.object:set_velocity({ x = 0, y = 0, z = 0 })
				self.home = vector.round(new_pos)
				self.guard_center = self.role == "guard" and vector.new(self.home) or self.guard_center
				self.follow_player = nil
				self.stay_here = true
				self.arrived_at = core.get_gametime()
				self.teleport_after = teleport_delay()
				sparkle(new_pos, 42)
			else
				self.arrived_at = core.get_gametime()
				self.teleport_after = teleport_delay()
			end
		end
	end,
})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "evolve:villager_menu" or not player then
		return false
	end
	local entity = evolve.villagers.forms[player:get_player_name()]
	if not entity or not entity.object then
		return true
	end
	for _, action in ipairs({ "talk", "magic", "build", "follow", "stay" }) do
		if fields[action] then
			role_action(entity, player, action)
			return true
		end
	end
	return true
end)

function evolve.spawn_evolve_villager(name, role_name)
	local player = core.get_player_by_name(name)
	if not player then
		return false, S("Player not found.")
	end
	role_name = role_name or "fairy"
	if not roles[role_name] then
		return false, S("Unknown Evolve villager role.")
	end
	local dir = player:get_look_dir()
	local pos = vector.add(player:get_pos(), vector.multiply(dir, 3))
	local spawn = find_safe_spawn(vector.round(pos)) or pos
	local obj = add_evolve_villager(spawn, role_name, { stay_here = true, home = vector.round(spawn), magical = true })
	if not obj then
		return false, S("Could not spawn Evolve villager.")
	end
	evolve.log_action(name, "evolve_villager", vector.round(spawn), vector.round(spawn), "role=" .. role_name)
	return true, S("Spawned @1.", roles[role_name].title)
end

function evolve.populate_evolve_villagers(name, radius, count)
	local center = evolve.player_pos(name)
	if not center then
		return false, S("Player not found.")
	end
	radius = evolve.clamp_number(radius, 4, evolve.settings.max_evolve_villager_radius or 128)
	count = evolve.clamp_number(count or #role_order, 1, evolve.settings.max_evolve_villager_count or 64)
	if not radius or not count then
		return false, S("Invalid Evolve villager area.")
	end

	local minp = vector.offset(center, -radius, -96, -radius)
	local maxp = vector.offset(center, radius, 96, radius)
	core.load_area(minp, maxp)

	local noise = core.get_perlin({
		offset = 0,
		scale = 1,
		spread = { x = math.max(14, radius * 0.34), y = math.max(14, radius * 0.34), z = math.max(14, radius * 0.34) },
		seed = 89131 + core.hash_node_position(center),
		octaves = 4,
		persist = 0.55,
		lacunarity = 2,
	})
	local candidates = {}
	local step = math.max(3, math.floor(radius / 8))
	for z = center.z - radius, center.z + radius, step do
		for x = center.x - radius, center.x + radius, step do
			local dx = x - center.x
			local dz = z - center.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= radius then
				table.insert(candidates, {
					pos = vector.new(x, center.y, z),
					score = noise:get_2d({ x = x, y = z }) - dist / radius * 0.05,
				})
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)

	local spawned = 0
	local placed = {}
	for _, candidate in ipairs(candidates) do
		if spawned >= count then
			break
		end
		local spawn = find_safe_spawn(candidate.pos)
		if spawn then
			local ok = true
			for _, other in ipairs(placed) do
				if vector.distance(spawn, other) < 4 then
					ok = false
					break
				end
			end
			if ok then
				local role = role_order[(spawned % #role_order) + 1]
				local obj = add_evolve_villager(spawn, role, { stay_here = true, home = vector.round(spawn), magical = true })
				if obj then
					table.insert(placed, spawn)
					spawned = spawned + 1
				end
			end
		end
	end

	evolve.log_action(name, "evolve_villagers", minp, maxp, ("radius=%d requested=%d spawned=%d"):format(radius, count, spawned))
	return true, S("Spawned @1 Evolve villagers.", spawned)
end

local ambient_timer = 0

local function nearby_evolve_villager_count(pos, radius)
	local count = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local entity = obj:get_luaentity()
		if entity and entity.name == "evolve:villager" then
			count = count + 1
		end
	end
	return count
end

local function maybe_spawn_ambient_for(player)
	local limit = math.max(0, evolve.settings.evolve_villagers_ambient_nearby_limit or 2)
	if limit == 0 then
		return
	end
	local pos = player:get_pos()
	if nearby_evolve_villager_count(pos, 40) >= limit then
		return
	end
	local spawn = safe_spawn_near_player(player)
	if not spawn then
		return
	end
	local role = random_role(vector.add(spawn, { x = math.random(-20, 20), y = 0, z = math.random(-20, 20) }))
	add_evolve_villager(spawn, role, { stay_here = true, home = vector.round(spawn), magical = true })
end

core.register_globalstep(function(dtime)
	if not evolve.settings.evolve_villagers_ambient_enable then
		return
	end
	ambient_timer = ambient_timer + dtime
	local interval = math.max(5, evolve.settings.evolve_villagers_ambient_interval or 75)
	if ambient_timer < interval then
		return
	end
	ambient_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		maybe_spawn_ambient_for(player)
	end
end)
