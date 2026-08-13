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
-- Effect is data for ItemUseService/ItemHandlers, keyed off the Tool's ItemId
-- attribute -- the Shop's own job stays selling and granting; nothing in this
-- module reads Effect itself. Three shapes, by Kind:
--   Kind = "Stat"        -- Stat, Delta, Duration (seconds, nil = no expiry).
--                            Applied via PlayerEffects as a delta against the
--                            PlayerStats base, never an absolute.
--   Kind = "Deploy"       -- PlacedAsset (name under Assets.Tool.SupportItem.
--                            PlacedItem), Lifetime (seconds, nil = until match
--                            end/owner death). Consume marks whether the held
--                            Tool is destroyed on successful use; ReplaceWith
--                            names another catalog Id to swap the held Tool
--                            INTO instead (Compact Speaker -> its remotes,
--                            Portable CCTV -> its tablet). Consume and
--                            ReplaceWith are mutually exclusive -- ReplaceWith
--                            wins, and Consume is written false alongside it
--                            for readability.
--   Kind = "Control"      -- an instant, hold-less use. ControlKind selects the
--                            handler's behaviour. Used by the post-placement
--                            tablet, which toggles a CCTV view.
--   Kind = "Trigger"      -- a one-shot that acts on something already in the
--                            world, with the ordinary hold. Consume empties the
--                            slot on success only -- a trigger that finds
--                            nothing to fire keeps the tool.
--   Kind = "Flashlight"   -- RangeDelta/BrightnessDelta/AngleDelta, applied
--                            via PlayerEffects the same way Stat is; no new
--                            Tool or slot. Currently only used by an Instant
--                            item, so it is applied at purchase, not on use.
-- HoldSeconds is common to all three: the generic 3-second hold every usable
-- item shares, kept per-item (not hardcoded in ItemUseService) so a future
-- item can tune it without touching the lifecycle owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type ShopItem = {
	Id: string,
	AssetName: string,
	AssetFolder: string?, -- optional subfolder of Assets.Tool.SupportItem, e.g. "ItemRemotes"
	DisplayName: string,
	Price: number,
	Description: string,
	Order: number,
	Enabled: boolean,
	-- true = the purchase itself applies the Effect; no Tool is cloned and no
	-- slot is used, so it also sells with both slots full. ShopFillSlot owns
	-- this path and rejects a second buy with AlreadyOwned while the effect is
	-- still live (PlayerEffects.HasSource) -- an instant item has no Tool for
	-- the ordinary slot-scan duplicate check to find. Instant items never
	-- reach ItemUseService, so their Effect needs no HoldSeconds/Consume.
	Instant: boolean?,
	Effect: any?, -- ItemUseGuard/ItemHandlers read this; see the per-Kind shapes below
}

local ShopCatalog = {}

local Items: { [string]: ShopItem } = {
	MotionSensor = {
		Id = "MotionSensor",
		AssetName = "MotionSensor",
		DisplayName = "Motion Sensor",
		Price = 200,
		Description = "Place a sensor that detects monsters within 10 Meters.",
		Order = 1,
		Enabled = true,
		Effect = {
			Kind = "Deploy",
			HoldSeconds = 3,
			Consume = true,
			PlacedAsset = "PlacedMotionSensor",
			Lifetime = nil, -- until match end / owner death
			DetectRadius = 35,
		},
	},
	BrighterFlashlight = {
		Id = "BrighterFlashlight",
		AssetName = "BetterFlashlight",
		DisplayName = "Brighter Flashlight",
		Price = 150,
		Description = "Permanently widens your flashlight's range, brightness, and beam radius for this life. Applies the moment you buy it.",
		Order = 2,
		Enabled = true,
		-- Bought, not carried: no Tool, no slot, no 3-second hold. See the
		-- Instant note in the type above. HoldSeconds/Consume are gone with the
		-- Tool that would have honoured them.
		Instant = true,
		Effect = {
			Kind = "Flashlight",
			RangeDelta = 64, -- 56 -> 120 (engine cap)
			BrightnessDelta = 1.4, -- 1.4 -> 2.8 (100%)
			AngleDelta = 48, -- 48 -> 96 (100% wider cone/beam radius)
			Duration = nil, -- per-life: cleared by death/match end only
		},
	},
	EnergyDrink = {
		Id = "EnergyDrink",
		AssetName = "EnergyDrink",
		DisplayName = "Energy Drink",
		Price = 60,
		Description = "Raises your max stamina to 150 for 45 seconds.",
		Order = 3,
		Enabled = true,
		Effect = {
			Kind = "Stat",
			HoldSeconds = 3,
			Consume = true,
			Stat = "MaxStamina",
			Delta = 50, -- 100 -> 150
			Duration = 45,
		},
	},
	Pills = {
		Id = "Pills",
		AssetName = "Pills",
		DisplayName = "Pills",
		Price = 50,
		Description = "Raises your walk speed to 15 for 120 seconds.",
		Order = 4,
		Enabled = true,
		Effect = {
			Kind = "Stat",
			HoldSeconds = 3,
			Consume = true,
			Stat = "WalkSpeed",
			Delta = 5, -- 10 -> 15
			Duration = 120,
		},
	},
	AdrenalineShot = {
		Id = "AdrenalineShot",
		AssetName = "AdrenalineShot",
		DisplayName = "Adrenaline Shot",
		Price = 80,
		Description = "Raises your sprint speed to 37.5 for 30 seconds.",
		Order = 5,
		Enabled = true,
		Effect = {
			Kind = "Stat",
			HoldSeconds = 3,
			Consume = true,
			Stat = "SprintSpeed",
			Delta = 12.5, -- 25 -> 37.5
			Duration = 30,
		},
	},
	CompactSpeaker = {
		Id = "CompactSpeaker",
		AssetName = "CompactSpeaker",
		DisplayName = "CompactSpeaker",
		Price = 120,
		Description = "Place a speaker, then set it off with the remotes to lure monsters for 15 seconds.",
		Order = 6,
		Enabled = true,
		Effect = {
			Kind = "Deploy",
			HoldSeconds = 3,
			Consume = false, -- replaced, not destroyed -- see ReplaceWith
			ReplaceWith = "CompactSpeakerRemotes",
			PlacedAsset = "PlacedCompactSpeaker",
			-- Seconds of noise once ARMED by the remotes, not how long the
			-- placed object survives: a placed-but-unfired speaker is inert
			-- and waits indefinitely. See ItemWorld/SpeakerService.
			Lifetime = 15,
			LureRadius = 140,
		},
	},
	PortableCCTV = {
		Id = "PortableCCTV",
		AssetName = "PortableCCTV",
		DisplayName = "Portable CCTV",
		Price = 250,
		Description = "Place a camera, then click the tablet to look through it. Click again or switch slots to exit.",
		Order = 7,
		Enabled = true,
		Effect = {
			Kind = "Deploy",
			HoldSeconds = 3,
			Consume = false, -- replaced, not destroyed -- see ReplaceWith
			ReplaceWith = "PortableCCTVTablet",
			PlacedAsset = "PlacedPortableCCTV",
			Lifetime = nil, -- until match end / owner death
		},
	},

	-- ===== Not sold: post-use replacement tools =====
	-- Enabled = false keeps these out of GetOrdered (so no shop row) and makes
	-- ShopFillSlot reject a direct BuyItem for them with ItemDisabled. They are
	-- here only so the swap has a catalog row to resolve an asset and an ItemId
	-- from -- same "one entry per item, no hardcoded name lists" rule the rest
	-- of this table exists to enforce.

	CompactSpeakerRemotes = {
		Id = "CompactSpeakerRemotes",
		AssetName = "CompactSpeakerRemotes",
		AssetFolder = "ItemRemotes",
		DisplayName = "Compact Speaker Remotes",
		Price = 0,
		Description = "",
		Order = 100,
		Enabled = false,
		-- Trigger kind: ARMS the inert speaker the placement left in the world
		-- (sound + lure + the 15s window + the monster-contact rule all start
		-- there, not at placement). Runs the ordinary 3-second hold rather than
		-- the tablet's instant toggle -- this is a one-shot, and the slot empties
		-- on success.
		Effect = {
			Kind = "Trigger",
			HoldSeconds = 3,
			Consume = true,
		},
	},
	PortableCCTVTablet = {
		Id = "PortableCCTVTablet",
		AssetName = "PortableCCTVTablet",
		AssetFolder = "ItemRemotes",
		DisplayName = "Portable CCTV Tablet",
		Price = 0,
		Description = "",
		Order = 101,
		Enabled = false,
		-- Control kind: an instant toggle, no hold. The tablet IS the viewing
		-- controller, so a 3-second hold to glance at a camera (and another to
		-- look away) would be a usability defect, not a security one.
		Effect = {
			Kind = "Control",
			ControlKind = "CCTV",
		},
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

	local searchFolder = supportFolder
	if item.AssetFolder then
		searchFolder = supportFolder:FindFirstChild(item.AssetFolder)
		if not searchFolder then
			return nil
		end
	end

	local template = searchFolder:FindFirstChild(item.AssetName)
	if template and template:IsA("Tool") then
		return template
	end
	return nil
end

-- Same lookup, for the world object a Deploy-kind item places
-- (Assets.Tool.SupportItem.PlacedItem.<name>). Separate from ResolveTemplate
-- because a placed object is a Model/BasePart, not a Tool -- sharing one
-- function would mean callers type-checking a union for no reason.
function ShopCatalog.ResolvePlacedAsset(assetName: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local toolFolder = assets and assets:FindFirstChild("Tool")
	local supportFolder = toolFolder and toolFolder:FindFirstChild("SupportItem")
	local placedFolder = supportFolder and supportFolder:FindFirstChild("PlacedItem")
	if not placedFolder then
		return nil
	end
	return placedFolder:FindFirstChild(assetName)
end

return ShopCatalog
