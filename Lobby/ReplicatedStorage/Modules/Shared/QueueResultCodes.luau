-- Shared reason codes for a queue request's outcome, and their player-facing
-- display strings. Mirrors Shared/SpectateResultCodes exactly.

local QueueResultCodes = {}

QueueResultCodes.Messages = {
	AlreadyQueued = "You Are Already Queued",
	NotQueued = "You Are Not Queued",
	RateLimited = "Slow Down",
	InvalidRequest = "Invalid Request",
	QueueFull = "Queue Is Full",
	PartyTooLarge = "Your Party Is Too Large For This Mode",
	NotPartyLeader = "Only Your Party Leader Can Queue",
	ProgressionNotReady = "Your Progress Isn't Saved Yet -- Try Again Shortly",
	ProgressionSaveFailed = "Couldn't Save Your Progress -- Try Again Shortly",
	RosterChanged = "Your Party Changed -- Requeued",
	LaunchInProgress = "A Match Is Already Launching",
	LaunchFailed = "Couldn't Start A Match -- Requeued",
	ModeUnavailable = "That Mode Isn't Available",
}

-- "Ok" has no message -- the client just reflects the new queue state. Any
-- other/unknown code falls back to a generic string rather than nil.
function QueueResultCodes.GetMessage(code: string?): string
	if not code or code == "Ok" then
		return ""
	end
	return QueueResultCodes.Messages[code] or "Queue Request Failed"
end

return QueueResultCodes
