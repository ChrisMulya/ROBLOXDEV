-- Registers the "Reward" MatchResultBuilder contributor: what each
-- participant earned during the match, plus their lifetime totals.
-- Same shape as RewardCleanupHook registering into MatchCleanup -- a
-- feature-layer module requiring down into the Match layer's registry, so
-- MatchResultBuilder never learns what a reward type is (R2).
--
-- Two different kinds of number, and the scoreboard shows the first:
--   xpEarned / scoreEarned -- this match only, from MatchEarnings. Keyed by
--     userId, so they survive the player disconnecting.
--   xp / score -- lifetime ledger totals, read off the live leaderstats
--     IntValues. Only present while the player is still connected.
--
-- The slice is returned even for a participant who has already left. That is
-- deliberate: returning nil would drop them from perPlayer and from the
-- roster array entirely, and a player who earned points then disconnected
-- should still appear on the end-of-match scoreboard with real numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local RewardLedger = require(script.Parent.RewardLedger)
local MatchEarnings = require(script.Parent.MatchEarnings)
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
		local slice = {
			xpEarned = MatchEarnings.Get(userId, "XP"),
			scoreEarned = MatchEarnings.Get(userId, "Score"),
		}

		-- Lifetime totals need a live Player (they're read off leaderstats),
		-- so they're the only conditional half.
		local player = Players:GetPlayerByUserId(userId)
		if player then
			slice.xp = RewardLedger.Get(player, "XP")
			slice.score = RewardLedger.Get(player, "Score")
		end

		return slice
	end)
end

return RewardResultHook
