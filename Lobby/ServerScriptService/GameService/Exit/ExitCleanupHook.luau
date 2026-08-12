-- Registers the Exit System's teardown step into MatchCleanup: clears
-- prompts back to disabled and resets CanExit on every registered exit at
-- Cleanup, so a re-used server doesn't show a stale-available exit before
-- ExitState.Reset() runs on the next match's WaitingForPlayers. Mirrors
-- Pickup/PickupCleanupHook.luau's registry-before-registrant shape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local ExitTypes = require(ReplicatedStorage.Modules.Exit.ExitTypes)
local ExitRegistry = require(script.Parent.ExitRegistry)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)

local ExitCleanupHook = {}

local started = false

function ExitCleanupHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchCleanup.RegisterTeardownStep("Exit", function()
		for _, instance in ipairs(ExitRegistry.All()) do
			instance:SetAttribute(ExitTypes.AvailabilityAttribute, false)
		end
	end)
end

return ExitCleanupHook
