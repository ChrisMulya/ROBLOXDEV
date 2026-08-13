-- Shared reason codes for the item-use lifecycle's outcome, and their
-- player-facing display strings. Same pattern as Shop/PurchaseResultCodes --
-- one source of truth instead of a client-side table duplicating
-- ItemUseGuard's codes by hand.

local ItemUseResultCodes = {}

ItemUseResultCodes.Messages = {
	TooFast = "Slow down.",
	NotInMatch = "You can't do that right now.",
	NotAlive = "You can't do that right now.",
	NoCharacter = "You can't do that right now.",
	NotEquipped = "Equip the item first.",
	InvalidItem = "That item isn't available.",
	NotUsable = "That item can't be used.",
	NoGround = "Find solid ground first.",
	Moved = "You moved.",
	Cancelled = "Cancelled.",
	Disconnected = "Cancelled.",
	NoSlot = "No empty slot available.",
	NoCamera = "Your camera is gone.",
	NoSpeaker = "No speaker to set off.",
	Failed = "That didn't work.",
}

function ItemUseResultCodes.GetMessage(code: string?): string
	local message = code and ItemUseResultCodes.Messages[code]
	return message or "Couldn't use that."
end

return ItemUseResultCodes
