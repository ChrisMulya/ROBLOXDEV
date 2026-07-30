-- Assembles the end-of-match summary by invoking registered contributors.
-- Requires no feature system (R2) -- Reward/Objective/Camera each register
-- their own slice of the payload during their own Start(); this module
-- never learns what an objective or a reward type is. Same contract as
-- RewardService.RegisterContextProvider: non-yielding, side-effect-free,
-- nil means "nothing to add for this player". No contributors are
-- registered yet -- perPlayer entries are empty tables until a future
-- system adds one, which is the whole point (see plan section 16's
-- modularity acceptance tests: adding a contributor must not touch this
-- file).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)

local MatchResultBuilder = {}

-- { {name, fn} }, registration order.
local contributors = {}

local capturedResultCode = "Unknown"
local capturedDuration = 0

function MatchResultBuilder.RegisterContributor(name: string, fn: (number) -> any?)
	table.insert(contributors, { name = name, fn = fn })
end

function MatchResultBuilder.Build()
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

	return {
		resultCode = capturedResultCode,
		durationSeconds = capturedDuration,
		perPlayer = perPlayer,
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
	-- reason and elapsed time that matter are the ones from that moment.
	MatchManager.StateChanged:Connect(function(newState: string, _oldState: string, reason: string?)
		if newState == "Ending" then
			capturedResultCode = reason or "Unknown"
			capturedDuration = MatchManager.GetElapsed()
		end
	end)
end

return MatchResultBuilder
