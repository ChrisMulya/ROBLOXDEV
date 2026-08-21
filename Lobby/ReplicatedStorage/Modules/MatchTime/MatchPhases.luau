-- The match phase enum, as data -- same shape as MatchStates/ObjectiveStates.
-- Phases are derived from the current hour, never stored and never
-- transitioned; there is no PhaseChanged setter anywhere, only
-- MatchTimeService reading FromHour() each sample and diffing against the
-- last value it saw. That is what keeps this from becoming a second state
-- machine parallel to MatchStates. Consumers read a flag, never the phase
-- name.

local MatchPhases = {}

local CORE_FLAGS = {
	"MonsterStage",
	"MonstersAggressive",
	"ExtractionOpen",
}

-- Ordered ascending by StartHour -- FromHour relies on this order.
MatchPhases.Order = { "Dusk", "Night", "DeepNight", "Dawn" }

MatchPhases.Phases = {
	Dusk = { StartHour = 18, MonsterStage = 1, MonstersAggressive = false, ExtractionOpen = false },
	Night = { StartHour = 19, MonsterStage = 1, MonstersAggressive = true, ExtractionOpen = false },
	DeepNight = { StartHour = 24, MonsterStage = 2, MonstersAggressive = true, ExtractionOpen = false },
	Dawn = { StartHour = 28, MonsterStage = 2, MonstersAggressive = true, ExtractionOpen = true },
}

-- Match-time bar fill colours, as their own ordered band list. Hours are
-- unwrapped on the same scale as Phases.StartHour: the Default schedule
-- starts at 18 and counts up, so 27 is 3am.
--
-- These bands deliberately do NOT reuse the phase boundaries. Green and purple
-- happen to land on Dusk and Night, but red starts at 27 (3am) while Dawn
-- starts at 28 (4am) -- the bar is a mood cue and was specified in its own
-- hours. Keeping the two lists side by side in this file is the point: whoever
-- moves a phase boundary sees the colour band that no longer matches it.
MatchPhases.BarColorOrder = { "Evening", "Night", "Dawn" }

MatchPhases.BarColors = {
	Evening = { StartHour = 18, Color = Color3.fromRGB(76, 209, 111) },
	Night = { StartHour = 19, Color = Color3.fromRGB(150, 96, 224) },
	Dawn = { StartHour = 27, Color = Color3.fromRGB(224, 74, 74) },
}

-- Same "last band whose StartHour <= hour" scan FromHour uses. Hours below the
-- first band (only reachable if a schedule starts before the Default's 6pm)
-- take the first colour rather than falling through to nil.
function MatchPhases.BarColorFromHour(hour: number): Color3
	local result = MatchPhases.BarColors[MatchPhases.BarColorOrder[1]]
	for _, bandName in ipairs(MatchPhases.BarColorOrder) do
		local band = MatchPhases.BarColors[bandName]
		if band.StartHour <= hour then
			result = band
		else
			break
		end
	end
	return result.Color
end

-- Pure lookup: the last phase in Order whose StartHour <= hour.
function MatchPhases.FromHour(hour: number): string
	local result = MatchPhases.Order[1]
	for _, phaseName in ipairs(MatchPhases.Order) do
		if MatchPhases.Phases[phaseName].StartHour <= hour then
			result = phaseName
		else
			break
		end
	end
	return result
end

function MatchPhases.GetMonsterStage(phaseName: string): number?
	local def = MatchPhases.Phases[phaseName]
	return def and def.MonsterStage
end

function MatchPhases.IsMonstersAggressive(phaseName: string): boolean
	local def = MatchPhases.Phases[phaseName]
	return def ~= nil and def.MonstersAggressive
end

function MatchPhases.IsExtractionOpen(phaseName: string): boolean
	local def = MatchPhases.Phases[phaseName]
	return def ~= nil and def.ExtractionOpen
end

function MatchPhases.Validate()
	local previousStart = -math.huge
	for _, phaseName in ipairs(MatchPhases.Order) do
		local def = MatchPhases.Phases[phaseName]
		assert(def ~= nil, ("MatchPhases.Validate: '%s' is in Order but not in Phases"):format(phaseName))
		assert(
			def.StartHour > previousStart,
			("MatchPhases.Validate: '%s' StartHour must exceed the previous phase's StartHour"):format(phaseName)
		)
		previousStart = def.StartHour

		for _, flag in ipairs(CORE_FLAGS) do
			assert(
				def[flag] ~= nil,
				("MatchPhases.Validate: phase '%s' is missing field '%s'"):format(phaseName, flag)
			)
		end
	end

	for phaseName in pairs(MatchPhases.Phases) do
		local found = false
		for _, orderedName in ipairs(MatchPhases.Order) do
			if orderedName == phaseName then
				found = true
				break
			end
		end
		assert(found, ("MatchPhases.Validate: '%s' is in Phases but not in Order"):format(phaseName))
	end

	-- Bar colours get the same ascending-order check, plus one tie to the phase
	-- table: the first colour band must start when the first phase does, so a
	-- schedule that changes its start hour fails here instead of drawing the
	-- first minutes of the match with no band covering them.
	local previousBandStart = -math.huge
	for _, bandName in ipairs(MatchPhases.BarColorOrder) do
		local band = MatchPhases.BarColors[bandName]
		assert(band ~= nil, ("MatchPhases.Validate: '%s' is in BarColorOrder but not in BarColors"):format(bandName))
		assert(
			band.StartHour > previousBandStart,
			("MatchPhases.Validate: bar colour '%s' StartHour must exceed the previous band's"):format(bandName)
		)
		previousBandStart = band.StartHour
	end

	assert(
		MatchPhases.BarColors[MatchPhases.BarColorOrder[1]].StartHour
			== MatchPhases.Phases[MatchPhases.Order[1]].StartHour,
		"MatchPhases.Validate: the first bar colour band must start at the first phase's StartHour"
	)

	for bandName in pairs(MatchPhases.BarColors) do
		local found = false
		for _, orderedName in ipairs(MatchPhases.BarColorOrder) do
			if orderedName == bandName then
				found = true
				break
			end
		end
		assert(found, ("MatchPhases.Validate: '%s' is in BarColors but not in BarColorOrder"):format(bandName))
	end
end

return MatchPhases
