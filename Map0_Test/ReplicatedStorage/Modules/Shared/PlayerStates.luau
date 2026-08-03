-- The player state enum, and each state's semantics as data. Modelled on
-- ObjectiveStates.luau / MatchStates.luau. Never branch on a state *name*
-- outside PlayerStateService's transition guard (Phase 3) -- read a flag
-- instead.
--
-- Only CORE flags live here: a flag belongs in All only if two or more
-- independent systems read it (MatchEndCondition, SpectateService,
-- DeathService all read CountsAsActive, for example). A flag exactly one
-- subsystem cares about (CanBeRevived, say) belongs in that subsystem's own
-- default-deny policy table, keyed by state -- not here. This keeps adding a
-- state a one-row change instead of an N-file one.
--
-- Downed / Reviving / Respawning / Observer are FUTURE states, not
-- implemented yet. Adding them later is exactly this: one row each, with
-- CountsAsActive = true for the first three, so a revive system needs zero
-- changes to MatchEndCondition.

local PlayerStates = {}

local INITIAL_STATE = "Alive"

local CORE_FLAGS = {
	"CanControlCharacter",
	"CanScore",
	"CountsAsActive",
	"CanSpectate",
	"Terminal",
}

PlayerStates.All = {
	Alive = {
		CanControlCharacter = true,
		CanScore = true,
		CountsAsActive = true,
		CanSpectate = false,
		Terminal = false,
	},
	Dead = {
		CanControlCharacter = false,
		CanScore = false,
		CountsAsActive = false,
		CanSpectate = false,
		Terminal = false,
	},
	Spectating = {
		CanControlCharacter = false,
		CanScore = false,
		CountsAsActive = false,
		CanSpectate = true,
		Terminal = false,
	},
	Disconnected = {
		CanControlCharacter = false,
		CanScore = false,
		CountsAsActive = false,
		CanSpectate = false,
		Terminal = false,
	},
	Leaving = {
		CanControlCharacter = false,
		CanScore = false,
		CountsAsActive = false,
		CanSpectate = false,
		Terminal = true,
	},
}

-- Disconnected is deliberately NOT terminal -- that's what makes reconnect
-- support a config change later rather than a redesign. Leaving is terminal:
-- this player will not be seen again on this server.
PlayerStates.Transitions = {
	Alive = { Dead = true, Disconnected = true, Leaving = true },
	Dead = { Spectating = true, Alive = true, Disconnected = true, Leaving = true },
	Spectating = { Alive = true, Disconnected = true, Leaving = true },
	Disconnected = { Alive = true, Leaving = true },
	Leaving = {},
}

function PlayerStates.IsValid(state: string): boolean
	return PlayerStates.All[state] ~= nil
end

function PlayerStates.CanControlCharacter(state: string): boolean
	local def = PlayerStates.All[state]
	return def ~= nil and def.CanControlCharacter
end

function PlayerStates.CanScore(state: string): boolean
	local def = PlayerStates.All[state]
	return def ~= nil and def.CanScore
end

function PlayerStates.CountsAsActive(state: string): boolean
	local def = PlayerStates.All[state]
	return def ~= nil and def.CountsAsActive
end

function PlayerStates.CanSpectate(state: string): boolean
	local def = PlayerStates.All[state]
	return def ~= nil and def.CanSpectate
end

function PlayerStates.IsTerminal(state: string): boolean
	local def = PlayerStates.All[state]
	return def ~= nil and def.Terminal
end

function PlayerStates.CanTransition(from: string, to: string): boolean
	local targets = PlayerStates.Transitions[from]
	return targets ~= nil and targets[to] == true
end

-- Same reasoning as MatchStates.Validate() -- this is the test suite for
-- the data every future subsystem trusts.
function PlayerStates.Validate()
	assert(
		PlayerStates.All[INITIAL_STATE] ~= nil,
		("PlayerStates.Validate: initial state '%s' is not defined in All"):format(INITIAL_STATE)
	)

	for fromState, targets in pairs(PlayerStates.Transitions) do
		assert(
			PlayerStates.All[fromState] ~= nil,
			("PlayerStates.Validate: transition source '%s' is not a valid state"):format(fromState)
		)
		for toState in pairs(targets) do
			assert(
				PlayerStates.All[toState] ~= nil,
				("PlayerStates.Validate: transition target '%s' (from '%s') is not a valid state"):format(toState, fromState)
			)
		end
	end

	for state, def in pairs(PlayerStates.All) do
		for _, flag in ipairs(CORE_FLAGS) do
			assert(
				typeof(def[flag]) == "boolean",
				("PlayerStates.Validate: state '%s' is missing boolean flag '%s'"):format(state, flag)
			)
		end
	end

	for state in pairs(PlayerStates.All) do
		if not PlayerStates.All[state].Terminal then
			local visited = { [state] = true }
			local stack = { state }
			local reachesTerminal = false
			while #stack > 0 do
				local current = table.remove(stack)
				if PlayerStates.All[current] and PlayerStates.All[current].Terminal then
					reachesTerminal = true
					break
				end
				for target in pairs(PlayerStates.Transitions[current] or {}) do
					if not visited[target] then
						visited[target] = true
						table.insert(stack, target)
					end
				end
			end
			assert(
				reachesTerminal,
				("PlayerStates.Validate: state '%s' cannot reach any terminal state"):format(state)
			)
		end
	end
end

return PlayerStates
