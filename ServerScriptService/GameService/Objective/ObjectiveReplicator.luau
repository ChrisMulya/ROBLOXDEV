-- Turns ObjectiveService.StateChanged into wire traffic. Two paths, kept
-- isolated here so neither leaks into ObjectiveService:
--   Shared  -- already replicated for free: ObjectiveService writes Shared
--             state directly onto the instance's ObjectiveState attribute,
--             and Roblox replicates attributes to every client automatically.
--   Player  -- attributes can't express per-player state, so this fires a
--             dedicated remote plus a join/respawn snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ObjectiveTypes = require(ReplicatedStorage.Modules.Objective.ObjectiveTypes)
local ObjectiveRegistry = require(script.Parent.ObjectiveRegistry)
local ObjectiveService = require(script.Parent.ObjectiveService)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local ObjectiveReplicator = {}

-- Provisioning now flows through Remotes.Init() (called once from Bootstrap),
-- which is idempotent and defers to any Studio-placed remote of the same
-- name. This used to self-provision inline here -- the only remote in the
-- codebase that did -- because it was authored while Studio MCP access was
-- unavailable.
local ObjectiveStateSync = Remotes.Get("ObjectiveStateSync")

local function ownershipFor(instance: Instance): string
	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).Ownership
end

ObjectiveService.StateChanged:Connect(function(player, instance, newState, _oldState)
	if ownershipFor(instance) ~= "Player" then
		return -- Shared already replicated via the ObjectiveState attribute
	end
	if not player or not player.Parent then
		return
	end
	ObjectiveStateSync:FireClient(player, { instance = instance, state = newState })
end)

local function sendSnapshot(player: Player)
	local entries = {}
	for _, instance in ipairs(ObjectiveRegistry.All()) do
		if ownershipFor(instance) == "Player" then
			table.insert(entries, { instance = instance, state = ObjectiveService.GetState(player, instance) })
		end
	end
	ObjectiveStateSync:FireClient(player, { entries = entries })
end

-- Only on CharacterAdded, not also immediately on PlayerAdded: the client's
-- ObjectiveStateClient hasn't required (let alone connected OnClientEvent)
-- by the time PlayerAdded fires server-side, so that immediate send was
-- always dropped -- it only ever "worked" because CharacterAdded re-sends a
-- moment later once the client has actually loaded.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		sendSnapshot(player)
	end)
end)

return ObjectiveReplicator
