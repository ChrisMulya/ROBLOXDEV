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

-- MaxMeters/MinMeters read headDistanceStuds, NOT distanceStuds -- these are
-- hard eligibility cutoffs, and distanceStuds is measured from the client-
-- reported shot origin (CaptureGuard bounds it to +-10 studs, an accepted
-- economy-only risk; see REWARD_SYSTEM.md). A gate built on that value
-- widens by the same slack -- 15m became an effective 18.33m. headDistanceStuds
-- is measured server-side from the player's own Head, so a rule gate can't be
-- widened by a spoofed origin. Fails closed (rejects) if it's ever missing,
-- rather than falling back to the client-influenced value.
CaptureRules.Register("MaxMeters", function(context, ruleSpec)
	if context.headDistanceStuds == nil then
		return false
	end
	-- Inclusive: exactly the threshold still passes ("distance <= 15m").
	return Units.StudsToMeters(context.headDistanceStuds) <= ruleSpec.Value
end)

CaptureRules.Register("MinMeters", function(context, ruleSpec)
	if context.headDistanceStuds == nil then
		return false
	end
	return Units.StudsToMeters(context.headDistanceStuds) >= ruleSpec.Value
end)

-- Generic equality gate against any field a context provider placed on the
-- context (e.g. RewardService's Objective provider adds context.objectiveState).
-- This rule knows nothing about objectives; it just compares a field to a
-- value, which is what lets Feature 4's whole gate be one config row.
CaptureRules.Register("RequireContextEquals", function(context, ruleSpec)
	return context[ruleSpec.Field] == ruleSpec.Value
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
