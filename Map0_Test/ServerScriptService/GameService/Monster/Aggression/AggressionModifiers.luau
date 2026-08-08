-- Registry of aggression drivers. Same shape as RewardModifiers.Register and
-- CaptureRules.Register: adding a driver is a Register call, not an edit to
-- the thing that consumes them.
--
-- A modifier answers exactly one question -- "how much should this monster
-- want to be angry right now" -- as a number in [0,1]. It does NOT know its own
-- weight, does not write to the Blackboard, and does not know any other
-- modifier exists. Weighting and accumulation belong to Components/Aggression,
-- which is the sole writer of Blackboard.Aggression.
--
-- Signature: fn(instance, blackboard, dt, settings) -> number
--   settings is the per-monster table under Config.Aggression.Modifiers[name],
--   so Weight/Curve/MaxDistance/... are all monster-authored.

local ServerScriptService = game:GetService("ServerScriptService")

local MatchTimeService = require(ServerScriptService.GameService.MatchTime.MatchTimeService)
local AggressionCurves = require(script.Parent.AggressionCurves)

local AggressionModifiers = {}

local registry = {}

function AggressionModifiers.Register(name: string, fn)
	assert(type(name) == "string", "AggressionModifiers.Register: name must be a string")
	assert(type(fn) == "function", ("AggressionModifiers.Register: '%s' is not a function"):format(name))
	assert(registry[name] == nil, ("AggressionModifiers: '%s' is already registered"):format(name))
	registry[name] = fn
end

function AggressionModifiers.Get(name: string)
	return registry[name]
end

function AggressionModifiers.Names(): { string }
	local names = {}
	for name in pairs(registry) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- Distance to the nearest thing Perception can see RIGHT NOW.
--
-- Deliberately does not fall back to Blackboard.LastKnownPos. A monster
-- standing on a stale last-known position would read as permanently
-- maximally aggressive, which defeats Decay entirely -- losing sight of
-- someone has to let the anger bleed off, or the threshold is a one-way door.
AggressionModifiers.Register("Proximity", function(instance, blackboard, _dt, settings)
	local rootPart = instance.rootPart
	local visible = blackboard.VisibleTargets
	if not rootPart or not visible or not visible[1] then
		return 0
	end

	-- Perception sorts nearest-first, so [1] is the closest without a rescan.
	local maxDistance = settings.MaxDistance or instance.config.Stats.DetectRadius
	if not maxDistance or maxDistance <= 0 then
		return 0
	end

	local distance = visible[1].distance
	local closeness = 1 - math.clamp(distance / maxDistance, 0, 1)
	return AggressionCurves.Get(settings.Curve)(closeness)
end)

-- Match hour, normalized across the window the monster cares about. Returns 0
-- when there is no active schedule -- a monster spawned outside a match should
-- not inherit whatever hour the last one ended on.
AggressionModifiers.Register("MatchTime", function(_instance, _blackboard, _dt, settings)
	local hour = MatchTimeService.GetHour()
	if not hour then
		return 0
	end

	-- Defaults bracket the interesting half of the night: nothing before 21:00,
	-- saturated by hour 27 -- the same 3 AM the evolution event fires at, so
	-- aggression is already at its ceiling when the monster evolves rather than
	-- both arriving at once.
	local from = settings.FromHour or 21
	local to = settings.ToHour or 27
	if to <= from then
		return 0
	end

	return AggressionCurves.Get(settings.Curve)((hour - from) / (to - from))
end)

-- Strongest recent stimulus, faded by age. Reads Blackboard.Stimuli, which
-- nothing writes until step 8 adds the StimulusBus -- it evaluates to 0 until
-- then rather than erroring, so a config can name it today.
AggressionModifiers.Register("Stimulus", function(_instance, blackboard, _dt, settings)
	local stimuli = blackboard.Stimuli
	if not stimuli then
		return 0
	end

	local memory = settings.MemorySeconds or 8
	if memory <= 0 then
		return 0
	end

	local now = os.clock()
	local strongest = 0
	for _, stimulus in ipairs(stimuli) do
		local age = now - (stimulus.Timestamp or 0)
		if age <= memory then
			local recency = 1 - age / memory
			strongest = math.max(strongest, (stimulus.Strength or 0) * recency)
		end
	end

	return AggressionCurves.Get(settings.Curve)(strongest)
end)

-- Baseline that rises with the monster's stage, so a late-match monster is
-- angrier before anything provokes it.
AggressionModifiers.Register("Evolution", function(instance, _blackboard, _dt, settings)
	local stage = instance.stage or 1
	return AggressionCurves.Get(settings.Curve)((stage - 1) * (settings.PerStage or 0.5))
end)

return AggressionModifiers
