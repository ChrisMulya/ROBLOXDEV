-- Registry of optional reward bonuses (combo, streak, event, premium,
-- prestige, camera upgrade, entity rarity...). Ships empty -- the seam exists
-- so a future bonus is one Register() call, not a RewardCalculator edit.
--
-- A modifier is:
--   { Name: string, Stage: "Additive" | "Multiplicative", AppliesTo: string?,
--     Applies(context, rewardType) -> boolean, GetValue(context, rewardType) -> number }
-- Additive values are summed with the base curve before the distance
-- multiplier; Multiplicative values are multiplied in after it.

local RewardModifiers = {}

local registered = {}

function RewardModifiers.Register(modifier)
	table.insert(registered, modifier)
end

-- Returns { { Name, Stage, Value }, ... } for every registered modifier that
-- applies to this context/rewardType.
function RewardModifiers.Collect(context, rewardType: string)
	local applied = {}
	for _, modifier in ipairs(registered) do
		local appliesToThisType = not modifier.AppliesTo or modifier.AppliesTo == rewardType
		if appliesToThisType and modifier.Applies(context, rewardType) then
			table.insert(applied, {
				Name = modifier.Name,
				Stage = modifier.Stage,
				Value = modifier.GetValue(context, rewardType),
			})
		end
	end
	return applied
end

return RewardModifiers
