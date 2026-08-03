-- Shared reason codes for MatchLauncher.Launch's outcome, and their
-- player-facing display strings. Mirrors SpectateResultCodes/ShotResultCodes.
-- Distinct vocabulary from MatchResultCodes -- that module describes why a
-- match ENDED, this one describes why a match failed to START.

local MatchLaunchResultCodes = {}

MatchLaunchResultCodes.Messages = {
	UnknownMode = "That Game Mode Isn't Available",
	NoPlayers = "No Players To Launch",
	ReserveFailed = "Couldn't Reserve A Server -- Try Again",
	TeleportFailed = "Couldn't Start The Match -- Try Again",
}

-- "Launched" has no message -- the client just follows the teleport. Any
-- other/unknown code falls back to a generic string rather than nil.
function MatchLaunchResultCodes.GetMessage(code: string?): string
	if not code or code == "Launched" then
		return ""
	end
	return MatchLaunchResultCodes.Messages[code] or "Couldn't Start The Match"
end

return MatchLaunchResultCodes
