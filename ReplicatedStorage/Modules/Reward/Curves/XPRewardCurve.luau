-- Shot quality -> base XP, before the distance multiplier and any modifiers.

local CurveFactory = require(script.Parent.CurveFactory)

return CurveFactory.LookupCurve({
	Strong = 1000,
	Weak = 600,
}, 0)
