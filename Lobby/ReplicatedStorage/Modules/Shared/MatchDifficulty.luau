-- Per-difficulty match-start spawn tunables. Same enum-as-data convention as
-- MatchStates/ObjectiveStates/PlayerStates: adding a difficulty is a new row
-- here, nothing branches on a difficulty NAME.
--
-- SpawnFraction/PlayerScaling are keyed by SpawnCategories row id, not by
-- hardcoded Cash/Objective/Document -- consumed by SpawnMath.AdjustedFraction
-- via SpawnSelection, which iterates SpawnCategories.OrderedNames() rather
-- than naming a category itself. A category absent from a difficulty's
-- SpawnFraction is not managed by spawn selection -- every authored instance
-- of it stays active.
--
-- CashRewardScaling is a separate concept from SpawnFraction: it scales the
-- VALUE of a Cash pickup (consumed by PickupHandlers/Cash), never the count
-- of Cash pickups selected to spawn. Do not conflate the two -- see
-- plans/create-a-read-only-blueprint-plan-agile-possum.md section 4.

local MatchDifficulty = {}

MatchDifficulty.Default = "Normal"

MatchDifficulty.All = {
	Easy = {
		DisplayName = "Easy",
		SpawnFraction = { Cash = 0.50, Objective = 0.40, Document = 0.20 },
		PlayerScaling = { Cash = 0.00, Objective = 0.08, Document = 0.08 },
	},
	Normal = {
		DisplayName = "Normal",
		SpawnFraction = { Cash = 0.30, Objective = 0.50, Document = 0.35 },
		PlayerScaling = { Cash = 0.00, Objective = 0.08, Document = 0.08 },
	},
	Hard = {
		DisplayName = "Hard",
		SpawnFraction = { Cash = 0.20, Objective = 0.60, Document = 0.45 },
		PlayerScaling = { Cash = 0.00, Objective = 0.08, Document = 0.08 },
	},
	Nightmare = {
		DisplayName = "Nightmare",
		SpawnFraction = { Cash = 0.10, Objective = 0.80, Document = 0.70 },
		PlayerScaling = { Cash = 0.00, Objective = 0.08, Document = 0.08 },
	},
}

-- Cash pickup VALUE devaluation per additional player (see header). Never
-- read by SpawnSelection.
MatchDifficulty.CashRewardScaling = {
	PerExtraPlayer = 0.10,
	Floor = 0.10,
}

-- Ordered by DisplayName, computed once at module load. Precedent:
-- CaptureTargets.OrderedNames / PickupTypes.OrderedNames.
local orderedDifficultyNames = {}
for difficultyId in pairs(MatchDifficulty.All) do
	table.insert(orderedDifficultyNames, difficultyId)
end
table.sort(orderedDifficultyNames)

function MatchDifficulty.OrderedNames(): { string }
	return table.clone(orderedDifficultyNames)
end

function MatchDifficulty.Get(difficultyId: string?)
	if not difficultyId then
		return nil
	end
	return MatchDifficulty.All[difficultyId]
end

function MatchDifficulty.IsValid(difficultyId: string): boolean
	return MatchDifficulty.All[difficultyId] ~= nil
end

-- Loud boot failure on a malformed row beats a silent bad spawn selection
-- later, same reasoning as MatchStates.Validate. Called from GameBoot
-- alongside MatchStates.Validate/MatchSchedule.Validate.
function MatchDifficulty.Validate()
	assert(
		MatchDifficulty.All[MatchDifficulty.Default] ~= nil,
		("MatchDifficulty.Validate: Default '%s' is not a defined row"):format(MatchDifficulty.Default)
	)

	for difficultyId, def in pairs(MatchDifficulty.All) do
		assert(
			typeof(def.DisplayName) == "string",
			("MatchDifficulty.Validate: '%s' is missing DisplayName"):format(difficultyId)
		)
		assert(
			typeof(def.SpawnFraction) == "table",
			("MatchDifficulty.Validate: '%s' is missing SpawnFraction"):format(difficultyId)
		)
		assert(
			typeof(def.PlayerScaling) == "table",
			("MatchDifficulty.Validate: '%s' is missing PlayerScaling"):format(difficultyId)
		)

		for categoryId, fraction in pairs(def.SpawnFraction) do
			assert(
				typeof(fraction) == "number" and fraction > 0 and fraction <= 1,
				("MatchDifficulty.Validate: '%s'.SpawnFraction.%s must be a number in (0, 1], got %s"):format(
					difficultyId, categoryId, tostring(fraction))
			)
			assert(
				typeof(def.PlayerScaling[categoryId]) == "number",
				("MatchDifficulty.Validate: '%s'.SpawnFraction has '%s' but PlayerScaling is missing it"):format(
					difficultyId, categoryId)
			)
		end
	end

	assert(
		typeof(MatchDifficulty.CashRewardScaling.PerExtraPlayer) == "number",
		"MatchDifficulty.Validate: CashRewardScaling.PerExtraPlayer must be a number"
	)
	assert(
		typeof(MatchDifficulty.CashRewardScaling.Floor) == "number"
			and MatchDifficulty.CashRewardScaling.Floor >= 0
			and MatchDifficulty.CashRewardScaling.Floor <= 1,
		"MatchDifficulty.Validate: CashRewardScaling.Floor must be a number in [0, 1]"
	)
end

return MatchDifficulty
