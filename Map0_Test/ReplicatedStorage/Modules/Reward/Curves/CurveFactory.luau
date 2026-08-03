-- Shared :Evaluate(input) contract every reward curve implements. Two curve
-- shapes cover every case so far: a straight key->value lookup (shot quality
-- -> base XP/Score) and a stepped falloff (distance -> multiplier). Adding a
-- third shape later is a new factory function here, not a change to callers.

local CurveFactory = {}

-- entries: { [key]: number }. default: value returned for an unrecognized key.
function CurveFactory.LookupCurve(entries: { [any]: number }, default: number)
	return {
		Evaluate = function(_self, key)
			local value = entries[key]
			if value == nil then
				return default
			end
			return value
		end,
	}
end

-- spec: { StepMeters, StartValue, StepDelta, MinValue }
-- tier = floor(input / StepMeters); value = max(MinValue, StartValue + StepDelta * tier).
-- Upper bound of each step is exclusive: input == StepMeters lands in tier 1,
-- not tier 0 (see REWARD_SYSTEM.md's boundary note).
function CurveFactory.SteppedCurve(spec)
	return {
		Evaluate = function(_self, input: number)
			local tier = math.floor(input / spec.StepMeters)
			return math.max(spec.MinValue, spec.StartValue + spec.StepDelta * tier)
		end,
	}
end

return CurveFactory
