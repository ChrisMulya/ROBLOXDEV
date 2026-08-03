-- Pure reward math: CaptureContext -> RewardResult. Contains zero reward
-- values itself -- every number comes from a curve, a target type's Payout
-- config, or a modifier, so a balance change never touches this file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Units = require(ReplicatedStorage.Modules.Shared.Units)
local RewardTypes = require(script.Parent.RewardTypes)
local RewardModifiers = require(script.Parent.RewardModifiers)
local DistanceMultiplierCurve = require(script.Parent.Curves.DistanceMultiplierCurve)
local DistanceBandLabels = require(script.Parent.Curves.DistanceBandLabels)

local BASE_CURVES = {
	XPRewardCurve = require(script.Parent.Curves.XPRewardCurve),
	ScoreRewardCurve = require(script.Parent.Curves.ScoreRewardCurve),
}

local RewardCalculator = {}

-- Shared by every strategy so RewardModifiers behaves identically regardless
-- of how the base amount was produced. extraMultiplier folds in whatever the
-- strategy itself contributes (the distance curve for Curve, the roll for
-- FlatRoll) so modifiers stack on top of it, not instead of it.
local function applyModifiers(context, rewardType: string, base: number, extraMultiplier: number)
	local modifiers = RewardModifiers.Collect(context, rewardType)
	local flat = 0
	local multiplier = extraMultiplier
	for _, applied in ipairs(modifiers) do
		if applied.Stage == "Additive" then
			flat += applied.Value
		elseif applied.Stage == "Multiplicative" then
			multiplier *= applied.Value
		end
	end
	return (base + flat) * multiplier, modifiers
end

-- Original behavior, unchanged: base amount from a per-shot-quality curve,
-- scaled by the distance falloff curve. This is what every monster capture
-- has always used.
local function calculateCurve(context, distanceMultiplier: number)
	local amounts = {}
	local breakdown = {}

	for typeName, typeDef in pairs(RewardTypes.All) do
		local baseCurve = BASE_CURVES[typeDef.BaseCurveName]
		local base = baseCurve:Evaluate(context.shotQuality)

		local amount, modifiers = applyModifiers(context, typeName, base, distanceMultiplier)
		amounts[typeName] = math.round(amount)
		breakdown[typeName] = { Base = base, DistanceMultiplier = distanceMultiplier, Modifiers = modifiers }
	end

	return amounts, breakdown
end

-- Objectives: a fixed base per currency times ONE random roll shared across
-- every currency -- a 0.35 roll means exactly +350 XP and +175 Score off a
-- 1000/500 base. Two independent rolls would break that relationship. No
-- distance multiplier: objectives gate on distance (CaptureRules.MaxMeters)
-- instead of scaling payout by it.
local function calculateFlatRoll(context, payout)
	local rollSpec = payout.Roll
	local roll = rollSpec.Min + math.random() * (rollSpec.Max - rollSpec.Min)
	if rollSpec.Step then
		roll = math.floor(roll / rollSpec.Step + 0.5) * rollSpec.Step
	end

	local amounts = {}
	local breakdown = {}

	for typeName, base in pairs(payout.Base) do
		local amount, modifiers = applyModifiers(context, typeName, base, roll)
		amounts[typeName] = math.round(amount)
		breakdown[typeName] = { Base = base, Roll = roll, Modifiers = modifiers }
	end

	return amounts, breakdown, roll
end

-- meters + band label only, no payout math. For failure-path display (a shot
-- that didn't qualify for a reward) where distance should still be shown.
function RewardCalculator.Describe(distanceStuds: number): (number, string)
	local meters = Units.StudsToMeters(distanceStuds)
	return meters, DistanceBandLabels:Evaluate(meters)
end

-- context: { player, subject, shotQuality, distanceStuds, cameraId }
-- targetTypeDef: a CaptureTargets.Types entry; its Payout table selects the
-- strategy. Omit (nil) to get the original Curve-with-distance-multiplier
-- behavior, preserving every pre-CaptureTargets caller.
-- returns { meters, bandLabel, amounts, breakdown, rollMultiplier? }
function RewardCalculator.Calculate(context, targetTypeDef)
	local meters = Units.StudsToMeters(context.distanceStuds)
	local payout = targetTypeDef and targetTypeDef.Payout
	local useDistanceMultiplier = not payout or payout.UseDistanceMultiplier ~= false
	local distanceMultiplier = if useDistanceMultiplier then DistanceMultiplierCurve:Evaluate(meters) else 1

	local amounts, breakdown, rollMultiplier
	if payout and payout.Strategy == "FlatRoll" then
		amounts, breakdown, rollMultiplier = calculateFlatRoll(context, payout)
	else
		amounts, breakdown = calculateCurve(context, distanceMultiplier)
	end

	return {
		meters = meters,
		bandLabel = DistanceBandLabels:Evaluate(meters),
		amounts = amounts,
		breakdown = breakdown,
		rollMultiplier = rollMultiplier,
	}
end

return RewardCalculator
