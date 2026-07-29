-- Match lifecycle only. Owns the current state and the transition guard
-- against MatchStates.Transitions. Contains no gameplay logic and no
-- end-condition policy (that's MatchEndCondition, Phase 7), and touches no
-- remotes/attributes itself (that's MatchReplicator). Game Server only.
--
-- RequestTransition is the one guarded entry point every transition goes
-- through, including RequestEnd/Abort below and (later) MatchClock. This is
-- not in the plan's original public-API listing, which showed only
-- Get/Is/StateChanged/RequestEnd/Abort/GetElapsed with the transition
-- itself private -- but nothing in that listing gives MatchClock (which
-- "drives transitions via MatchManager", per the plan's own module
-- breakdown) or this phase's manual console verification ("Drive Loading
-- -> ... -> Finished by hand") any way to reach Loading -> WaitingForPlayers
-- -> Countdown -> Playing, since RequestEnd only fires from Playing and
-- Abort only lands on Cleanup. Exposing the guarded setter by name doesn't
-- weaken "no external module sets match state directly" in the sense that
-- matters: every call still goes through the exact same
-- MatchStates.CanTransition guard as RequestEnd/Abort.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local MatchManager = {}

local INITIAL_STATE = "Loading"

local currentState = INITIAL_STATE
local startedAt = 0

MatchManager.StateChanged = Signal.new() -- fires (newState, oldState, reason?)

function MatchManager.Get(): string
	return currentState
end

function MatchManager.Is(state: string): boolean
	return currentState == state
end

function MatchManager.GetElapsed(): number
	return os.clock() - startedAt
end

function MatchManager.RequestTransition(to: string, reason: string?): boolean
	if not MatchStates.IsValid(to) then
		warn(("MatchManager: '%s' is not a valid MatchState"):format(tostring(to)))
		return false
	end

	if not MatchStates.CanTransition(currentState, to) then
		warn(("MatchManager: illegal transition %s -> %s"):format(currentState, to))
		return false
	end

	local from = currentState
	currentState = to
	MatchManager.StateChanged:Fire(to, from, reason)
	return true
end

-- The only sanctioned way to leave Playing. Idempotent: deferred Signal
-- firing means several players dying in the same frame will all call this,
-- and a call once the match has already left Playing is a harmless no-op
-- rather than an error.
function MatchManager.RequestEnd(reason: string): boolean
	if currentState ~= "Playing" then
		return false
	end
	return MatchManager.RequestTransition("Ending", reason)
end

-- Any non-terminal state can eventually reach Cleanup -- the universal abort
-- path for "nobody arrived", host shutdown, or a fatal error. Playing is the
-- one state that can't skip straight there: MatchStates.Transitions.Playing
-- only permits Ending, because gameplay must freeze there first (stop
-- spawning, show the end screen) before anything is destroyed. So Abort
-- steps to Ending from Playing rather than failing -- this is the resolution
-- to a genuine inconsistency between the plan's prose ("any state can reach
-- Cleanup") and its own transition table (no direct Playing -> Cleanup edge).
function MatchManager.Abort(reason: string): boolean
	if MatchStates.IsTerminal(currentState) or currentState == "Cleanup" then
		return false
	end

	if MatchStates.CanTransition(currentState, "Cleanup") then
		return MatchManager.RequestTransition("Cleanup", reason)
	end

	if currentState == "Playing" then
		return MatchManager.RequestTransition("Ending", reason)
	end

	return false
end

local started = false

function MatchManager.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()
	startedAt = os.clock()
end

return MatchManager
