-- Pure formulas for match-start spawn selection: adjusted spawn fraction,
-- cash reward multiplier, and selected instance count. No state, no
-- services -- shared verbatim by SpawnSelection and PickupHandlers/Cash so
-- both derive the same numbers from the same inputs.

local SpawnMath = {}

-- Compounding growth: each additional player multiplies the CURRENT fraction
-- by (1 + playerScaling), not the base by a linear term. playerScaling = 0
-- collapses to baseFraction * 1^(n-1) = baseFraction, which is how Cash stays
-- exactly unscaled with no branch. No upper cap -- values above 1.0 are legal
-- and are absorbed by SelectedCount's clamp to the authored instance count.
function SpawnMath.AdjustedFraction(baseFraction: number, playerScaling: number, playerCount: number): number
	local extraPlayers = math.max(playerCount, 1) - 1
	return baseFraction * (1 + playerScaling) ^ extraPlayers
end

-- Fractional reduction per player after the first, floored so a Cash pickup
-- can never be devalued to a non-positive amount (PickupHandlers/Cash
-- refuses amount <= 0 as HandlerFailed). Unreachable at the current
-- MatchConfig.Modes.Default.MaxPlayers = 8 -- guards a future larger mode.
function SpawnMath.CashRewardMultiplier(playerCount: number, perExtraPlayer: number, floor: number): number
	local extraPlayers = math.max(playerCount, 1) - 1
	return math.max(floor, 1 - perExtraPlayer * extraPlayers)
end

-- Always ceil, always clamp to [min(1, availableCount), availableCount] --
-- never invent instances, but never drop a category with at least one
-- authored instance to zero (ExitRequirements.isCategoryComplete treats
-- total == 0 as satisfied, which SpawnSelection must not trigger).
--
-- Rounds the product to the nearest 1e-9 before ceiling: 20 * 0.30 is
-- 6.000000000000001 in double-precision float, and an unguarded ceil returns
-- 7, not 6 -- silently breaking the documented Normal/1-player example.
function SpawnMath.SelectedCount(availableCount: number, adjustedFraction: number): number
	if availableCount <= 0 then
		return 0
	end
	local product = availableCount * adjustedFraction
	local wanted = math.ceil(product - 1e-9)
	local lowerBound = math.min(1, availableCount)
	return math.clamp(wanted, lowerBound, availableCount)
end

return SpawnMath
