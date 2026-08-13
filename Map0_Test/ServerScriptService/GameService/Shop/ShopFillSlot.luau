local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
local CashWallet = require(script.Parent.Parent.Player.CashWallet)

local ShopFillSlot = {}

local SLOT_NAMES = { "Slot 1", "Slot 2" }

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
function ShopFillSlot.PurchaseItem(player, itemId)
	local item = ShopCatalog.Get(itemId)
	if not item then
		warn("ShopFillSlot: unknown item id:", itemId)
		return false, "InvalidItem", nil
	end

	if not item.Enabled then
		return false, "ItemDisabled", item.Price
	end

	local itemTemplate = ShopCatalog.ResolveTemplate(itemId)
	if not itemTemplate then
		warn("ShopFillSlot: no asset for item", itemId, "(expected", item.AssetName, "under Assets.Tool.SupportItem)")
		return false, "InvalidItem", item.Price
	end

	if not CashWallet.Has(player) then
		return false, "NoCurrency", item.Price
	end

	-- Gather both slots up front: one pass to check for a duplicate, one
	-- (the first empty one found) to grant into.
	local slots = {}
	for _, slotName in ipairs(SLOT_NAMES) do
		local slot, inCharacter = findSlot(player, slotName)
		slots[slotName] = { slot = slot, inCharacter = inCharacter }

		if slot and slot:IsA("Tool") and slot:GetAttribute("ItemId") == item.Id then
			return false, "AlreadyOwned", item.Price
		end
	end

	local targetSlot, targetInCharacter, targetName
	for _, slotName in ipairs(SLOT_NAMES) do
		local entry = slots[slotName]
		if entry.slot and entry.slot:IsA("Tool") and entry.slot:GetAttribute("IsEmpty") then
			targetSlot, targetInCharacter, targetName = entry.slot, entry.inCharacter, slotName
			break
		end
	end

	if not targetSlot then
		return false, "NoSlot", item.Price
	end

	local balance = CashWallet.Get(player) or 0
	if balance < item.Price then
		return false, "InsufficientFunds", item.Price
	end

	-- Nothing below this point may fail: clone first so a bad template can't
	-- leave a debited player empty-handed, then debit, then grant.
	local newItem = itemTemplate:Clone()
	local newBalance = CashWallet.Add(player, -item.Price)

	targetSlot:Destroy()

	newItem.Name = targetName
	newItem:SetAttribute("ItemId", item.Id)
	newItem.Parent = targetInCharacter and player.Character or player:FindFirstChild("Backpack")

	return true, "Success", item.Price, newBalance
end

return ShopFillSlot
