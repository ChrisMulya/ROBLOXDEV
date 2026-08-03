-- Registry, not a require -- a policy module requiring RewardStore +
-- RewardLedger directly would be requires flowing DOWN from Lobby-layer
-- orchestration into a feature (R2/R3 violation). Reward/RewardLaunchHook
-- registers the actual progression precondition; QueueService registers its
-- own "Roster" precondition. QueueService and MatchLauncher never learn what
-- a precondition actually checks.
--
-- RegisterOnLaunched/OnLaunched: fired once, only after MatchLauncher.Launch
-- has actually succeeded for a candidate list -- the point at which it's
-- certain those players are leaving this server. RewardLaunchHook uses it to
-- release the Lobby's ProfileStore session for each candidate
-- (RewardStore.ClearSession), so the Game place's own session-start isn't
-- left waiting out a lock conflict against a session nobody meant to keep
-- holding. Same registry-not-require reasoning as the preconditions above.
--
-- Phase 10 also had RegisterRollback/Rollback here, for undoing whatever a
-- precondition committed if the launch never happened (its own MarkHandedOff
-- cheap gate had no real undo otherwise). Removed in Phase 12: ProfileStore's
-- session lock means the Lobby simply keeps its session active/exclusive
-- until OnLaunched actually fires, so there is nothing left to roll back --
-- a failed Check or a failed Launch now just leaves every candidate's
-- session exactly as it was.
--
-- RegisterOnLaunchAborted/OnLaunchAborted (Phase 12.5 item 2): for the case
-- OnLaunched itself doesn't cover -- MatchLauncher.Launch returning true
-- only means TeleportAsync was accepted, not that anyone arrived. A later,
-- async TeleportInitFailed means OnLaunched already fired and already
-- released whatever a candidate's precondition held (RewardLaunchHook's
-- session, for one) for a player who never actually left. MatchLauncher
-- calls this once it gives up retrying that specific player's teleport.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local LaunchGate = {}

local preconditions: { { name: string, fn: ({ Player }) -> (boolean, string) } } = {}
local onLaunchedHandlers: { { name: string, fn: ({ Player }) -> () } } = {}
local onLaunchAbortedHandlers: { { name: string, fn: ({ Player }) -> () } } = {}

function LaunchGate.RegisterPrecondition(name: string, fn: ({ Player }) -> (boolean, string))
	table.insert(preconditions, { name = name, fn = fn })
end

function LaunchGate.RegisterOnLaunched(name: string, fn: ({ Player }) -> ())
	table.insert(onLaunchedHandlers, { name = name, fn = fn })
end

function LaunchGate.RegisterOnLaunchAborted(name: string, fn: ({ Player }) -> ())
	table.insert(onLaunchAbortedHandlers, { name = name, fn = fn })
end

-- First failure wins. Preconditions run in registration order, so boot order
-- (RewardLaunchHook before QueueService) is also precondition order --
-- Progression's confirmed-save check happens before Roster's read-only
-- check, matching the roadmap's own sequencing.
function LaunchGate.Check(players: { Player }): (boolean, string)
	for _, entry in ipairs(preconditions) do
		local ok, code = entry.fn(players)
		if not ok then
			return false, code
		end
	end
	return true, "Ok"
end

function LaunchGate.OnLaunched(players: { Player })
	for _, entry in ipairs(onLaunchedHandlers) do
		entry.fn(players)
	end
end

function LaunchGate.OnLaunchAborted(players: { Player })
	for _, entry in ipairs(onLaunchAbortedHandlers) do
		entry.fn(players)
	end
end

local started = false

function LaunchGate.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertLobbyServer()
end

return LaunchGate
