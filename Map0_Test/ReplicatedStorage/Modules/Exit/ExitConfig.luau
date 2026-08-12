-- Exit System tunables. One place for the numbers ExitState and
-- ExitRequirements both need, same shape as MatchConfig.

local ExitConfig = {}

-- Continuous match-time scale (see MatchSchedule): 18 = 6 PM, 24 = midnight,
-- 27 = 3 AM, 30 = 6 AM. Never apply `% 24` to this outside
-- MatchTimeMath.FormatHour.
ExitConfig.AlternateUnlockHour = 27

ExitConfig.PhotoScoreThreshold = 2000

-- Escaping is a dwell, not a keypress: the player must stand inside the
-- marked exit volume continuously for this long. Leaving the volume (or
-- dying, or the exit re-locking) resets the timer to zero rather than
-- pausing it -- a resumable timer would let a player chip away at it between
-- monster passes, which is the tension this mechanic exists to create.
ExitConfig.DwellSeconds = 10

-- How often the server tests who is standing in an exit. Matches
-- MatchTimeService's own sampling rate: fine enough that the on-screen
-- countdown reads smoothly, coarse enough to stay off the per-frame path.
ExitConfig.DwellSampleInterval = 0.25

-- MainExit requires at least one of {Soft Objectives, Documents} to actually
-- exist in the map. Without this, a map with zero objectives and zero
-- documents would read both categories as vacuously complete and open
-- MainExit at match start. See ExitRequirements.IsMainSatisfied.
ExitConfig.RequireAtLeastOneCategory = true

-- When true, the random Alternate requirement pool excludes any kind whose
-- category total is 0 for the map being played, so the roll can never land on
-- a requirement that is already vacuously true.
--
-- On, because the requirement is meant to be something the players still have
-- to go and DO: an empty category reads as complete (see
-- ExitRequirements.isCategoryComplete), and rolling one would open the
-- Alternate the instant it unlocks. A no-op on a fully authored map -- nothing
-- is vacuous there, so nothing gets filtered.
ExitConfig.ExcludeVacuousRequirements = true

-- Loud boot failure beats a silently-never-firing Alternate unlock, same
-- reasoning as MatchSchedule.Validate/MatchPhases.Validate. Checked against
-- the Default schedule specifically -- Debug is a Studio-only fast loop with
-- its own EndHour shape and is never selected by a real mode row.
function ExitConfig.Validate(defaultSchedule: { StartHour: number, EndHour: number })
	assert(
		ExitConfig.AlternateUnlockHour >= defaultSchedule.StartHour
			and ExitConfig.AlternateUnlockHour < defaultSchedule.EndHour,
		"ExitConfig.Validate: AlternateUnlockHour must lie within [StartHour, EndHour) of the Default schedule"
	)
end

return ExitConfig
