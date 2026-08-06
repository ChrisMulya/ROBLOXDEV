-- Per-schedule match time tunables. Keyed by schedule id, same Get()-warns-
-- and-falls-back shape as MatchConfig. Which schedule a match uses comes
-- from MatchConfig.Modes[modeId].ScheduleId.
--
-- Hours run on a continuous scale past 24 rather than wrapping at midnight --
-- 6 AM is 30, midnight is 24. Every comparison/subtraction/segment lookup in
-- the Match Time System is plain arithmetic on this scale. Only
-- MatchTimeMath.FormatHour applies `% 24`, and only for display. Wrapping
-- anywhere else reintroduces the midnight-crossing bugs this scale avoids.
--
-- Segments are ordered and contiguous: the first starts at StartHour, each
-- ends at UntilHour, and the next begins where the previous left off. Adding
-- a schedule (a slower midnight, a faster sunrise, a map-specific pacing) is
-- one more table entry -- MatchTimeMath has no schedule-shape knowledge.

local MatchSchedule = {}

MatchSchedule.Schedules = {
	Default = {
		StartHour = 16, -- 4 PM
		EndHour = 30, -- 6 AM the next day
		Segments = {
			{ UntilHour = 19, SecondsPerHour = 60 }, -- 4 PM -> 7 PM
			{ UntilHour = 30, SecondsPerHour = 75 }, -- 7 PM -> 6 AM
		},
	},
	-- Fast loop for Studio verification -- ~42s total instead of 840s.
	-- Never used by a real mode row; require it by scheduleId explicitly.
	Debug = {
		StartHour = 16,
		EndHour = 30,
		Segments = {
			{ UntilHour = 30, SecondsPerHour = 3 },
		},
	},
}

function MatchSchedule.Get(scheduleId: string)
	local schedule = MatchSchedule.Schedules[scheduleId]
	if not schedule then
		warn(("MatchSchedule.Get: unknown schedule '%s', falling back to Default"):format(tostring(scheduleId)))
		schedule = MatchSchedule.Schedules.Default
	end
	return schedule
end

-- Loud boot failure beats a silently broken clock, same reasoning as
-- MatchStates.Validate / PlayerStates.Validate. Called from GameBoot
-- alongside those.
function MatchSchedule.Validate()
	for scheduleId, schedule in pairs(MatchSchedule.Schedules) do
		assert(
			typeof(schedule.StartHour) == "number" and typeof(schedule.EndHour) == "number",
			("MatchSchedule.Validate: '%s' is missing StartHour/EndHour"):format(scheduleId)
		)
		assert(
			schedule.EndHour > schedule.StartHour,
			("MatchSchedule.Validate: '%s' EndHour must be greater than StartHour"):format(scheduleId)
		)
		assert(
			typeof(schedule.Segments) == "table" and #schedule.Segments > 0,
			("MatchSchedule.Validate: '%s' has no Segments"):format(scheduleId)
		)

		local previousUntil = schedule.StartHour
		for index, segment in ipairs(schedule.Segments) do
			assert(
				typeof(segment.UntilHour) == "number" and segment.UntilHour > previousUntil,
				("MatchSchedule.Validate: '%s' segment %d UntilHour must exceed the previous segment's UntilHour"):format(
					scheduleId,
					index
				)
			)
			assert(
				typeof(segment.SecondsPerHour) == "number" and segment.SecondsPerHour > 0,
				("MatchSchedule.Validate: '%s' segment %d SecondsPerHour must be positive"):format(scheduleId, index)
			)
			previousUntil = segment.UntilHour
		end

		assert(
			previousUntil == schedule.EndHour,
			("MatchSchedule.Validate: '%s' last segment must end exactly at EndHour"):format(scheduleId)
		)
	end
end

return MatchSchedule
