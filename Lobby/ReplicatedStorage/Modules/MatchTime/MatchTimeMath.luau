-- Pure conversions between real seconds and the continuous in-game hour
-- scale (see MatchSchedule's header for why hours run past 24 instead of
-- wrapping). No state, no services -- shared verbatim by server and client
-- so both derive the same hour from the same inputs and can never drift
-- against each other.

local MatchTimeMath = {}

local HOUR_NAMES_12 = { 12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }

function MatchTimeMath.TotalRealSeconds(schedule): number
	local total = 0
	local previousUntil = schedule.StartHour
	for _, segment in ipairs(schedule.Segments) do
		total += (segment.UntilHour - previousUntil) * segment.SecondsPerHour
		previousUntil = segment.UntilHour
	end
	return total
end

-- Walks segments accumulating each one's real-second cost; interpolates
-- within the segment realSeconds lands in. Clamps to [StartHour, EndHour] so
-- out-of-range input can never produce a nonsense hour.
function MatchTimeMath.RealToHour(schedule, realSeconds: number): number
	if realSeconds <= 0 then
		return schedule.StartHour
	end

	local remaining = realSeconds
	local hour = schedule.StartHour
	for _, segment in ipairs(schedule.Segments) do
		local segmentHours = segment.UntilHour - hour
		local segmentSeconds = segmentHours * segment.SecondsPerHour
		if remaining <= segmentSeconds then
			return hour + (remaining / segment.SecondsPerHour)
		end
		remaining -= segmentSeconds
		hour = segment.UntilHour
	end

	return schedule.EndHour
end

-- Inverse of RealToHour -- for event scheduling ("fire at hour H" needs to
-- know how many real seconds into the match that is). Clamps to
-- [0, TotalRealSeconds].
function MatchTimeMath.HourToReal(schedule, hour: number): number
	if hour <= schedule.StartHour then
		return 0
	end

	local elapsed = 0
	local previousUntil = schedule.StartHour
	for _, segment in ipairs(schedule.Segments) do
		if hour <= segment.UntilHour then
			return elapsed + (hour - previousUntil) * segment.SecondsPerHour
		end
		elapsed += (segment.UntilHour - previousUntil) * segment.SecondsPerHour
		previousUntil = segment.UntilHour
	end

	return elapsed
end

-- Display only. The single legal `% 24` in the Match Time System -- every
-- other function in this module operates on the continuous scale.
function MatchTimeMath.FormatHour(hour: number): string
	local wrapped = math.floor(hour) % 24
	local displayHour = HOUR_NAMES_12[(wrapped % 12) + 1]
	local meridiem = (wrapped < 12) and "AM" or "PM"
	return ("%d %s"):format(displayHour, meridiem)
end

return MatchTimeMath
