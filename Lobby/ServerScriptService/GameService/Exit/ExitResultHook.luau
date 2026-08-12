-- Registers the Exit System's slice into MatchResultBuilder. Non-yielding,
-- side-effect-free, nil for anyone who didn't escape -- same contract as the
-- Reward/Player/Stats contributors. Modular by design: a future extraction
-- bonus, grade modifier, or receipt row consumes this slice without any
-- other Exit System module changing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local ExitState = require(script.Parent.ExitState)
local MatchResultBuilder = require(script.Parent.Parent.Match.MatchResultBuilder)

local ExitResultHook = {}

local started = false

function ExitResultHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchResultBuilder.RegisterContributor("Exit", function(userId: number)
		local record = ExitState.GetEscape(userId)
		if not record then
			return nil
		end
		return {
			escaped = true,
			exitType = record.exitType,
			escapedAtHour = record.atHour,
		}
	end)
end

return ExitResultHook
