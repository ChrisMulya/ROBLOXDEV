-- The match state enum, and each state's semantics as data. Modelled
-- exactly on ObjectiveStates.luau: nothing outside this module (and
-- MatchManager's transition guard, Phase 4) should branch on a state
-- *name* -- read a flag instead. Adding a state is a new row here.
--
-- Every non-terminal state can reach Cleanup -- that's what makes abort
-- paths (nobody arrived, host shutdown, fatal error) safe without special-
-- casing: MatchManager.Abort() can always land on Cleanup from wherever the
-- match currently is.

local MatchStates = {}

local INITIAL_STATE = "Loading"

local CORE_FLAGS = {
	"GameplayActive",
	"AcceptsJoins",
	"SpectateAllowed",
	"ScoringActive",
	"MonstersSpawn",
	"Terminal",
}

MatchStates.All = {
	Loading = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
	},
	WaitingForPlayers = {
		GameplayActive = false,
		AcceptsJoins = true,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
	},
	Countdown = {
		GameplayActive = false,
		AcceptsJoins = true,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
	},
	Playing = {
		GameplayActive = true,
		AcceptsJoins = false,
		SpectateAllowed = true,
		ScoringActive = true,
		MonstersSpawn = true,
		Terminal = false,
	},
	Ending = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = true,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
	},
	Cleanup = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
	},
	Finished = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = true,
	},
}

MatchStates.Transitions = {
	Loading = { WaitingForPlayers = true, Cleanup = true },
	WaitingForPlayers = { Countdown = true, Cleanup = true },
	Countdown = { Playing = true, WaitingForPlayers = true, Cleanup = true },
	Playing = { Ending = true },
	Ending = { Cleanup = true },
	Cleanup = { Finished = true },
	Finished = {},
}

function MatchStates.IsValid(state: string): boolean
	return MatchStates.All[state] ~= nil
end

function MatchStates.IsGameplayActive(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.GameplayActive
end

function MatchStates.AcceptsJoins(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.AcceptsJoins
end

function MatchStates.IsSpectateAllowed(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.SpectateAllowed
end

function MatchStates.IsScoringActive(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.ScoringActive
end

function MatchStates.MonstersSpawn(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.MonstersSpawn
end

function MatchStates.IsTerminal(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.Terminal
end

function MatchStates.CanTransition(from: string, to: string): boolean
	local targets = MatchStates.Transitions[from]
	return targets ~= nil and targets[to] == true
end

-- With no test framework in this repo, this IS the test suite for the most
-- load-bearing data in the system. Called from GameBoot before any service
-- starts -- a typo'd state name becomes a loud boot failure instead of a
-- silent capability grant.
function MatchStates.Validate()
	assert(
		MatchStates.All[INITIAL_STATE] ~= nil,
		("MatchStates.Validate: initial state '%s' is not defined in All"):format(INITIAL_STATE)
	)

	for fromState, targets in pairs(MatchStates.Transitions) do
		assert(
			MatchStates.All[fromState] ~= nil,
			("MatchStates.Validate: transition source '%s' is not a valid state"):format(fromState)
		)
		for toState in pairs(targets) do
			assert(
				MatchStates.All[toState] ~= nil,
				("MatchStates.Validate: transition target '%s' (from '%s') is not a valid state"):format(toState, fromState)
			)
		end
	end

	for state, def in pairs(MatchStates.All) do
		for _, flag in ipairs(CORE_FLAGS) do
			assert(
				typeof(def[flag]) == "boolean",
				("MatchStates.Validate: state '%s' is missing boolean flag '%s'"):format(state, flag)
			)
		end
	end

	for state in pairs(MatchStates.All) do
		if not MatchStates.All[state].Terminal then
			local visited = { [state] = true }
			local stack = { state }
			local reachesTerminal = false
			while #stack > 0 do
				local current = table.remove(stack)
				if MatchStates.All[current] and MatchStates.All[current].Terminal then
					reachesTerminal = true
					break
				end
				for target in pairs(MatchStates.Transitions[current] or {}) do
					if not visited[target] then
						visited[target] = true
						table.insert(stack, target)
					end
				end
			end
			assert(
				reachesTerminal,
				("MatchStates.Validate: state '%s' cannot reach any terminal state"):format(state)
			)
		end
	end
end

return MatchStates
