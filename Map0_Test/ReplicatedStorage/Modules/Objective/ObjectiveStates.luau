-- The objective state enum, and each state's semantics as data. Nothing in
-- the Objective or Reward systems branches on a state name -- they only ever
-- read IsRewardable/IsVisible, so adding a state is a new row here.
--
-- "Resettable" from the original brief is deliberately NOT a state: modelling
-- it as one allows an illegal combination (an objective both Completed and
-- Resettable) on day one. It is instead a ResetPolicy on the objective TYPE
-- (see ObjectiveTypes), which composes with every state below.

local ObjectiveStates = {}

-- VisualStyle here is an override of the owning type's VisualStyle -- nil
-- means "use whatever ObjectiveTypes says", which is every state's default
-- except the ones that should never be visible at all.
ObjectiveStates.All = {
	Available = { Rewardable = true, Visible = true, VisualStyle = nil },
	Completed = { Rewardable = false, Visible = false, VisualStyle = nil },
	Disabled = { Rewardable = false, Visible = false, VisualStyle = nil },
	Hidden = { Rewardable = false, Visible = false, VisualStyle = nil },
	MissionLocked = { Rewardable = false, Visible = false, VisualStyle = nil },
	EventOnly = { Rewardable = false, Visible = false, VisualStyle = nil },
}

function ObjectiveStates.IsRewardable(state: string): boolean
	local def = ObjectiveStates.All[state]
	return def ~= nil and def.Rewardable
end

function ObjectiveStates.IsVisible(state: string): boolean
	local def = ObjectiveStates.All[state]
	return def ~= nil and def.Visible
end

function ObjectiveStates.IsValid(state: string): boolean
	return ObjectiveStates.All[state] ~= nil
end

return ObjectiveStates
