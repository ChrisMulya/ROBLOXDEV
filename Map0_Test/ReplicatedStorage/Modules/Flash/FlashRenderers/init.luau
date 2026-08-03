-- Subscribes every flash renderer to FlashSignal exactly once. Adding a new
-- renderer (e.g. a future viewfinder shutter animation) is one require + one
-- Connect here -- nothing else in the Flash or Camera systems changes.
--
-- Boot: required (for its side effect) from StarterPlayerScripts/ClientBootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashSignal = require(ReplicatedStorage.Modules.Flash.FlashSignal)
local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local ScreenFlashRenderer = require(script.ScreenFlashRenderer)
local WorldLightRenderer = require(script.WorldLightRenderer)

FlashSignal:Connect(function(flashContext)
	local flashSettings = CameraStats.GetFlashSettings(flashContext.cameraId)
	ScreenFlashRenderer.Play(flashSettings)
	WorldLightRenderer.Play(flashContext, flashSettings)
end)

return true
