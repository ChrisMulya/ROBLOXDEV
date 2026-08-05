-- Per-match reward deltas: how much each participant actually earned during
-- THIS match, as opposed to the lifetime totals RewardLedger holds.
--
-- Exists because the end-of-match scoreboard can't be built from the ledger.
-- Score happens to read correctly there (it's ResetOnRunEnd and starts at 0
-- on a Game server, and its reset runs during Cleanup, strictly after the
-- Ending snapshot) -- but XP is persistent and carries the player's whole
-- Lobby balance in, so a player who earned 400 XP would see 8,800.
--
-- Subscribes to RewardService.Granted rather than .Awarded: Awarded only
-- fires on the capture path, while Granted fires from Grant itself -- the
-- sole caller of RewardLedger.Add in the repo. Every reward amount that will
-- ever exist passes through it, so this accumulator is complete by
-- construction and a future reward source (missions, achievements) is counted
-- without touching this file.
--
-- Keyed by userId, never by Player. A participant who disconnects mid-match
-- keeps their earnings and therefore keeps a real row on the scoreboard --
-- nothing is cleared on PlayerRemoving, deliberately.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local RewardService = require(script.Parent.RewardService)

local MatchEarnings = {}

-- [userId] = { [rewardTypeName] = number }
local earnings: { [number]: { [string]: number } } = {}

function MatchEarnings.Get(userId: number, rewardType: string): number
	local forPlayer = earnings[userId]
	return (forPlayer and forPlayer[rewardType]) or 0
end

-- Whole-table snapshot for one player, for callers that want every type
-- without naming any (the result contributor). Returns a fresh table.
function MatchEarnings.GetAll(userId: number): { [string]: number }
	local result = {}
	for rewardType, amount in pairs(earnings[userId] or {}) do
		result[rewardType] = amount
	end
	return result
end

function MatchEarnings.Reset()
	earnings = {}
end

local function onGranted(player: Player, amounts: { [string]: number })
	local userId = player.UserId
	local forPlayer = earnings[userId]
	if not forPlayer then
		forPlayer = {}
		earnings[userId] = forPlayer
	end

	-- Generic over reward types on purpose: adding a currency is a row in
	-- RewardTypes.luau and must not require an edit here.
	for rewardType, amount in pairs(amounts) do
		forPlayer[rewardType] = (forPlayer[rewardType] or 0) + amount
	end
end

local started = false

function MatchEarnings.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Signal fires deferred (BindableEvent), so a grant landing in the same
	-- frame the match ends could in principle accrue just after
	-- MatchResultBuilder's Ending snapshot. Accepted: the window is one
	-- resumption point, and every other subscriber in this repo (e.g.
	-- ObjectiveService on Awarded) already lives with the same property.
	RewardService.Granted:Connect(onGranted)

	-- A reserved Game server hosts exactly one match, so this is mostly
	-- belt-and-braces -- but Studio Play and MatchArrival's solo-seed
	-- fallback can run a second cycle in one session, and a stale
	-- accumulator would silently inflate the next scoreboard.
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "WaitingForPlayers" then
			MatchEarnings.Reset()
		end
	end)
end

return MatchEarnings
