-- Registers the Pickup System's teardown step into MatchCleanup: destroys
-- every remaining pickup at Cleanup. Each Destroy fires
-- workspace.DescendantRemoving, which PickupRegistry already turns into an
-- Unregistered signal that PickupService listens to to clear its claim-set
-- entry -- so this module doesn't need to know that table exists. Mirrors
-- Reward/RewardCleanupHook.luau's registry-before-registrant shape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PickupRegistry = require(script.Parent.PickupRegistry)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)

local PickupCleanupHook = {}

local started = false

function PickupCleanupHook.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchCleanup.RegisterTeardownStep("Pickup", function()
		for _, instance in ipairs(PickupRegistry.All()) do
			instance:Destroy()
		end
	end)
end

return PickupCleanupHook
