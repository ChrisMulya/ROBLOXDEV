-- The registry of capturable target KINDS. Every capture attribute name
-- (IsMonster, IsObjective, ...) is defined here and nowhere else -- this is
-- what makes adding Boss/RareMonster/SecretObject/QuestObject/etc. a config
-- row instead of a code change, and what makes renaming an attribute (e.g.
-- the old bare CanCapture) a one-file edit.

local CaptureTargets = {}

-- Rules/Payout are consumed by CaptureRules and RewardCalculator
-- respectively; this module only owns identity (Attribute, Priority) and
-- resolution.
CaptureTargets.Types = {
	Monster = {
		Attribute = "IsMonster",
		Priority = 100,
		Rules = {}, -- no gating: always awards, per design decision
		RepeatPolicy = "Unlimited", -- anti-farm seam, currently disabled -- see REWARD_SYSTEM.md
		Payout = {
			Strategy = "Curve",
			UseDistanceMultiplier = true,
		},
	},

	Objective = {
		Attribute = "IsObjective",
		Priority = 200, -- wins over Monster if an instance somehow carries both
		Rules = {
			{ Rule = "RequireShotQuality", Value = "Strong", Code = "WrongShotQuality" },
			{ Rule = "MaxMeters", Value = 15, Code = "TooFar" }, -- inclusive: exactly 15m awards
		},
		RepeatPolicy = "Unlimited",
		Payout = {
			Strategy = "FlatRoll",
			Base = { XP = 1000, Score = 500 },
			Roll = { Min = 0.3, Max = 0.4 },
			UseDistanceMultiplier = false,
		},
	},
}

-- Ordered by Priority (highest first), computed once at module load rather
-- than on every resolve -- pairs() iteration order isn't guaranteed and this
-- table rarely changes.
local orderedTypeNames = {}
for typeName in pairs(CaptureTargets.Types) do
	table.insert(orderedTypeNames, typeName)
end
table.sort(orderedTypeNames, function(a, b)
	return CaptureTargets.Types[a].Priority > CaptureTargets.Types[b].Priority
end)

function CaptureTargets.Get(typeName: string)
	return CaptureTargets.Types[typeName]
end

function CaptureTargets.AttributeFor(typeName: string): string?
	local typeDef = CaptureTargets.Types[typeName]
	return typeDef and typeDef.Attribute
end

-- Returns the type this EXACT instance is tagged as, or nil. Does not walk
-- ancestors -- see Resolve for that. Highest-Priority match wins if an
-- instance carries more than one type's attribute.
function CaptureTargets.TypeOf(instance: Instance): string?
	for _, typeName in ipairs(orderedTypeNames) do
		if instance:GetAttribute(CaptureTargets.Types[typeName].Attribute) then
			return typeName
		end
	end
	return nil
end

function CaptureTargets.IsType(instance: Instance, typeName: string): boolean
	local attribute = CaptureTargets.AttributeFor(typeName)
	return attribute ~= nil and instance:GetAttribute(attribute) == true
end

-- Walks from hitInstance up through its ancestors (stopping at workspace),
-- returning the first Instance carrying a registered type attribute and
-- which type it is, or (nil, nil). Checks hitInstance itself first, so
-- calling Resolve(subject) on an already-resolved subject doubles as a
-- re-verify: it re-checks that exact instance's attribute before falling
-- back to walking further up (which only matters if the tag moved, an edge
-- case handled the same way as the original walk-from-a-raycast-hit case).
function CaptureTargets.Resolve(hitInstance: Instance?): (Instance?, string?)
	local current = hitInstance
	while current and current ~= workspace do
		local typeName = CaptureTargets.TypeOf(current)
		if typeName then
			return current, typeName
		end
		current = current.Parent
	end
	return nil, nil
end

return CaptureTargets
