-- Owns the flashlight's per-frame work, once, for whichever input toggled it
-- (F on desktop, the touch button on mobile). Those two scripts only fire the
-- toggle remote; everything below is independent of which one did.
--
-- Deliberately requires NOTHING. StarterPlayerScripts LocalScripts in this
-- game run sandboxed, and a sandboxed thread cannot require an unsandboxed
-- ModuleScript -- so SEND_RATE below is mirrored by hand from
-- ReplicatedStorage/Modules/Player/FlashlightAim.luau (the server's copy, and
-- the written-down source of this contract). Change it in both places.
--
-- Server-authoritative only: this script reports the camera's look vector at
-- SEND_RATE and does nothing else. It used to also rewrite the emitter's
-- CFrame locally every RenderStepped (a same-frame visual trick for the
-- holder, never replicated) -- dropped because four players' worth of
-- FlashlightAim traffic at 30Hz is trivial (one Vector3 each, ~120 calls/sec
-- total server-wide), so there was no cost reason to keep two code paths
-- posing the same part.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Deliberately relaxes the "requires nothing" sandbox property (see header):
-- FlashlightService only exists on a Game Server, so there is nothing to
-- report aim to on the Lobby. ServerRole -> PlaceIds is a two-module leaf
-- chain, nothing else.
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
if not ServerRole.Is("GameServer") then
	return
end

-- Mirrors FlashlightAim.SEND_RATE.
local SEND_RATE = 1 / 30

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local aimRemote = remotesFolder:WaitForChild("FlashlightAim")

local sinceLastSend = 0

local function getEmitter(): BasePart?
	local character = player.Character
	local emitter = character and character:FindFirstChild("FlashlightEmitter")
	return (emitter and emitter:IsA("BasePart")) and emitter or nil
end

RunService.RenderStepped:Connect(function(deltaTime)
	if not getEmitter() then
		-- No beam: nothing worth reporting. Reset so the first frame after a
		-- toggle sends immediately rather than waiting out a partial interval.
		sinceLastSend = SEND_RATE
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	sinceLastSend += deltaTime
	if sinceLastSend < SEND_RATE then
		return
	end
	sinceLastSend = 0
	aimRemote:FireServer(camera.CFrame.LookVector)
end)
