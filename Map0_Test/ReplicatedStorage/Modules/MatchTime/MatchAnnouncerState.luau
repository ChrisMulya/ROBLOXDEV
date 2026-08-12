-- Pure resolver for the announcer line beneath the match-time bar. Mirrors
-- MatchTimeMath's role: no instances, no services, no state -- one sample of
-- the same clock MatchTimeClient already reads, never a second timer.
--
-- Two windows, evaluated in order:
--   1. A countdown to COUNTDOWN_TO_HOUR (7 PM), red for its final
--      RED_THRESHOLD seconds.
--   2. A fixed-length banner starting at ENRAGE_HOUR (3 AM).
-- Anything outside both is blank (nil).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchTimeMath = require(script.Parent.MatchTimeMath)
local UITheme = require(ReplicatedStorage.Modules.UI.UITheme)

local MatchAnnouncerState = {}

local COUNTDOWN_TO_HOUR = 19 -- 7 PM
local ENRAGE_HOUR = 27 -- 3 AM
local ENRAGE_TEXT = "The Creature is Enraged"
local ENRAGE_SECONDS = 6 -- real seconds the banner stays up
local RED_THRESHOLD = 10 -- countdown value at/below which the text turns red
local ENRAGE_FONT = Enum.Font.SpecialElite

-- Returns nil for "blank". Half-open intervals throughout: a countdown value
-- is shown for exactly one real second, [E, E+1), and the banner window is
-- [enrageStart, enrageStart + ENRAGE_SECONDS). See plans/match-time-announcer.md
-- section 3 for the full boundary table and why ceil is the correct rounding.
function MatchAnnouncerState.Resolve(schedule, elapsedReal: number): (string?, Color3?, Enum.Font?)
	local countdownEnd = MatchTimeMath.HourToReal(schedule, COUNTDOWN_TO_HOUR)
	if elapsedReal < countdownEnd then
		local remaining = math.ceil(countdownEnd - elapsedReal)
		if remaining <= 0 then
			-- Guards the E == countdownEnd instant landing here due to float
			-- error rather than falling into the enrage check below.
			return nil
		end

		local color = (remaining <= RED_THRESHOLD) and UITheme.Colors.Danger or UITheme.Colors.Text
		return tostring(remaining), color, UITheme.Fonts.Bold
	end

	local enrageStart = MatchTimeMath.HourToReal(schedule, ENRAGE_HOUR)
	if elapsedReal >= enrageStart and elapsedReal < enrageStart + ENRAGE_SECONDS then
		return ENRAGE_TEXT, UITheme.Colors.DangerDeep, ENRAGE_FONT
	end

	return nil
end

return MatchAnnouncerState
