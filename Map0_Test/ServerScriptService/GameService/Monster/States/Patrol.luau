-- Walk an authored route, in order, looping. Ineligible with no route
-- authored -- same "never eligible without the data it needs" shape Reset
-- already uses for LeashDistance, so a monster that declares CanPatrol but no
-- route just never enters this state rather than erroring.
--
-- Config.Navigation.PatrolRoute: an ordered array of Vector3, or of
-- { Position = Vector3 } tables if a future waypoint ever needs more (a wait
-- time, a facing direction) -- both shapes are accepted so that extension
-- does not require touching every existing route.

local Patrol = {}

Patrol.Name = "Patrol"
Patrol.Band = 0
Patrol.Interruptible = true
Patrol.TickRate = 0.5
-- Same reasoning as Wander: an unalerted monster walking its route should not
-- move at pursuit speed. Per-monster override: States.Patrol.SpeedScale.
Patrol.SpeedScale = 0.5

local function routeFor(instance): { any }?
	local navigation = instance.config.Navigation
	local route = navigation and navigation.PatrolRoute
	if route and #route > 0 then
		return route
	end
	return nil
end

local function positionOf(waypoint): Vector3
	if typeof(waypoint) == "Vector3" then
		return waypoint
	end
	return waypoint.Position
end

local function memoryFor(instance)
	local memory = instance.patrolMemory
	if not memory then
		memory = { index = 1, resolved = {} }
		instance.patrolMemory = memory
	end
	return memory
end

-- Authored route points get the same ground-and-clearance guarantee as random
-- roam points. An authored Vector3 is if anything MORE likely to be slightly
-- inside a wall or floating a stud above the floor than a random one -- it was
-- typed or dragged by hand, and nothing validates it at author time.
--
-- Cached per index, including the failures (stored as false), because the
-- route never moves: resolving costs a raycast plus an overlap query and this
-- runs at Patrol's tick rate forever.
local function resolvePoint(instance, navigation, route, index): Vector3?
	local memory = memoryFor(instance)
	local cached = memory.resolved[index]
	if cached ~= nil then
		return cached or nil
	end

	local raw = positionOf(route[index])
	local resolved = navigation:ResolveReachable(raw)
	if not resolved then
		-- Once per bad waypoint, naming the index, because this is a level
		-- authoring mistake and the fix is in Studio rather than in code.
		warn(("Patrol: '%s' route waypoint %d at %s has no reachable ground -- skipping it")
			:format(instance.monsterId, index, tostring(raw)))
	end

	memory.resolved[index] = resolved or false
	return resolved
end

function Patrol.Score(instance, blackboard): number?
	if blackboard.Target or blackboard.LastKnownPos then
		return nil
	end
	if not routeFor(instance) then
		return nil
	end
	-- Same low constant as Wander -- the two are mutually exclusive in
	-- practice (a monster either has an authored route or it doesn't), so
	-- there is no tuning surface for "prefer Patrol over Wander" to get wrong.
	return 0.3
end

function Patrol.Enter(_instance) end

function Patrol.Update(instance, dt: number)
	local navigation = instance:GetComponent("Navigation")
	local route = routeFor(instance)
	if not navigation or not route then
		return
	end

	local memory = memoryFor(instance)

	-- Walk past unresolvable waypoints rather than stalling on one. Bounded by
	-- the route length so a route that is bad end to end costs one pass and
	-- then does nothing, instead of spinning this loop every tick forever.
	local target
	for _ = 1, #route do
		if memory.index > #route then
			memory.index = 1
		end
		target = resolvePoint(instance, navigation, route, memory.index)
		if target then
			break
		end
		memory.index += 1
	end

	if not target then
		return
	end

	if navigation:MoveTo(target, dt) then
		memory.index += 1
		if memory.index > #route then
			memory.index = 1
		end
	end
end

function Patrol.Exit(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
end

return Patrol
