-- Composable validation predicates a CaptureTargets type opts into via its
-- Rules list. Rules never know about target types; types never know how a
-- rule is implemented -- adding a new gating condition (time of day, height,
-- quest state) is one Register() call here, not a change to every type that
-- might want it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Modules.Shared.Units)

local CaptureRules = {}

-- [name] = function(context, ruleSpec) -> boolean
-- context: { player, subject, shotQuality, distanceStuds, cameraId, targetType }
-- ruleSpec: the { Rule, Value, Code } entry from a type's Rules list
local predicates = {}

function CaptureRules.Register(name: string, predicate: (any, any) -> boolean)
	predicates[name] = predicate
end

CaptureRules.Register("RequireShotQuality", function(context, ruleSpec)
	return context.shotQuality == ruleSpec.Value
end)

CaptureRules.Register("MaxMeters", function(context, ruleSpec)
	-- Inclusive: exactly the threshold still passes ("distance <= 15m").
	return Units.StudsToMeters(context.distanceStuds) <= ruleSpec.Value
end)

CaptureRules.Register("MinMeters", function(context, ruleSpec)
	return Units.StudsToMeters(context.distanceStuds) >= ruleSpec.Value
end)

-- Runs every rule in typeDef.Rules against context in order, stopping at the
-- first failure. Returns true, nil on success, or false, code on failure.
-- An empty/absent Rules list (e.g. Monster) always passes.
function CaptureRules.Check(typeDef, context): (boolean, string?)
	for _, ruleSpec in ipairs(typeDef.Rules or {}) do
		local predicate = predicates[ruleSpec.Rule]
		if not predicate then
			warn(("CaptureRules: unknown rule '%s'"):format(tostring(ruleSpec.Rule)))
			continue
		end
		if not predicate(context, ruleSpec) then
			return false, ruleSpec.Code
		end
	end
	return true, nil
end

return CaptureRules
