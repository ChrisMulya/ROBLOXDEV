-- Registers the first MatchResultBuilder contributor: each participant's
-- current XP/Score at the moment the match ends. Same shape as
-- RewardCleanupHook registering into MatchCleanup -- a feature-layer module
-- requiring down into the Match layer's registry, so MatchResultBuilder
-- never learns what a reward type is (R2).
--
-- These are current totals, not a match-scoped delta -- no per-match earning
-- tracker exists yet. Score is ResetOnRunEnd (RewardTypes.luau), so it's
-- already match-scoped in practice; XP is persistent and carries the Lobby
-- balance in too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local RewardLedger = require(script.Parent.RewardLedger)
local MatchResultBuilder = require(script.Parent.Parent.Match.MatchResultBuilder)

local RewardResultHook = {}

local started = false

function RewardResultHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchResultBuilder.RegisterContributor("Reward", function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return nil
		end

		return {
			xp = RewardLedger.Get(player, "XP"),
			score = RewardLedger.Get(player, "Score"),
		}
	end)
end

return RewardResultHook
