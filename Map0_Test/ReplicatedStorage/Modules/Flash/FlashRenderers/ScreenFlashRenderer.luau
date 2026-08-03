-- Full-screen white fade. Moved verbatim out of the old CameraFlashEffect,
-- with one fix: the GUI + tween are now created once and reused instead of
-- stacking a fresh ScreenGui per call (rapid shutter presses used to leave
-- N overlapping fades all racing to Destroy the wrong instance).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ScreenFlashRenderer = {}

local player = Players.LocalPlayer

local screenGui: ScreenGui? = nil
local flashFrame: Frame? = nil
local activeTween: Tween? = nil

local function ensureGui()
	if screenGui and screenGui.Parent then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CameraFlashGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000 -- above the viewfinder and everything else
	screenGui.Parent = playerGui

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.BorderSizePixel = 0
	flashFrame.BackgroundTransparency = 1
	flashFrame.Parent = screenGui
end

-- flashSettings: CameraStats Flash block -- { Color, Duration, ScreenIntensity, ... }
function ScreenFlashRenderer.Play(flashSettings)
	if not flashSettings.Enabled or flashSettings.ScreenIntensity <= 0 then
		return
	end

	ensureGui()

	if activeTween then
		activeTween:Cancel()
	end

	flashFrame.BackgroundColor3 = flashSettings.Color
	flashFrame.BackgroundTransparency = 1 - flashSettings.ScreenIntensity

	activeTween = TweenService:Create(
		flashFrame,
		TweenInfo.new(flashSettings.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	activeTween:Play()
end

return ScreenFlashRenderer
