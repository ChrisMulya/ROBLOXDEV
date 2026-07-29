-- Wires CameraTouchHud (pure UI) to the actual camera systems. Kept as its
-- own script rather than folded into CameraToolWatcher -- that script's job
-- is binding input to tools, not owning UI lifecycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraTouchHud = require(ReplicatedStorage.Modules.Camera.CameraTouchHud)
local CameraToolController = require(ReplicatedStorage.Modules.Camera.CameraToolController)
local CameraSession = require(ReplicatedStorage.Modules.Camera.CameraSession)
local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)

local function onOpenPressed()
	local tool = CameraToolController.GetEquipped()
	if tool then
		CameraSession.Toggle(tool)
	end
end

local function onPhotoPressed()
	CameraSession.Capture()
end

CameraTouchHud.Init(onOpenPressed, onPhotoPressed)

CameraToolController.OnEquippedChanged(function(tool)
	if tool then
		CameraTouchHud.Show()
	else
		CameraTouchHud.Hide()
	end
end)

CameraState.OnChanged(function(inCamera)
	CameraTouchHud.SetInCamera(inCamera)
end)

-- Catch-up for the case where a camera tool is already equipped by the time
-- this script starts (Equipped won't fire again for an already-equipped tool).
if CameraToolController.GetEquipped() then
	CameraTouchHud.Show()
end
