-- Shot quality -> base Score, before the distance multiplier and any modifiers.

local CurveFactory = require(script.Parent.CurveFactory)

return CurveFactory.LookupCurve({
	Strong = 200,
	Weak = 100,
}, 0)
