-- Shared reason codes for a queue pad's outcome, and their player-facing
-- display strings. Mirrors Shared/SpectateResultCodes exactly. Also carries
-- MatchLauncher's own launch-failure codes (formerly the separate, never-
-- required MatchLaunchResultCodes module) -- both arrive on the same
-- QueueResult remote, and QueueService passes MatchLauncher's code straight
-- through rather than flattening it, so there's one map to keep in sync with
-- one set of producers.
--
-- AlreadyQueued/PartyTooLarge/NotPartyLeader are unreachable today: they only
-- trip when a party has more than one member, and PartyService has no client
-- surface yet (Join/Leave are never called), so every party is solo. Kept
-- rather than deleted -- they activate the moment party invites ship, with no
-- code change needed here.

local QueueResultCodes = {}

QueueResultCodes.Messages = {
	AlreadyQueued = "You Are Already Queued",
	InvalidRequest = "Invalid Request",
	QueueFull = "Queue Is Full",
	PartyTooLarge = "Your Party Is Too Large For This Mode",
	NotPartyLeader = "Only Your Party Leader Can Queue",
	ProgressionNotReady = "Your Progress Isn't Saved Yet -- Try Again Shortly",
	ProgressionSaveFailed = "Couldn't Save Your Progress -- Try Again Shortly",
	RosterChanged = "Your Party Changed -- Requeued",
	LaunchInProgress = "A Match Is Already Launching",
	-- Fallback for any launch failure code not listed below.
	LaunchFailed = "Couldn't Start A Match -- Requeued",

	-- MatchLauncher.Launch's specific failure reasons -- previously produced
	-- and then discarded (QueueService flattened all of them to LaunchFailed
	-- before firing QueueResult). Passed through as-is now, so the player
	-- hears why instead of a generic retry prompt.
	UnknownMode = "That Game Mode Isn't Available",
	NoPlayers = "No Players To Launch",
	ReserveFailed = "Couldn't Reserve A Server -- Try Again",
	TeleportFailed = "Couldn't Start The Match -- Try Again",
	-- TeleportAsync was accepted (Launch returned true) but a later, async
	-- TeleportInitFailed means this specific player never actually left
	-- after MatchLauncher retried with backoff.
	TeleportInitFailed = "Couldn't Complete Your Teleport -- Try Queueing Again",
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
