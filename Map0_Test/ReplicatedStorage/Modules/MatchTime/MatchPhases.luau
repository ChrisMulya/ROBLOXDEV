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
	Dusk = { StartHour = 16, MonsterStage = 1, MonstersAggressive = false, ExtractionOpen = false },
	Night = { StartHour = 19, MonsterStage = 1, MonstersAggressive = true, ExtractionOpen = false },
	DeepNight = { StartHour = 24, MonsterStage = 2, MonstersAggressive = true, ExtractionOpen = false },
	Dawn = { StartHour = 28, MonsterStage = 2, MonstersAggressive = true, ExtractionOpen = true },
}

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
end

return MatchPhases
