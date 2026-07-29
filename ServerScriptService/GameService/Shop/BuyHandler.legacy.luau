local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopFillSlot = require(game.ServerScriptService.GameService.Shop.ShopFillSlot)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local BuyItem = Remotes.Get("BuyItem")
local PurchaseResult = Remotes.Get("PurchaseResult")

local MAX_INTERACT_DISTANCE = 12 -- studs; same margin CameraShelfHandler uses for its prompt
local purchaseCooldown = Cooldown.new(0.5)

-- Shop parts are tagged IsShop=true in Studio (mirrors IsCameraShelf). Scanned
-- once at boot rather than per-purchase; there are only ever a handful of
-- shop locations on a map.
local shopParts: { BasePart } = {}
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant:GetAttribute("IsShop") == true then
		table.insert(shopParts, descendant)
	end
end

local function nearestShopDistance(rootPart: BasePart): number
	local nearest = math.huge
	for _, shopPart in ipairs(shopParts) do
		if shopPart.Parent then
			local distance = (rootPart.Position - shopPart.Position).Magnitude
			if distance < nearest then
				nearest = distance
			end
		end
	end
	return nearest
end

BuyItem.OnServerEvent:Connect(function(player, itemName)
	if typeof(itemName) ~= "string" then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or nearestShopDistance(rootPart) > MAX_INTERACT_DISTANCE then
		PurchaseResult:FireClient(player, {
			success = false,
			reason = "TooFarAway",
			itemName = itemName,
		})
		return
	end

	if not purchaseCooldown:Check(player.UserId) then
		return
	end

	local success, reason, price = ShopFillSlot.PurchaseItem(player, itemName)

	PurchaseResult:FireClient(player, {
		success = success,
		reason = reason,
		itemName = itemName,
		price = price,
	})
end)
