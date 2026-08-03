-- Shared reason codes for a spectate request's outcome, and their
-- player-facing display strings. Mirrors Reward/ShotResultCodes.

local SpectateResultCodes = {}

SpectateResultCodes.Messages = {
	NotSpectating = "You Are Not Spectating",
	SpectateNotAllowed = "Spectating Is Not Available Right Now",
	InvalidTarget = "That Player Can't Be Spectated",
	NoTargets = "No One Left To Spectate",
	RateLimited = "Slow Down",
	InvalidRequest = "Invalid Request",
	MatchEnded = "The Match Has Ended",
}

-- "Ok" has no message -- the client just reflects the new target. Any
-- other/unknown code falls back to a generic string rather than nil.
function SpectateResultCodes.GetMessage(code: string?): string
	if not code or code == "Ok" then
		return ""
	end
	return SpectateResultCodes.Messages[code] or "Spectate Request Failed"
end

return SpectateResultCodes
