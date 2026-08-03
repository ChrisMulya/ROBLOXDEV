local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopPrices = require(ReplicatedStorage.Modules.ShopPrices)

local ShopFillSlot = {}

local function findSlot(player, slotName)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	local slot = backpack and backpack:FindFirstChild(slotName)
	local inCharacter = false

	if not slot and character then
		slot = character:FindFirstChild(slotName)
		inCharacter = true
	end

	return slot, inCharacter
end

-- Returns: success (bool), reason (string), price (number or nil)
function ShopFillSlot.PurchaseItem(player, itemName)
	local itemTemplate = ReplicatedStorage.Assets.Tool.SupportItem:FindFirstChild(itemName)
	if not itemTemplate then
		warn("Item template not found:", itemName)
		return false, "InvalidItem", nil
	end

	local price = ShopPrices.GetPrice(itemName)
	if not price then
		warn("No price configured for:", itemName)
		return false, "InvalidItem", nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		warn("Player has no Cash value:", player.Name)
		return false, "NoCurrency", price
	end

	local slot1, slot1InCharacter = findSlot(player, "Slot 1")
	local slot2, slot2InCharacter = findSlot(player, "Slot 2")

	local targetSlot, targetInCharacter, targetName

	if slot1 and slot1:IsA("Tool") and slot1:GetAttribute("IsEmpty") then
		targetSlot, targetInCharacter, targetName = slot1, slot1InCharacter, "Slot 1"
	elseif slot2 and slot2:IsA("Tool") and slot2:GetAttribute("IsEmpty") then
		targetSlot, targetInCharacter, targetName = slot2, slot2InCharacter, "Slot 2"
	else
		print("No Empty Slot")
		return false, "NoSlot", price
	end

	if cash.Value < price then
		print(player.Name, "cannot afford", itemName, "- has", cash.Value, "needs", price)
		return false, "InsufficientFunds", price
	end

	cash.Value -= price

	targetSlot:Destroy()

	local newItem = itemTemplate:Clone()
	newItem.Name = targetName
	newItem.Parent = targetInCharacter and player.Character or player:FindFirstChild("Backpack")

	return true, "Success", price
end

return ShopFillSlot