if not evolve.settings.time_enable then
	return
end

local day_start = math.max(0, math.min(1, evolve.settings.time_day_start))
local night_start = math.max(0, math.min(1, evolve.settings.time_night_start))
local day_speed = math.max(0, evolve.settings.time_day_speed)
local night_speed = math.max(0, evolve.settings.time_night_speed)

local last_time = core.get_timeofday() or 0.5
local timer = 0

local function wrap_time(value)
	value = value % 1
	if value < 0 then
		value = value + 1
	end
	return value
end

local function circular_distance(a, b)
	local diff = math.abs(a - b)
	return math.min(diff, 1 - diff)
end

local function is_day(timeofday)
	if day_start == night_start then
		return true
	end
	if day_start < night_start then
		return timeofday >= day_start and timeofday < night_start
	end
	return timeofday >= day_start or timeofday < night_start
end

local function current_time_speed()
	return tonumber(core.settings:get("time_speed")) or 72
end

core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.25 then
		return
	end

	local elapsed = timer
	timer = 0

	local time_speed = current_time_speed()
	if time_speed <= 0 then
		last_time = core.get_timeofday() or last_time
		return
	end

	local current = core.get_timeofday()
	if not current then
		return
	end
	local normal_delta = (time_speed / 86400) * elapsed
	local expected_current = wrap_time(last_time + normal_delta)

	-- Respect deliberate external time changes, such as /time commands or other admin tools.
	if circular_distance(current, expected_current) > 0.01 then
		last_time = current
	end

	local multiplier = is_day(last_time) and day_speed or night_speed
	local next_time = wrap_time(last_time + normal_delta * multiplier)
	core.set_timeofday(next_time)
	last_time = next_time
end)

core.log("action", ("[evolve] time controller enabled: day %sx, night %sx"):format(day_speed, night_speed))
