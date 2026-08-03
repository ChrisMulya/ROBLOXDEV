-- Registry, not a require -- a policy module requiring RewardStore +
-- RewardLedger directly would be requires flowing DOWN from Lobby-layer
-- orchestration into a feature (R2/R3 violation). Reward/RewardLaunchHook
-- registers the actual progression precondition; QueueService registers its
-- own "Roster" precondition. QueueService and MatchLauncher never learn what
-- a precondition actually checks.
--
-- RegisterRollback/Rollback are NOT in the roadmap's §4.2 API listing --
-- added here to close roadmap risk R-3: "MatchLauncher.Launch returning
-- false must trigger [recovery] for each candidate, in the same phase, not
-- noticed later." The plan's own Progression precondition example commits a
-- side effect (Save + MarkHandedOff) as part of *checking* readiness, so a
-- later precondition failing, or Launch itself failing, can leave that side
-- effect stranded with no code path left to undo it -- QueueService can't
-- undo it directly without learning what XP is (the exact thing R2 forbids).
-- A same-shape registry for "undo whatever Check committed" is the smallest
-- addition that keeps that boundary intact.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local LaunchGate = {}

local preconditions: { { name: string, fn: ({ Player }) -> (boolean, string) } } = {}
local rollbacks: { { name: string, fn: ({ Player }) -> () } } = {}

function LaunchGate.RegisterPrecondition(name: string, fn: ({ Player }) -> (boolean, string))
	table.insert(preconditions, { name = name, fn = fn })
end

function LaunchGate.RegisterRollback(name: string, fn: ({ Player }) -> ())
	table.insert(rollbacks, { name = name, fn = fn })
end

-- First failure wins. Preconditions run in registration order, so boot order
-- (RewardLaunchHook before QueueService) is also precondition order --
-- Progression's Save/MarkHandedOff commit happens before Roster's read-only
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

-- Runs every registered rollback unconditionally. Each rollback must be
-- idempotent and a no-op for players it never actually touched -- callers
-- (QueueService) invoke this on ANY non-launch outcome, not just the one
-- precondition that happened to fail, since an earlier precondition may have
-- already committed a side effect before a later one failed.
function LaunchGate.Rollback(players: { Player })
	for _, entry in ipairs(rollbacks) do
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
