-- Boots client subsystems that have no natural first caller of their own --
-- previously these were required as a side effect of CameraSession loading,
-- which meant an unrelated failure in either of them (e.g. the objective
-- remote never replicating) could take the camera down with it. Now they
-- boot independently, at game start, regardless of whether the player has
-- ever touched a camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Modules.Flash.FlashRenderers)
require(ReplicatedStorage.Modules.Objective.ObjectiveVisualsController)
-- Pickup visuals (idle spin + light pillar) are purely cosmetic and place-
-- agnostic -- boots on both places, regardless of match state. The
-- ProximityPrompt and any actual grant stay Game-place + active-match gated
-- server-side (PickupRegistry/PickupService/PickupHandlers), so a pickup
-- placed on the Lobby spins and glows but is never interactable and never
-- pays out.
require(ReplicatedStorage.Modules.Pickup.PickupVisualsController)

-- Mirrors the server-side role branch in Bootstrap.legacy.luau.
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

if ServerRole.Is("LobbyServer") then
	require(ReplicatedStorage.Modules.UI.MatchReceiptController)
	require(ReplicatedStorage.Modules.Queue.QueueController)
	require(ReplicatedStorage.Modules.Queue.QueuePadDisplay)
elseif ServerRole.Is("GameServer") then
	require(ReplicatedStorage.Modules.UI.DeathScreenController)
	require(ReplicatedStorage.Modules.Spectate.SpectateController)
	require(ReplicatedStorage.Modules.UI.MatchReceiptController)
end
