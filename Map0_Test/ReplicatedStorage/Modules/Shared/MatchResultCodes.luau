-- Shared reason codes for why a match ended, and their player-facing display
-- strings. Mirrors ShotResultCodes/PurchaseResultCodes -- one place the
-- server's code and the client's rendered text agree.

local MatchResultCodes = {}

MatchResultCodes.Messages = {
	AllPlayersDown = "Everyone was defeated.",
	ObjectiveComplete = "Objective complete!",
	TimeExpired = "Time's up.",
	Aborted = "Match ended early.",
	HostShutdown = "Server shutting down.",
}

-- Any other/unknown code falls back to a generic string rather than nil.
function MatchResultCodes.GetMessage(code: string?): string
	if not code then
		return MatchResultCodes.Messages.Aborted
	end
	return MatchResultCodes.Messages[code] or "Match ended."
end

return MatchResultCodes
