local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local CameraSession = require(ReplicatedStorage.Modules.Camera.CameraSession)
local CameraStability = require(ReplicatedStorage.Modules.Camera.CameraStability)
local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)

local player = Players.LocalPlayer

-- Returns (true, tool) if the character's equipped Tool is a camera,
-- (false, nil) otherwise -- NOT "any Tool", which used to let switching to
-- a support item mid-session leave the camera session stuck active.
local function getEquippedCameraTool(character)
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("IsCameraTool") == true then
		return true, tool
	end
	return false, nil
end

-- Death/respawn safety net: a new character never starts InCamera.
player.CharacterAdded:Connect(function()
	if CameraSession.IsActive() then
		CameraSession.Exit()
	end
end)

-- Single per-frame loop drives blur, reticle, and stability -- each read
-- exactly once (previously blur was updated twice per tick here, smoothing
-- at roughly double the configured SmoothingFactor).
RunService.RenderStepped:Connect(function()
	if not CameraSession.IsActive() then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	local holdingCamera, tool = getEquippedCameraTool(character)
	if not holdingCamera then
		CameraSession.Exit()
		return
	end

	if rootPart then
		CameraSession.UpdateBlur(rootPart.AssemblyLinearVelocity.Magnitude)
	end

	if humanoid then
		local cameraId = CameraStats.GetIdFromTool(tool)
		local thresholds = CameraStats.GetStabilitySettings(cameraId)
		local moving = CameraStability.IsMoving(humanoid, rootPart, thresholds)
		CameraState.SetStable(not moving)
	end
end)
