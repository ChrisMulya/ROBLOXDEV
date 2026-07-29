-- Boots client subsystems that have no natural first caller of their own --
-- previously these were required as a side effect of CameraSession loading,
-- which meant an unrelated failure in either of them (e.g. the objective
-- remote never replicating) could take the camera down with it. Now they
-- boot independently, at game start, regardless of whether the player has
-- ever touched a camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Modules.Flash.FlashRenderers)
require(ReplicatedStorage.Modules.Objective.ObjectiveVisualsController)

-- Mirrors the server-side role branch in Bootstrap.legacy.luau. Empty on
-- both sides today -- MatchStateClient/PlayerStateClient/DeathScreen/
-- SpectateHud (Game) and QueueHud (Lobby) land in later phases.
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)

if ServerRole.Is("LobbyServer") then
	-- Phase 9: QueueHud
elseif ServerRole.Is("GameServer") then
	require(ReplicatedStorage.Modules.UI.DeathScreenController)
	require(ReplicatedStorage.Modules.Spectate.SpectateController)
	-- Phase 7: EndMatchScreen
end
