-- Shared reason codes for a pickup collect attempt, and their player-facing
-- display strings. Mirrors Reward/ShotResultCodes.luau -- one place the
-- server's returned code and any future client-rendered text agree.

local PickupResultCodes = {}

PickupResultCodes.Messages = {
	NotAPickup = "Not Collectible",
	AlreadyClaimed = "Already Taken",
	UnknownType = "Not Collectible",
	TooFarAway = "Too Far Away",
	NotAlive = "Not Available",
	NotInMatch = "Not Available",
	MatchNotActive = "Match Not Active",
	CurrencyNotReady = "Not Ready Yet",
	OnCooldown = "Try Again",
	HandlerFailed = "Could Not Collect",
}

-- "Success" has no message here -- a future client would render the amount
-- instead. Any other/unknown code falls back to a generic string rather than nil.
function PickupResultCodes.GetMessage(code: string?): string
	if not code or code == "Success" then
		return ""
	end
	return PickupResultCodes.Messages[code] or "Could Not Collect"
end

return PickupResultCodes
