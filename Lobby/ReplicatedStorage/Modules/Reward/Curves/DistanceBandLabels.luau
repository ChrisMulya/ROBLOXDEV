-- meters -> display label ("POINT BLANK", "CLOSE", ...). Presentation only --
-- never multiplied into a reward number. Ordered nearest-first; the first
-- band whose Max the distance doesn't exceed wins.

local DistanceBandLabels = {}

local BANDS = {
	{ Max = 15, Label = "POINT BLANK" },
	{ Max = 30, Label = "CLOSE" },
	{ Max = 45, Label = "MID" },
	{ Max = 60, Label = "FAR" },
}
local DEFAULT_LABEL = "DISTANT"

function DistanceBandLabels:Evaluate(meters: number): string
	for _, band in ipairs(BANDS) do
		if meters <= band.Max then
			return band.Label
		end
	end
	return DEFAULT_LABEL
end

return DistanceBandLabels
