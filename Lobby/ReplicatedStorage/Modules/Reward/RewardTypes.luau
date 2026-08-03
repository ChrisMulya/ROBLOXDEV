-- What a reward type IS: display name, where it lives, whether it survives
-- EndGame/rejoin. Adding a currency is a row here plus one base curve module
-- -- nothing that awards rewards needs to change.

local RewardTypes = {}

RewardTypes.All = {
	XP = {
		DisplayName = "XP",
		LeaderstatName = "XP",
		Persistent = true,
		ResetOnRunEnd = false,
		BaseCurveName = "XPRewardCurve",
		Round = "nearest",
	},
	Score = {
		DisplayName = "Score",
		LeaderstatName = "Score",
		Persistent = false,
		ResetOnRunEnd = true,
		BaseCurveName = "ScoreRewardCurve",
		Round = "nearest",
	},
}

function RewardTypes.Get(name: string)
	return RewardTypes.All[name]
end

function RewardTypes.Persistent(): { string }
	local names = {}
	for name, def in pairs(RewardTypes.All) do
		if def.Persistent then
			table.insert(names, name)
		end
	end
	return names
end

function RewardTypes.RunScoped(): { string }
	local names = {}
	for name, def in pairs(RewardTypes.All) do
		if def.ResetOnRunEnd then
			table.insert(names, name)
		end
	end
	return names
end

return RewardTypes
