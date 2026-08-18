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
	"KitGranted",
	"ShowsMatchTime",
	"RespawnsOnDeath",
	"ShowsLoadingScreen",
}

-- KitGranted: whether a participant may hold their starter kit right now.
-- Added 8.5 -- the seam that lets KitLifecycleHook decide "may I grant/keep
-- a kit" as a data lookup instead of a condition someone has to remember at
-- every call site.
--
-- ShowsMatchTime: whether the match time HUD is on screen. True for Playing
-- only -- the match clock is match-scoped, and MatchTimeService clears its
-- anchors the moment Playing ends, so there is no time left to draw. The
-- "bar completely filled at 6 AM" requirement is still met: progress is
-- clamped to 1, so the last frame drawn before the transition is a full bar.
-- An earlier draft had this true for Ending too; that was a flag claiming a
-- capability the replicated data could not back, since the attributes are
-- already nil by then.
--
-- RespawnsOnDeath: whether DeathService respawns a dying player instead of
-- moving them into Dead/Spectating. True only for the pre-match states,
-- where a death must not strand someone waiting on a match that never
-- started. Critically FALSE for Ending: sunrise elimination kills every
-- survivor while the match is already Ending, and the old
-- `not IsGameplayActive` test would have respawned all of them into the map
-- underneath the result receipt.
--
-- ShowsLoadingScreen: true for Loading only. Loading.KitGranted and
-- Loading.AcceptsJoins are also true -- the match loading screen spawns
-- characters (and therefore grants kits) under the curtain, and a reserved
-- server is accepting joins the moment it boots, not only once the roster is
-- confirmed ready.
MatchStates.All = {
	Loading = {
		GameplayActive = false,
		AcceptsJoins = true,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
		KitGranted = true,
		ShowsMatchTime = false,
		RespawnsOnDeath = true,
		ShowsLoadingScreen = true,
	},
	WaitingForPlayers = {
		GameplayActive = false,
		AcceptsJoins = true,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
		KitGranted = true,
		ShowsMatchTime = false,
		RespawnsOnDeath = true,
		ShowsLoadingScreen = false,
	},
	Countdown = {
		GameplayActive = false,
		AcceptsJoins = true,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
		KitGranted = true,
		ShowsMatchTime = false,
		RespawnsOnDeath = true,
		ShowsLoadingScreen = false,
	},
	Playing = {
		GameplayActive = true,
		AcceptsJoins = false,
		SpectateAllowed = true,
		ScoringActive = true,
		MonstersSpawn = true,
		Terminal = false,
		KitGranted = true,
		ShowsMatchTime = true,
		RespawnsOnDeath = false,
		ShowsLoadingScreen = false,
	},
	Ending = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = true,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
		KitGranted = false,
		ShowsMatchTime = false,
		RespawnsOnDeath = false,
		ShowsLoadingScreen = false,
	},
	Cleanup = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = false,
		KitGranted = false,
		ShowsMatchTime = false,
		RespawnsOnDeath = false,
		ShowsLoadingScreen = false,
	},
	Finished = {
		GameplayActive = false,
		AcceptsJoins = false,
		SpectateAllowed = false,
		ScoringActive = false,
		MonstersSpawn = false,
		Terminal = true,
		KitGranted = false,
		ShowsMatchTime = false,
		RespawnsOnDeath = false,
		ShowsLoadingScreen = false,
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

function MatchStates.IsKitGranted(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.KitGranted
end

function MatchStates.ShowsMatchTime(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.ShowsMatchTime
end

function MatchStates.RespawnsOnDeath(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.RespawnsOnDeath
end

function MatchStates.ShowsLoadingScreen(state: string): boolean
	local def = MatchStates.All[state]
	return def ~= nil and def.ShowsLoadingScreen
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
