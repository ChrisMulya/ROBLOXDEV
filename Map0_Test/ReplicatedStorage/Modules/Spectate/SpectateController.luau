-- Wires SpectateCameraController + SpectateHud to the server's
-- SpectateStateSync remote and to PlayerStateClient. Game Server only --
-- required from ClientBootstrap's GameServer branch for its side effects,
-- the same pattern already used there for FlashRenderers/
-- ObjectiveVisualsController/DeathScreenController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local PlayerStateClient = require(ReplicatedStorage.Modules.Shared.PlayerStateClient)
local SpectateCameraController = require(script.Parent.SpectateCameraController)
local SpectateHud = require(script.Parent.SpectateHud)

PlayerStateClient.Start()

Remotes.Get("SpectateStateSync").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local targetPlayer = payload.targetUserId and Players:GetPlayerByUserId(payload.targetUserId)
	SpectateCameraController.SetTarget(targetPlayer)
	SpectateHud.Update(targetPlayer and targetPlayer.Name, payload.index or 0, payload.total or 0)
end)

PlayerStateClient.Changed:Connect(function(newState: string, oldState: string?)
	if oldState == "Spectating" and newState ~= "Spectating" then
		SpectateCameraController.Stop()
		SpectateHud.Hide()
	end
end)

return {}
