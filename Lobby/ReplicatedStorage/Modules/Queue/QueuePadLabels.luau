-- Queue pad readout strings. Presentation only -- these describe a pad's
-- live state (occupancy, countdown), never a queue result code, so they
-- don't belong in QueueResultCodes. Same split as Reward/Curves/
-- DistanceBandLabels: state-dependent display text lives in a shared module,
-- not hardcoded in the view that renders it.
--
-- "Full" here and QueueResultCodes' "Queue Is Full" describe the same
-- condition on purpose: one is the persistent world-space label (this
-- module), the other is the transient HUD popup fired when a specific
-- player's JoinPad was rejected. Different audiences, different lifetimes --
-- keep both, keep them worded consistently.

local QueuePadLabels = {}

QueuePadLabels.Idle = "Step in to start"
QueuePadLabels.Full = "Full"

function QueuePadLabels.Counting(secondsRemaining: number): string
	return ("Starting in %d..."):format(secondsRemaining)
end

-- count/capacity line plus the status line, joined the way QueuePadDisplay
-- renders them -- callers pass whichever status string applies.
function QueuePadLabels.Format(count: number, capacity: number, status: string): string
	return ("%d/%d\n%s"):format(count, capacity, status)
end

return QueuePadLabels
