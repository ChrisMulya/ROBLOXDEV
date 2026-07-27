local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopFillSlot = require(game.ServerScriptService.GameService.Shop.ShopFillSlot)

local BuyItem = ReplicatedStorage.Remotes:WaitForChild("BuyItem")
local PurchaseResult = ReplicatedStorage.Remotes:WaitForChild("PurchaseResult")

BuyItem.OnServerEvent:Connect(function(player, itemName)
	local success, reason, price = ShopFillSlot.PurchaseItem(player, itemName)

	if success then
		print(player.Name, "bought", itemName)
	else
		print(player.Name, "purchase failed for", itemName, "-", reason)
	end

	PurchaseResult:FireClient(player, {
		success = success,
		reason = reason,
		itemName = itemName,
		price = price,
	})
end)