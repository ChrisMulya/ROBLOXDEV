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

local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)

local MatchResultBuilder = {}

-- { {name, fn} }, registration order.
local contributors = {}

local capturedResultCode = "Unknown"
local capturedDuration = 0
local capturedPerPlayer: { [number]: any } = {}

function MatchResultBuilder.RegisterContributor(name: string, fn: (number) -> any?)
	table.insert(contributors, { name = name, fn = fn })
end

local function buildPerPlayer()
	local perPlayer = {}

	for _, userId in ipairs(MatchParticipants.All()) do
		local slice = {}
		for _, contributor in ipairs(contributors) do
			local extra = contributor.fn(userId)
			if extra ~= nil then
				slice[contributor.name] = extra
			end
		end
		perPlayer[userId] = slice
	end

	return perPlayer
end

function MatchResultBuilder.Build()
	return {
		resultCode = capturedResultCode,
		durationSeconds = capturedDuration,
		perPlayer = capturedPerPlayer,
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
			capturedPerPlayer = buildPerPlayer()
		end
	end)
end

return MatchResultBuilder
