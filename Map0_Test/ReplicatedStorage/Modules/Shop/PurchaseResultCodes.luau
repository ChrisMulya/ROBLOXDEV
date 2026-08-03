-- Shared reason codes for a shop purchase's outcome, and their player-facing
-- display strings. Mirrors Reward/ShotResultCodes and CameraShelf/
-- ShelfResultCodes -- completes the pattern for the one remaining remote
-- (BuyItem/PurchaseResult) that previously hardcoded its messages as a local
-- table inside PurchaseNotification, duplicating ShopFillSlot's reason codes
-- by hand instead of sharing one source of truth.

local PurchaseResultCodes = {}

PurchaseResultCodes.Messages = {
	InvalidItem = "That item isn't available.",
	NoCurrency = "Currency not set up.",
	NoSlot = "No empty slot available.",
	InsufficientFunds = "Not enough cash for %s.",
	TooFarAway = "Move closer to the shop.",
}

-- itemName fills a "%s" placeholder when the template has one (InsufficientFunds).
function PurchaseResultCodes.GetMessage(code: string?, itemName: string?): string
	local template = code and PurchaseResultCodes.Messages[code]
	if not template then
		return "Purchase failed."
	end
	if itemName and template:find("%%s") then
		return string.format(template, itemName)
	end
	return template
end

return PurchaseResultCodes
