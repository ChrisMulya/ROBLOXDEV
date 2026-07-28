-- meters -> reward multiplier. The only place the distance falloff shape is
-- defined; RewardCalculator just calls :Evaluate.

local CurveFactory = require(script.Parent.CurveFactory)

return CurveFactory.SteppedCurve({
	StepMeters = 15,
	StartValue = 1.0,
	StepDelta = -0.1,
	MinValue = 0.5,
})
