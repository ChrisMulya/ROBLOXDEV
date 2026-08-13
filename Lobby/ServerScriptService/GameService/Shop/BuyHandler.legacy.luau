local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopFillSlot = require(game.ServerScriptService.GameService.Shop.ShopFillSlot)
local ShopSession = require(script.Parent.ShopSession)
local ShopCatalog = require(ReplicatedStorage.Modules.Shop.ShopCatalog)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local Cooldown = require(ReplicatedStorage.Modules.Shared.Cooldown)
local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)

local BuyItem = Remotes.Get("BuyItem")
local PurchaseResult = Remotes.Get("PurchaseResult")

local MAX_INTERACT_DISTANCE = 12 -- studs; same margin CameraShelfHandler uses for its prompt
local purchaseCooldown = Cooldown.new(0.5)

-- Shop parts are tagged IsShop=true in Studio (mirrors IsCameraShelf). Kept
-- current via DescendantAdded in addition to the boot-time scan below, so a
-- part created after this Script starts (streaming, a map loaded after boot)
-- is not silently invisible to distance checks.
local shopParts: { BasePart } = {}
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant:GetAttribute("IsShop") == true then
		table.insert(shopParts, descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") and descendant:GetAttribute("IsShop") == true then
		table.insert(shopParts, descendant)
	end
end)

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

local function fail(player: Player, itemId: string, reason: string, price: number?)
	PurchaseResult:FireClient(player, {
		success = false,
		reason = reason,
		itemId = itemId,
		price = price,
	})
end

BuyItem.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" then
		return
	end

	-- Cooldown first: an out-of-range or otherwise-invalid spammer should not
	-- get a PurchaseResult fired for every click, only for the first one in
	-- each window.
	if not purchaseCooldown:Check(player.UserId) then
		return
	end

	if not (ServerRole.Is("GameServer") and MatchStates.IsKitGranted(MatchManager.Get())) then
		fail(player, itemId, "ShopUnavailable", nil)
		return
	end

	if not ShopSession.IsOpen(player) then
		fail(player, itemId, "NotOpen", nil)
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or nearestShopDistance(rootPart) > MAX_INTERACT_DISTANCE then
		fail(player, itemId, "TooFarAway", nil)
		return
	end

	local success, reason, price, balance = ShopFillSlot.PurchaseItem(player, itemId)
	local item = ShopCatalog.Get(itemId)

	PurchaseResult:FireClient(player, {
		success = success,
		reason = reason,
		itemId = itemId,
		displayName = item and item.DisplayName or itemId,
		price = price,
		balance = balance,
	})
end)
