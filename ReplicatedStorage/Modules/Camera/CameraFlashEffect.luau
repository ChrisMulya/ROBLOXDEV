local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CameraFlashEffect = {}

local FADE_TIME = 0.4

function CameraFlashEffect.Play()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CameraFlashGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000 -- above the viewfinder and everything else
	screenGui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.Parent = screenGui

	local tween = TweenService:Create(
		flash,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}
	)

	tween:Play()
	tween.Completed:Connect(function()
		screenGui:Destroy()
	end)
end

return CameraFlashEffect