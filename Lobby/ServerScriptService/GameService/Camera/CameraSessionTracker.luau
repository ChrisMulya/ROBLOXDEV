-- Tracks which players currently report themselves as InCamera, client-
-- reported via the CameraSessionChanged remote. This is a UX guard (stops
-- the shelf from destroying an equipped, active camera tool out from under
-- a player), not a security boundary -- a malicious client could simply not
-- report, so nothing here should be trusted for anti-cheat purposes.
--
-- Phase 12.5 item 5: converted from module-scope self-wiring to the Start()
-- convention. Remotes.Get is a WaitForChild, so requiring this before
-- Remotes.Init() ran would have hung -- same debt class (#21) already fixed
-- for RewardLedger in Phase 12, and the established repo precedent is
-- Phase 8.5 moving Remotes.Get out of module scope in StartGame/EndGame for
-- the identical reason. This was also the specific thing that broke
-- require-based verification of CameraShelfSwap from the command bar in
-- both Phase 11 and Phase 12 -- worked around twice, fixed now.
--
-- Must be booted on BOTH places -- runs identically on each, no ServerRole
-- assertion, same as PlayerStateService. If either boot list misses this,
-- IsInCamera silently returns false forever, and the shelf would then
-- happily destroy an equipped, active camera out from under a player --
-- exactly the cascade this module exists to prevent, with no error to
-- reveal the missing boot line.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local CameraSessionTracker = {}

local inCamera = {}

function CameraSessionTracker.IsInCamera(player: Player): boolean
	return inCamera[player.UserId] == true
end

local started = false

function CameraSessionTracker.Start()
	if started then
		return
	end
	started = true

	Remotes.Get("CameraSessionChanged").OnServerEvent:Connect(function(player, isActive)
		inCamera[player.UserId] = (isActive == true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inCamera[player.UserId] = nil
	end)
end

return CameraSessionTracker
