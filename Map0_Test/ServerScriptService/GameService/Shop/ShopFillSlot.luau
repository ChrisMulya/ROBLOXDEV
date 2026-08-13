local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
local CashWallet = require(script.Parent.Parent.Player.CashWallet)
local PlayerEffects = require(script.Parent.Parent.Player.PlayerEffects)
local FlashlightEffect = require(script.Parent.Parent.Item.ItemHandlers.FlashlightEffect)

local ShopFillSlot = {}

local SLOT_NAMES = { "Slot 1", "Slot 2" }

-- Instant items (ShopItem.Instant) apply their Effect at purchase instead of
-- granting a Tool. Dispatched by Effect.Kind through the SAME handler the
-- Tool-based use path would have called, so there is one implementation of
-- what "Brighter Flashlight" means -- the only difference is what triggers it.
local INSTANT_HANDLERS: { [string]: (Player, any) -> (boolean, string) } = {
	Flashlight = function(player, item)
		return FlashlightEffect.Apply(player, { item = item })
	end,
}

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

	if not CashWallet.Has(player) then
		return false, "NoCurrency", item.Price
	end

	-- Instant path: no template to resolve, no slot to fill. Returns before the
	-- Tool machinery below so it also sells with both slots occupied.
	if item.Instant then
		local handler = item.Effect and INSTANT_HANDLERS[item.Effect.Kind]
		if not handler then
			warn("ShopFillSlot: instant item", itemId, "has no handler for kind", item.Effect and item.Effect.Kind)
			return false, "InvalidItem", item.Price
		end

		-- One per life. The effect row is the ownership record -- it is cleared
		-- on death and match end, so the next life can buy it again.
		if PlayerEffects.HasSource(player, item.Id) then
			return false, "AlreadyOwned", item.Price
		end

		local balance = CashWallet.Get(player) or 0
		if balance < item.Price then
			return false, "InsufficientFunds", item.Price
		end

		local applied, reason = handler(player, item)
		if not applied then
			-- Nothing debited yet: a failed apply costs the player nothing.
			return false, reason, item.Price
		end

		return true, "Success", item.Price, CashWallet.Add(player, -item.Price)
	end

	local itemTemplate = ShopCatalog.ResolveTemplate(itemId)
	if not itemTemplate then
		warn("ShopFillSlot: no asset for item", itemId, "(expected", item.AssetName, "under Assets.Tool.SupportItem)")
		return false, "InvalidItem", item.Price
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
