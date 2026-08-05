-- Assembles the end-of-match summary by invoking registered contributors.
-- Requires no feature system (R2) -- Reward/Objective/Camera each register
-- their own slice of the payload during their own Start(); this module
-- never learns what an objective or a reward type is. Same contract as
-- RewardService.RegisterContextProvider: non-yielding, side-effect-free,
-- nil means "nothing to add for this player".
--
-- perPlayer is captured once, on Ending, same as resultCode/durationSeconds
-- below -- Build() is called again later (MatchReplicator at Ending itself,
-- then ReturnToLobbyService during Cleanup/Finished), by which point
-- MatchCleanup's teardown steps have already run and would zero anything a
-- contributor reads live (Score, held tools, objective state). Recomputing
-- on every Build() call would make the in-match end screen and the Lobby
-- arrival receipt disagree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)

local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)

local MatchResultBuilder = {}

-- Fires once, after capturedPerPlayer/capturedRoster are populated on
-- Ending. Exists because MatchReplicator used to read Build() from its own
-- separate MatchManager.StateChanged -> "Ending" subscriber -- correct only
-- if that subscriber happened to run after this module's, an implicit
-- ordering dependency on Signal dispatch order rather than a real
-- guarantee. Subscribing to THIS signal instead makes "capture already
-- happened" the actual contract.
MatchResultBuilder.Captured = Signal.new()

-- { {name, fn} }, registration order.
local contributors = {}

local capturedResultCode = "Unknown"
local capturedDuration = 0
local capturedPerPlayer: { [number]: any } = {}
-- Same data as capturedPerPlayer, as an ordered array of
-- { userId, slices }. Two reasons it isn't just the map:
--   1. The map is userId-keyed, and TeleportData is JSON-encoded on the way
--      to the Lobby -- integer keys come back as strings, so a numeric
--      lookup on the far side silently misses. An array survives intact.
--   2. The end-of-match scoreboard needs a stable order, which pairs() over
--      a map can't give.
local capturedRoster: { { userId: number, slices: any } } = {}

function MatchResultBuilder.RegisterContributor(name: string, fn: (number) -> any?)
	table.insert(contributors, { name = name, fn = fn })
end

local function buildPerPlayer()
	local perPlayer = {}
	local roster = {}

	local participants = MatchParticipants.All()
	if #participants == 0 then
		-- Not necessarily a bug (e.g. every participant disconnected before
		-- Ending), but a receipt with nobody in it is exactly what an empty,
		-- silent panel looks like on the client -- worth a trace either way.
		warn("MatchResultBuilder: capturing at Ending with zero participants")
	end

	for _, userId in ipairs(participants) do
		local slice = {}
		for _, contributor in ipairs(contributors) do
			-- pcall'd deliberately: contributors are third-party to this
			-- module (Reward/Match/Objective each register their own), and
			-- one throwing must not blank every other player's slice, let
			-- alone abort the capture Build()/MatchReplicator both depend on.
			local ok, extra = pcall(contributor.fn, userId)
			if not ok then
				warn(("MatchResultBuilder: contributor %q errored for userId %d: %s"):format(
					contributor.name, userId, tostring(extra)))
			elseif extra ~= nil then
				slice[contributor.name] = extra
			end
		end
		perPlayer[userId] = slice
		table.insert(roster, { userId = userId, slices = slice })
	end

	return perPlayer, roster
end

function MatchResultBuilder.Build()
	return {
		resultCode = capturedResultCode,
		durationSeconds = capturedDuration,
		perPlayer = capturedPerPlayer,
		roster = capturedRoster,
	}
end

local started = false

function MatchResultBuilder.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Captured once, when the match actually leaves Playing -- Build() may
	-- be called later (during Cleanup, or by a retry), long after the
	-- reason, elapsed time, and per-player state that matter are the ones
	-- from that moment.
	MatchManager.StateChanged:Connect(function(newState: string, _oldState: string, reason: string?)
		if newState == "Ending" then
			capturedResultCode = reason or "Unknown"
			capturedDuration = MatchManager.GetElapsed()
			capturedPerPlayer, capturedRoster = buildPerPlayer()
			MatchResultBuilder.Captured:Fire()
		end
	end)
end

return MatchResultBuilder
