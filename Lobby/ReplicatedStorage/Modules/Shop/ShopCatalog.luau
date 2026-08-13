-- Single source of truth for what the Shop sells. Replaces ShopPrices.luau --
-- previously an item had to exist in 3 unlinked places (a price table, a
-- Tool under Assets.Tool.SupportItem, and a hardcoded client-side name list)
-- to be purchasable at all. Now it's one entry here.
--
-- Id is the stable key sent over the wire and written as the ItemId
-- attribute on a granted Tool -- it must never change once players can hold
-- an item. AssetName is separate from Id because the Studio asset for
-- "Brighter Flashlight" is actually named "BetterFlashlight"; renaming the
-- asset to match Id is not required and should not be done.
--
-- Effect is reserved for a future gameplay-effect system (duration/magnitude/
-- target/etc.) and is nil on every entry today. Nothing in the Shop reads
-- it -- the Shop's job is selling and granting, not applying effects. A
-- future effect system requires this module, reads entry.Effect, and keys
-- off the Tool's ItemId attribute; that requires zero edits here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type ShopItem = {
	Id: string,
	AssetName: string,
	DisplayName: string,
	Price: number,
	Description: string,
	Order: number,
	Enabled: boolean,
	Effect: any?, -- reserved: { Type, TargetSystem, Activation, Duration, Magnitude }
}

local ShopCatalog = {}

local Items: { [string]: ShopItem } = {
	MotionSensor = {
		Id = "MotionSensor",
		AssetName = "MotionSensor",
		DisplayName = "Motion Sensor",
		Price = 200,
		Description = "Detect monster in 10 meters range.",
		Order = 1,
		Enabled = true,
	},
	BrighterFlashlight = {
		Id = "BrighterFlashlight",
		AssetName = "BetterFlashlight",
		DisplayName = "Brighter Flashlight",
		Price = 150,
		Description = "More brighter flashlight.",
		Order = 2,
		Enabled = true,
	},
	EnergyDrink = {
		Id = "EnergyDrink",
		AssetName = "EnergyDrink",
		DisplayName = "Energy Drink",
		Price = 60,
		Description = "Gives 50% more stamina for 45 seconds.",
		Order = 3,
		Enabled = true,
	},
	Pills = {
		Id = "Pills",
		AssetName = "Pills",
		DisplayName = "Pills",
		Price = 50,
		Description = "Walk 30% Faster for 120 seconds.",
		Order = 4,
		Enabled = true,
	},
	AdrenalineShot = {
		Id = "AdrenalineShot",
		AssetName = "AdrenalineShot",
		DisplayName = "Adrenaline Shot",
		Price = 80,
		Description = "Sprint 50% Faster for 30 seconds.",
		Order = 5,
		Enabled = true,
	},
	CompactSpeaker = {
		Id = "CompactSpeaker",
		AssetName = "CompactSpeaker",
		DisplayName = "CompactSpeaker",
		Price = 120,
		Description = "Make noise for 15 seconds.",
		Order = 6,
		Enabled = true,
	},
	PortableCCTV = {
		Id = "PortableCCTV",
		AssetName = "PortableCCTV",
		DisplayName = "Portable CCTV",
		Price = 250,
		Description = "A portable CCTV.",
		Order = 7,
		Enabled = true,
	},
}

function ShopCatalog.Get(id: string): ShopItem?
	return Items[id]
end

-- Enabled entries only, sorted by Order. Rebuilt on every call rather than
-- cached -- this is a handful of items, and callers (UI rebuilds, purchase
-- validation) are already infrequent.
function ShopCatalog.GetOrdered(): { ShopItem }
	local ordered = {}
	for _, item in pairs(Items) do
		if item.Enabled then
			table.insert(ordered, item)
		end
	end
	table.sort(ordered, function(a, b)
		return a.Order < b.Order
	end)
	return ordered
end

function ShopCatalog.GetPrice(id: string): number?
	local item = Items[id]
	return item and item.Price
end

-- Lazy lookup, same resilience pattern as CameraInventory.templatesFolder --
-- the Assets tree is hand-placed in Studio and is not guaranteed present.
-- Returns nil rather than erroring at every step so a missing folder/tool
-- surfaces as InvalidItem, not a hard server error.
function ShopCatalog.ResolveTemplate(id: string): Tool?
	local item = Items[id]
	if not item then
		return nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local toolFolder = assets and assets:FindFirstChild("Tool")
	local supportFolder = toolFolder and toolFolder:FindFirstChild("SupportItem")
	if not supportFolder then
		return nil
	end

	local template = supportFolder:FindFirstChild(item.AssetName)
	if template and template:IsA("Tool") then
		return template
	end
	return nil
end

return ShopCatalog
