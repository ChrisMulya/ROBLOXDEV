local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SoundIds = require(ReplicatedStorage.Modules.SoundIds)
local PurchaseResultCodes = require(ReplicatedStorage.Modules.Shop.PurchaseResultCodes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PurchaseNotification = {}

local function playSound(soundName)
	local soundId = SoundIds.GetSoundId(soundName)
	if not soundId then
		return -- no asset id configured yet, skip silently
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function showText(text, color)
	local screenGui = playerGui:FindFirstChild("PurchaseNotificationGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PurchaseNotificationGui"
		screenGui.ResetOnSpawn = false
		-- DisplayOrder 60 -- registered in UIBuilder.CreateScreenGui's comment.
		-- Must beat ShopGui (35): every purchase result fires while the shop
		-- panel is open, so at the default 0 the message rendered behind the
		-- thing it is a response to.
		screenGui.DisplayOrder = 60
		screenGui.Parent = playerGui
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 400, 0, 40)
	label.Position = UDim2.new(0.5, -200, 0.15, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextTransparency = 0
	label.Parent = screenGui

	local tween = TweenService:Create(
		label,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, Position = label.Position - UDim2.new(0, 0, 0.05, 0)}
	)

	-- Spawned so this fade-out doesn't block the caller's thread -- Handle is
	-- invoked directly off the PurchaseResult remote's OnClientEvent, and a
	-- blocking task.wait here used to stall that connection for a full second.
	task.spawn(function()
		task.wait(1)
		tween:Play()
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

function PurchaseNotification.Handle(resultData)
	local displayName = resultData.displayName or resultData.itemId or resultData.itemName
	if resultData.success then
		local text = string.format("Successfully bought %s for $%d", displayName, resultData.price)
		showText(text, Color3.fromRGB(85, 255, 127))
		playSound("KaChing")
	else
		local text = PurchaseResultCodes.GetMessage(resultData.reason, displayName)
		showText(text, Color3.fromRGB(255, 85, 85))
	end
end

return PurchaseNotification
