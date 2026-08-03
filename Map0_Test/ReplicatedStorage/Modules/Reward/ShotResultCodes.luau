-- Shared reason codes for a camera shot's outcome, and their player-facing
-- display strings. Mirrors CameraShelf/ShelfResultCodes -- one place the
-- server's returned code and the client's rendered text agree, instead of a
-- bare hardcoded string (the old "No Reward") drifting out of sync with why
-- a shot didn't pay out.

local ShotResultCodes = {}

ShotResultCodes.Messages = {
	TooFar = "Too Far",
	WrongShotQuality = "Needs a Strong Shot",
	OnRepeatCooldown = "Already Photographed",
	UnknownTarget = "Not Capturable",
	AlreadyCompleted = "Already Photographed",
	ObjectiveUnavailable = "Not Available",
	MatchNotScoring = "Match Has Ended",
}

-- "Awarded" has no message here -- the client renders the amounts instead.
-- Any other/unknown code falls back to a generic string rather than nil.
function ShotResultCodes.GetMessage(code: string?): string
	if not code or code == "Awarded" then
		return ""
	end
	return ShotResultCodes.Messages[code] or "No Reward"
end

return ShotResultCodes
