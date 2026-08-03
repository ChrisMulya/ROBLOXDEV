local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FloatingShotText = require(ReplicatedStorage.Modules.Camera.FloatingShotText)
local ShotResultCodes = require(ReplicatedStorage.Modules.Reward.ShotResultCodes)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local ShotFeedback = Remotes.Get("ShotFeedback")

local SHOT_COLORS = {
	Strong = Color3.fromRGB(85, 255, 127),
	Weak = Color3.fromRGB(255, 200, 85),
}

local MISS_DURATION = 0.8

local function showMiss()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShotMissGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 200, 0, 40)
	label.Position = UDim2.new(0.5, -100, 0.55, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextStrokeTransparency = 0.5
	label.Text = "Missed"
	label.Parent = screenGui

	local tween = TweenService:Create(
		label,
		TweenInfo.new(MISS_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1, TextStrokeTransparency = 1}
	)
	tween:Play()
	tween.Completed:Connect(function()
		screenGui:Destroy()
	end)
end

-- data.amounts is nil whenever data.resultCode isn't "Awarded" (rule failed,
-- unknown target, on a repeat-policy cooldown, ...) -- still shows
-- band/meters, with ShotResultCodes explaining why instead of a bare
-- "No Reward" string that never said what actually happened.
local function buildHitText(data)
	local lines = {
		data.bandLabel or string.upper(data.shotType),
		string.format("%.1fm", data.meters),
	}

	if data.amounts then
		local rewardLine = string.format("+%d XP  +%d Score", data.amounts.XP or 0, data.amounts.Score or 0)
		if data.rollMultiplier then
			rewardLine ..= string.format("  (%.0f%%)", data.rollMultiplier * 100)
		end
		table.insert(lines, rewardLine)
	else
		table.insert(lines, ShotResultCodes.GetMessage(data.resultCode))
	end

	return table.concat(lines, "\n")
end

ShotFeedback.OnClientEvent:Connect(function(data)
	if not data.hit then
		showMiss()
		return
	end

	local text = buildHitText(data)
	local color = SHOT_COLORS[data.shotType] or Color3.new(1, 1, 1)

	FloatingShotText.Show(data.position, text, color)
end)
