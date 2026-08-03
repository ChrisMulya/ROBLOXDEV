local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local OpenShop = Remotes.Get("OpenShop")
local BuyItem = Remotes.Get("BuyItem")


local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local RunService = game:GetService("RunService")
local character = player.Character or player.CharacterAdded:Wait()

local UserInputService = game:GetService("UserInputService")

local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local controls = playerModule:GetControls()

local MAX_DISTANCE = 10
local distanceCheckConnection = nil
local mouseLockConnection = false

local PurchaseResult = Remotes.Get("PurchaseResult")
local PurchaseNotification = require(ReplicatedStorage.Modules.Shop.PurchaseNotification)
local ShopPrices = require(ReplicatedStorage.Modules.ShopPrices)

-- Build the Shop GUI once, keep it hidden until needed
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0, 400, 0, 300)
frame.Position = UDim2.new(0.5, -200, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
title.Text = "Shop"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.Text = "X"
closeButton.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Parent = frame

local itemList = Instance.new("UIListLayout")
itemList.Padding = UDim.new(0, 8)
itemList.SortOrder = Enum.SortOrder.LayoutOrder

local itemContainer = Instance.new("Frame")
itemContainer.Size = UDim2.new(1, -20, 1, -60)
itemContainer.Position = UDim2.new(0, 10, 0, 50)
itemContainer.BackgroundTransparency = 1
itemContainer.Parent = frame
itemList.Parent = itemContainer

-- Driven by ShopPrices instead of a hardcoded name list -- previously this
-- list and ShopPrices.Prices had to be kept in sync by hand, and the button
-- showed no price at all.
local ITEM_NAMES = {"Item1", "Item2", "Item3", "Item4"}

for i, itemName in ipairs(ITEM_NAMES) do
	local itemButton = Instance.new("TextButton")
	itemButton.Name = itemName
	itemButton.Size = UDim2.new(1, 0, 0, 45)
	itemButton.LayoutOrder = i
	itemButton.Text = string.format("Buy %s ($%d)", itemName, ShopPrices.GetPrice(itemName) or 0)
	itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	itemButton.TextColor3 = Color3.new(1, 1, 1)
	itemButton.Parent = itemContainer

	itemButton.MouseButton1Click:Connect(function()
		BuyItem:FireServer(itemName)
	end)
end

-- Open/close behavior. isShopOpen (not screenGui.Enabled) is the source of
-- truth for whether cleanup is needed -- CameraSession.hideOtherGuis can set
-- screenGui.Enabled = false out from under this script while the shop is
-- still logically open, which used to skip closeShop's cleanup entirely and
-- leak the distance-check Heartbeat and the mouse-unlock render-step across
-- every subsequent respawn.
local isShopOpen = false

local function closeShop()
	if not isShopOpen then
		return
	end
	isShopOpen = false

	screenGui.Enabled = false
	controls:Enable()

	if mouseLockConnection then
		RunService:UnbindFromRenderStep("ShopMouseUnlock")
		mouseLockConnection = false
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default -- changed from LockCenter

	if distanceCheckConnection then
		distanceCheckConnection:Disconnect()
		distanceCheckConnection = nil
	end
end

local function bindDeathHandler(char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Died:Connect(closeShop)
end

bindDeathHandler(character) -- for the character that already exists when this script starts

player.CharacterAdded:Connect(function(newCharacter)
	closeShop()
	bindDeathHandler(newCharacter)
end)

local function openShop(shopPart)
	if isShopOpen and distanceCheckConnection then
		distanceCheckConnection:Disconnect()
		distanceCheckConnection = nil
	end
	isShopOpen = true

	screenGui.Enabled = true
	controls:Disable()
	UserInputService.MouseIconEnabled = true

	if not mouseLockConnection then
		mouseLockConnection = true
		RunService:BindToRenderStep("ShopMouseUnlock", Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
	end

	distanceCheckConnection = RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local distance = (hrp.Position - shopPart.Position).Magnitude
		if distance > MAX_DISTANCE then
			closeShop()
		end
	end)
end

OpenShop.OnClientEvent:Connect(function(shopPart)
	openShop(shopPart)
end)

PurchaseResult.OnClientEvent:Connect(function(resultData)
	PurchaseNotification.Handle(resultData)
end)

closeButton.MouseButton1Click:Connect(closeShop)