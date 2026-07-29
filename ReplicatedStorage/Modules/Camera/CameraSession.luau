-- Orchestrates one camera "in-camera" session: resolves the tool's stats,
-- shows the viewfinder, applies Lighting effects, hides other GUIs, locks
-- CameraMode, hides the mouse icon, and dims the tool -- all registered into
-- one Trove as they're acquired, so Exit() is a single Clean() call and
-- teardown can never drift from setup.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Modules.Shared.Trove)
local CameraState = require(ReplicatedStorage.Modules.Camera.CameraState)
local CameraEffects = require(ReplicatedStorage.Modules.Camera.CameraEffects)
local CameraViewfinder = require(ReplicatedStorage.Modules.Camera.CameraViewfinder)
local CameraStats = require(ReplicatedStorage.Modules.Camera.CameraStats)
local FlashSignal = require(ReplicatedStorage.Modules.Flash.FlashSignal)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local WeakCameraShot = Remotes.Get("WeakCameraShot")
local StrongCameraShot = Remotes.Get("StrongCameraShot")
local CameraSessionChanged = Remotes.Get("CameraSessionChanged")

local player = Players.LocalPlayer

local CameraSession = {}

local sessionTrove = nil
local originalCameraMode = nil
local activeCameraId = nil

local function setToolLocalTransparency(tool, transparency)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = transparency
		end
	end
end

-- Hides every other enabled ScreenGui and restores each one's PRIOR Enabled
-- state on exit (not a blanket re-enable), so a GUI that was legitimately
-- disabled before entering the camera stays disabled after leaving it.
--
-- Two exemptions, both required for the camera to be usable on touch devices:
--   - ScreenGuis carrying a KeepDuringCamera=true attribute (the viewfinder
--     itself, and CameraTouchHud) -- same attribute-tag convention as
--     IsCameraTool/IsMonster/IsCameraShelf elsewhere in this project.
--   - "TouchGui" by name: Roblox's own touch controls (joystick, jump). It's
--     engine-owned and gets recreated on control-scheme changes, so it can't
--     reliably carry our attribute. Hiding it previously also broke camera
--     look on touch devices -- CameraModule/CameraInput reads
--     TouchGui.TouchControlFrame and early-outs when TouchGui is disabled.
local function hideOtherGuis(trove)
	local playerGui = player:WaitForChild("PlayerGui")
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui")
			and gui.Name ~= "CameraViewfinderGui"
			and gui.Name ~= "TouchGui"
			and not gui:GetAttribute("KeepDuringCamera")
			and gui.Enabled
		then
			gui.Enabled = false
			trove:Add(function()
				if gui and gui.Parent then
					gui.Enabled = true
				end
			end)
		end
	end
end

function CameraSession.IsActive(): boolean
	return CameraState.Get()
end

function CameraSession.Enter(tool: Tool)
	if CameraState.Get() then return end

	local cameraId = CameraStats.GetIdFromTool(tool)
	activeCameraId = cameraId
	local effectsSettings = CameraStats.GetEffectsSettings(cameraId)
	local blurSettings = CameraStats.GetBlurSettings(cameraId)
	local movementSettings = CameraStats.GetMovementSettings(cameraId)
	local colorGrade = CameraStats.GetColorGradeSettings(cameraId)
	local viewfinderSettings = CameraStats.GetViewfinderSettings(cameraId)

	sessionTrove = Trove.new()

	CameraViewfinder.Show(effectsSettings, viewfinderSettings)
	sessionTrove:Add(function()
		CameraViewfinder.Hide()
	end)

	hideOtherGuis(sessionTrove)

	originalCameraMode = player.CameraMode
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	sessionTrove:Add(function()
		player.CameraMode = originalCameraMode or Enum.CameraMode.Classic
	end)

	UserInputService.MouseIconEnabled = false
	sessionTrove:Add(function()
		UserInputService.MouseIconEnabled = true
	end)

	CameraEffects.Apply(colorGrade, blurSettings)
	sessionTrove:Add(function()
		CameraEffects.Clear()
	end)

	setToolLocalTransparency(tool, 1)
	sessionTrove:Add(tool.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		end
	end))
	sessionTrove:Add(function()
		if tool and tool.Parent then
			setToolLocalTransparency(tool, 0)
		end
	end)

	CameraState.SetMovementSettings(movementSettings)
	CameraState.SetInCamera(true)

	-- Lets the server refuse actions that shouldn't interrupt an active
	-- session (e.g. the shelf swapping out an equipped, active camera).
	CameraSessionChanged:FireServer(true)
end

-- "Scope button" semantics: enters if not active, exits if active. Shared by
-- both the desktop right-click binding and the mobile Open/Close touch
-- button so the two input paths can never drift into different behavior.
function CameraSession.Toggle(tool: Tool)
	if CameraState.Get() then
		CameraSession.Exit()
	else
		CameraSession.Enter(tool)
	end
end

function CameraSession.Exit()
	if not CameraState.Get() then return end

	CameraState.SetInCamera(false)
	CameraState.SetMovementSettings(nil)

	if sessionTrove then
		sessionTrove:Clean()
		sessionTrove = nil
	end

	CameraSessionChanged:FireServer(false)
end

-- speed: studs/sec, the root part's current AssemblyLinearVelocity magnitude.
-- Drives both the world blur and the viewfinder's reticle ghost-ring.
function CameraSession.UpdateBlur(speed: number)
	if not CameraState.Get() then return end

	CameraEffects.UpdateFromSpeed(speed)
	CameraViewfinder.SetBlurAlpha(CameraEffects.GetBlurAlpha())
end

function CameraSession.Capture()
	if not CameraState.Get() then return end

	local stable = CameraState.GetStable()

	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local shotQuality = stable and "Strong" or "Weak"

	if stable then
		StrongCameraShot:FireServer(origin, direction)
	else
		WeakCameraShot:FireServer(origin, direction)
	end

	FlashSignal:Fire({
		cameraId = activeCameraId,
		shotQuality = shotQuality,
		origin = origin,
		direction = direction,
	})
	CameraSession.Exit()
end

return CameraSession
