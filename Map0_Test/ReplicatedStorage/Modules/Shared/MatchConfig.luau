-- Per-mode match tunables. Keyed by mode id, same shape as CameraStats/
-- Monster/Configs: adding a mode is one more table entry, no script changes.
-- Mode ids correspond to PlaceIds.GameModes keys.

local MatchConfig = {}

MatchConfig.Modes = {
	Default = {
		MinPlayers = 1,
		MaxPlayers = 8,
		WaitTimeout = 60, -- seconds WaitingForPlayers waits before Cleanup at zero players
		CountdownSeconds = 5,
		-- How long Playing runs is NOT set here -- it is the sum of the
		-- schedule's segment durations (MatchTimeMath.TotalRealSeconds).
		-- MatchConfig.MatchDuration and MatchClock.runPlaying were deleted
		-- when the Match Time System landed: two independent authorities on
		-- match length is exactly the duplicate timer that system replaces.
		ScheduleId = "Default", -- key into MatchSchedule.Schedules
		EndingHoldSeconds = 60, -- how long Ending stays up so the summary is readable
		PadCountdownSeconds = 10, -- lobby queue pad: countdown from the first player stepping on to launch
	},
}

function MatchConfig.Get(modeId: string)
	local config = MatchConfig.Modes[modeId]
	if not config then
		warn(("MatchConfig.Get: unknown mode '%s', falling back to Default"):format(modeId))
		config = MatchConfig.Modes.Default
	end
	return config
end

return MatchConfig
