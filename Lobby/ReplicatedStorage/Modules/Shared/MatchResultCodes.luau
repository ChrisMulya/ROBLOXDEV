-- Shared reason codes for why a match ended, and their player-facing display
-- strings. Mirrors ShotResultCodes/PurchaseResultCodes -- one place the
-- server's code and the client's rendered text agree.

local MatchResultCodes = {}

MatchResultCodes.Messages = {
	AllPlayersDown = "Everyone was defeated.",
	ObjectiveComplete = "Objective complete!",
	-- Replaces TimeExpired, which MatchClock.runPlaying used to emit before
	-- the Match Time System owned match length. The clock reaching 6 AM is
	-- now the only way a match ends on time, and it kills whoever is left --
	-- so the string is about the sunrise, not about a timer running out.
	Sunrise = "The sun came up.",
	Aborted = "Match ended early.",
	HostShutdown = "Server shutting down.",
	Extracted = "You made it out.",
}

-- Any other/unknown code falls back to a generic string rather than nil.
function MatchResultCodes.GetMessage(code: string?): string
	if not code then
		return MatchResultCodes.Messages.Aborted
	end
	return MatchResultCodes.Messages[code] or "Match ended."
end

return MatchResultCodes
