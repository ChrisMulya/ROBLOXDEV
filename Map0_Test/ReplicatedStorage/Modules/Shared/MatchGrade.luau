-- Personal-stats letter grade for the end-of-match receipt. Shared because
-- the server computes it (into MatchStats' "Stats" contributor slice) and
-- the client renders it -- the grade is never recomputed client-side, only
-- the formula's shape needs to be reachable from ReplicatedStorage.
--
-- THE FORMULA BELOW IS A PLACEHOLDER. Banded purely on total successful
-- captures this match (sum of every count in stats.captures) so the grade
-- has something honest to show today. Real grading -- weighing survival
-- time, balancing capture types, whatever the actual design turns out to
-- be -- is a rewrite of this one module and nothing else; every caller only
-- ever sees a letter, never the formula behind it.
--
-- Same ordered-threshold-table shape as Reward/Curves/DistanceBandLabels,
-- just ascending instead of descending: higher total is better here, where
-- DistanceBandLabels' lower distance is better.

local MatchGrade = {}

local BANDS = {
	{ Min = 16, Grade = "S" },
	{ Min = 12, Grade = "A" },
	{ Min = 8, Grade = "B" },
	{ Min = 5, Grade = "C" },
	{ Min = 3, Grade = "D" },
	{ Min = 1, Grade = "E" },
}
local DEFAULT_GRADE = "F"

-- stats: the same shape MatchStats' "Stats" contributor returns --
-- { survivedSeconds: number, captures: { [targetType]: number } }. Takes the
-- whole slice, not just the total, so a future formula that also weighs
-- survivedSeconds doesn't need a new call signature.
function MatchGrade.Evaluate(stats: { captures: { [string]: number } }): string
	local total = 0
	for _, count in pairs(stats.captures or {}) do
		total += count
	end

	for _, band in ipairs(BANDS) do
		if total >= band.Min then
			return band.Grade
		end
	end
	return DEFAULT_GRADE
end

return MatchGrade
