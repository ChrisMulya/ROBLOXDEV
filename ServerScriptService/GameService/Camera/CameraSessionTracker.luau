-- Tracks which players currently report themselves as InCamera, client-
-- reported via the CameraSessionChanged remote. This is a UX guard (stops
-- the shelf from destroying an equipped, active camera tool out from under
-- a player), not a security boundary -- a malicious client could simply not
-- report, so nothing here should be trusted for anti-cheat purposes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraSessionChanged = ReplicatedStorage.Remotes:WaitForChild("CameraSessionChanged")

local CameraSessionTracker = {}

local inCamera = {}

CameraSessionChanged.OnServerEvent:Connect(function(player, isActive)
	inCamera[player.UserId] = (isActive == true)
end)

Players.PlayerRemoving:Connect(function(player)
	inCamera[player.UserId] = nil
end)

function CameraSessionTracker.IsInCamera(player: Player): boolean
	return inCamera[player.UserId] == true
end

return CameraSessionTracker
