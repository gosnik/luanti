local S = evolve.S

local help = table.concat({
	"Evolve commands:",
	"/ev help",
	"/ev undo",
	"/ev terraform <radius> <max_height>",
	"/ev terraform_status",
	"/ev terraform_cancel",
	"/ev road <length> <width> [node]",
	"/ev treasure <area> <amount> [tier]",
	"/ev hut",
	"/ev village <small|medium|large>",
	"/ev city <small|medium|large>",
	"/ev villagers <radius> <count> [area_name]",
	"/ev evolve_villagers <radius> [count]",
	"/ev evolve_villager <role>",
	"/ev animals <radius> [count]",
	"/ev charm_scatter <radius> <count>",
	"/ev beautify <radius>",
	"/ev mushroom_kingdom <area>",
	"/ev pipe_link [distance]",
	"/ev castle [small|medium|large]",
}, "\n")

local function dispatch(name, param)
	local ok, err = evolve.require_priv(name)
	if not ok then
		return false, err
	end

	local args = evolve.parse_args(param or "")
	local cmd = args[1] or "help"

	if cmd == "help" then
		return true, help
	elseif cmd == "undo" then
		return evolve.undo(name)
	elseif cmd == "terraform" then
		if not args[2] or not args[3] then
			return false, S("Usage: /ev terraform <radius> <max_height>")
		end
		return evolve.terraform(name, args[2], args[3])
	elseif cmd == "terraform_status" then
		return evolve.terraform_status(name)
	elseif cmd == "terraform_cancel" then
		return evolve.terraform_cancel(name)
	elseif cmd == "road" then
		if not args[2] or not args[3] then
			return false, S("Usage: /ev road <length> <width> [node]")
		end
		return evolve.road(name, args[2], args[3], args[4])
	elseif cmd == "treasure" then
		if not args[2] or not args[3] then
			return false, S("Usage: /ev treasure <area> <amount> [tier]")
		end
		return evolve.scatter_treasure(name, args[2], args[3], args[4])
	elseif cmd == "hut" then
		return evolve.place_hut(name)
	elseif cmd == "village" then
		return evolve.place_village(name, args[2] or "small")
	elseif cmd == "city" then
		return evolve.place_city(name, args[2] or "small")
	elseif cmd == "villagers" then
		if not args[2] or not args[3] then
			return false, S("Usage: /ev villagers <radius> <count> [area_name]")
		end
		return evolve.assign_villagers(name, args[2], args[3], args[4])
	elseif cmd == "evolve_villagers" or cmd == "magic_villagers" then
		if not args[2] then
			return false, S("Usage: /ev evolve_villagers <radius> [count]")
		end
		return evolve.populate_evolve_villagers(name, args[2], args[3])
	elseif cmd == "evolve_villager" or cmd == "magic_villager" then
		if not args[2] then
			return false, S("Usage: /ev evolve_villager <fairy|wizard|builder|pet_keeper|princess|rainbow_trader|guard|gardener>")
		end
		return evolve.spawn_evolve_villager(name, args[2])
	elseif cmd == "animals" or cmd == "populate_animals" then
		if not args[2] then
			return false, S("Usage: /ev animals <radius> [count]")
		end
		return evolve.populate_animals(name, args[2], args[3])
	elseif cmd == "charm_scatter" or cmd == "scatter_charms" then
		if not args[2] or not args[3] then
			return false, S("Usage: /ev charm_scatter <radius> <count>")
		end
		if not evolve.magic or not evolve.magic.scatter_collectibles then
			return false, S("Wonder Charms are not enabled.")
		end
		return evolve.magic.scatter_collectibles(name, args[2], args[3])
	elseif cmd == "beautify" or cmd == "garden" then
		if not args[2] then
			return false, S("Usage: /ev beautify <radius>")
		end
		return evolve.beautify(name, args[2])
	elseif cmd == "mushroom_kingdom" or cmd == "mk" then
		if not args[2] then
			return false, S("Usage: /ev mushroom_kingdom <area>")
		end
		return evolve.mushroom_kingdom(name, args[2])
	elseif cmd == "pipe_link" or cmd == "pipe" then
		return evolve.create_pipe_link(name, args[2])
	elseif cmd == "castle" then
		return evolve.fairy_tale_castle(name, args[2] or "medium")
	end

	return false, S("Unknown Evolve command. Use /ev help.")
end

local def = {
	params = "<command> [args]",
	description = S("Admin tools for terraforming, structures, villages, cities, and treasure."),
	privs = { evolve = true },
	func = dispatch,
}

core.register_chatcommand("ev", def)
core.register_chatcommand("evolve", def)
