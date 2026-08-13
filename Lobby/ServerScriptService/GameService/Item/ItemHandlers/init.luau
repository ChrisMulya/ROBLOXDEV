-- Registry: item id -> handler module. Same shape as Pickup/PickupHandlers.
-- A handler exports Apply(player, ctx) -> (ok: boolean, code: string) where
-- ctx = { tool: Tool, item: ShopCatalog.ShopItem }. ItemUseService calls
-- Apply only once ItemUseGuard has already confirmed the hold completed
-- validly -- a handler never sees the hold, the progress bar, or the
-- movement lock, only a successful completion.
--
-- StatEffect/FlashlightEffect are generic and reused across multiple ids --
-- Energy Drink, Pills, and Adrenaline Shot are identical in shape (apply one
-- PlayerEffects delta from ShopCatalog's own Effect data) and differ only in
-- which stat, so three near-identical files would just be duplication.

local StatEffect = require(script.StatEffect)
local FlashlightEffect = require(script.FlashlightEffect)
local MotionSensor = require(script.MotionSensor)
local CompactSpeaker = require(script.CompactSpeaker)
local PortableCCTV = require(script.PortableCCTV)
local CCTVControl = require(script.CCTVControl)
local SpeakerRemote = require(script.SpeakerRemote)

local handlers = {
	MotionSensor = MotionSensor,
	BrighterFlashlight = FlashlightEffect,
	EnergyDrink = StatEffect,
	Pills = StatEffect,
	AdrenalineShot = StatEffect,
	-- The two deployables the player actually buys, each of which places its
	-- world object and swaps itself for a controller tool (see ShopCatalog's
	-- ReplaceWith) -- followed by those two controllers. The speaker's remotes
	-- ARM the inert speaker they placed (one-shot, 3s hold); the CCTV's tablet
	-- toggles the placed camera's view (repeatable, instant).
	CompactSpeaker = CompactSpeaker,
	CompactSpeakerRemotes = SpeakerRemote,
	PortableCCTV = PortableCCTV,
	PortableCCTVTablet = CCTVControl,
}

local ItemHandlers = {}

function ItemHandlers.Get(itemId: string)
	return handlers[itemId]
end

return ItemHandlers
