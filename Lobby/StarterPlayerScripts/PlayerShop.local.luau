local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local OpenShop = Remotes.Get("OpenShop")
local BuyItem = Remotes.Get("BuyItem")
local PurchaseResult = Remotes.Get("PurchaseResult")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local character = player.Character or player.CharacterAdded:Wait()

local UserInputService = game:GetService("UserInputService")

local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local controls = playerModule:GetControls()

local ShopGui = require(ReplicatedStorage.Modules.Shop.ShopGui)
local PurchaseNotification = require(ReplicatedStorage.Modules.Shop.PurchaseNotification)

local MAX_DISTANCE = 10
local distanceCheckConnection = nil
local mouseLockConnection = false

local SLOT_NAMES = { "Slot 1", "Slot 2" }

-- Reads the two carry slots straight off Backpack + Character (whichever
-- currently holds each) to compute what ShopGui.Refresh needs: which item
-- ids are owned, and how many slots are free. Pure read -- no remotes, since
-- slot state replicates to the client as ordinary Instance data.
local function readSlotState(): ({ [string]: boolean }, number)
	local ownedIds = {}
	local freeCount = 0

	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character

	for _, slotName in ipairs(SLOT_NAMES) do
		local slot = backpack and backpack:FindFirstChild(slotName)
		if not slot and char then
			slot = char:FindFirstChild(slotName)
		end

		if slot and slot:IsA("Tool") then
			if slot:GetAttribute("IsEmpty") then
				freeCount += 1
			else
				local itemId = slot:GetAttribute("ItemId")
				if itemId then
					ownedIds[itemId] = true
				end
			end
		end
	end

	return ownedIds, freeCount
end

local function refreshGui()
	if not ShopGui.IsBuilt() then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local ownedIds, freeCount = readSlotState()
	ShopGui.Refresh(cash and cash.Value or 0, ownedIds, freeCount)
end

ShopGui.SetOnBuy(function(itemId)
	ShopGui.SetPending(itemId, true)
	refreshGui()
	BuyItem:FireServer(itemId)
end)

-- Open/close behavior. isShopOpen (not screenGui.Enabled, and not ShopGui's
-- own internal state) is the source of truth for whether cleanup is needed --
-- CameraSession.hideOtherGuis can set the ScreenGui's Enabled to false out
-- from under this script while the shop is still logically open, which used
-- to skip closeShop's cleanup entirely and leak the distance-check Heartbeat
-- and the mouse-unlock render-step across every subsequent respawn. This is
-- also why ShopGui's own X button doesn't call ShopGui.Hide() directly --
-- see ShopGui.SetOnCloseRequested below, wired to closeShop so the panel's
-- close button goes through the same cleanup path as every other trigger.
local isShopOpen = false

local function closeShop()
	if not isShopOpen then
		return
	end
	isShopOpen = false

	ShopGui.Hide()
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

ShopGui.SetOnCloseRequested(closeShop)

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

	ShopGui.Show()
	refreshGui()
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
	if resultData.itemId then
		ShopGui.SetPending(resultData.itemId, false)
	end
	refreshGui()
	PurchaseNotification.Handle(resultData)
end)

-- Refresh whenever cash or slot contents change, so affordability/owned/full
-- states stay live while the shop is open (and cost nothing while it's not --
-- Refresh no-ops before ShopGui has been built).
player:WaitForChild("leaderstats"):WaitForChild("Cash").Changed:Connect(refreshGui)

local function watchContainer(container: Instance)
	container.ChildAdded:Connect(refreshGui)
	container.ChildRemoved:Connect(refreshGui)
end

local backpack = player:WaitForChild("Backpack")
watchContainer(backpack)
watchContainer(character)
player.CharacterAdded:Connect(watchContainer)
