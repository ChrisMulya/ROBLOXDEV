-- Thins the hand-placed Cash/Objective/Document instances down to a
-- difficulty x player-count subset at match start. Runs exactly once per
-- match, on the first Loading -> WaitingForPlayers, and never rerolls (a
-- Countdown -> WaitingForPlayers fallback must not reshuffle the world out
-- from under an already-spawned player).
--
-- Deactivation is a reparent into ServerStorage.SpawnSelection.Inactive, not
-- a Destroy and not an attribute clear: workspace.DescendantRemoving already
-- fires PickupRegistry/ObjectiveRegistry/CaptureRegistry's unregister paths
-- (see each module's Start/bootstrap), so an instance moved out of Workspace
-- is already uncollectable, unphotographable, and dropped from
-- MissionProgress's live counts -- with zero edits to any of those modules.
-- Reversible in principle (original Parent is recorded) and torn down by
-- MatchCleanup at Cleanup.
--
-- Reads MatchDifficulty (the percentage table) and SpawnCategories (which
-- registry answers for each category) rather than naming Cash/Objective/
-- Document itself -- adding a category is a data change in those two
-- modules, never a change here.
--
-- The plan this was designed against (plans/create-a-read-only-blueprint-
-- plan-agile-possum.md) no longer exists on disk -- don't go looking for it.
-- Whatever edge-case rationale it held beyond what's inline in this file is
-- lost; treat the code and MatchDifficulty/SpawnMath's own comments as the
-- only remaining source.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchDifficulty = require(ReplicatedStorage.Modules.Shared.MatchDifficulty)
local SpawnCategories = require(ReplicatedStorage.Modules.Shared.SpawnCategories)
local SpawnMath = require(ReplicatedStorage.Modules.Shared.SpawnMath)
local PickupTypes = require(ReplicatedStorage.Modules.Pickup.PickupTypes)
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)
local Trove = require(ReplicatedStorage.Modules.Shared.Trove)

local PickupRegistry = require(script.Parent.Parent.Pickup.PickupRegistry)
local CaptureRegistry = require(script.Parent.Parent.Reward.CaptureRegistry)
local MatchManager = require(script.Parent.MatchManager)
local MatchSettings = require(script.Parent.MatchSettings)
local MatchCleanup = require(script.Parent.MatchCleanup)

local SpawnSelection = {}

local applied = false
local lastSummary: { [string]: { available: number, adjustedFraction: number, selected: number, deactivated: number } } = {}

local trove = Trove.new()
local inactiveContainer: Folder? = nil

local function getInactiveContainer(): Folder
	if inactiveContainer then
		return inactiveContainer
	end

	local root = Instance.new("Folder")
	root.Name = "SpawnSelection"
	root.Parent = ServerStorage
	trove:Add(root)

	local inactive = Instance.new("Folder")
	inactive.Name = "Inactive"
	inactive.Parent = root

	inactiveContainer = inactive
	return inactive
end

-- Only two Source kinds exist -- see SpawnCategories's header.
local function instancesForCategory(categoryDef): { Instance }
	local result = {}

	if categoryDef.Source == "Pickup" then
		for _, instance in ipairs(PickupRegistry.All()) do
			if PickupTypes.TypeOf(instance) == categoryDef.PickupType then
				table.insert(result, instance)
			end
		end
	elseif categoryDef.Source == "CaptureTarget" then
		local attribute = CaptureTargets.AttributeFor(categoryDef.TargetType)
		for _, instance in ipairs(CaptureRegistry.All()) do
			if attribute and instance:GetAttribute(attribute) then
				table.insert(result, instance)
			end
		end
	end

	return result
end

-- In-place Fisher-Yates using the match-scoped rng, so the same seed always
-- produces the same order for the same category's discovered instance list.
local function shuffle(rng: Random, list: { Instance })
	for index = #list, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		list[index], list[swapIndex] = list[swapIndex], list[index]
	end
end

function SpawnSelection.Apply()
	if applied then
		return
	end
	applied = true

	local settings = MatchSettings.Get()
	local difficulty = MatchDifficulty.Get(settings.difficultyId)
	if not difficulty then
		warn(("SpawnSelection.Apply: difficulty '%s' has no MatchDifficulty row -- no spawn selection applied"):format(
			tostring(settings.difficultyId)))
		return
	end

	local rng = Random.new(settings.randomSeed)
	local claimedBy: { [Instance]: string } = {}
	local summary = {}

	for _, categoryId in ipairs(SpawnCategories.OrderedNames()) do
		local baseFraction = difficulty.SpawnFraction[categoryId]
		if baseFraction then
			local categoryDef = SpawnCategories.Get(categoryId)
			local scaling = difficulty.PlayerScaling[categoryId] or 0
			local rawInstances = instancesForCategory(categoryDef)

			-- An instance carrying two category markers belongs to whichever
			-- category claims it first, in OrderedNames order -- deterministic,
			-- and never processed twice.
			local available = {}
			for _, instance in ipairs(rawInstances) do
				if claimedBy[instance] then
					warn(("SpawnSelection.Apply: %s already claimed by category '%s' -- skipping for '%s'"):format(
						instance:GetFullName(), claimedBy[instance], categoryId))
				else
					claimedBy[instance] = categoryId
					table.insert(available, instance)
				end
			end

			local adjustedFraction = SpawnMath.AdjustedFraction(baseFraction, scaling, settings.playerCount)
			local keepCount = SpawnMath.SelectedCount(#available, adjustedFraction)

			shuffle(rng, available)

			local deactivatedCount = 0
			for index = keepCount + 1, #available do
				local instance = available[index]
				instance.Parent = getInactiveContainer()
				deactivatedCount += 1
			end

			summary[categoryId] = {
				available = #available,
				adjustedFraction = adjustedFraction,
				selected = keepCount,
				deactivated = deactivatedCount,
			}

			if #available == 0 then
				warn(("SpawnSelection.Apply: no authored '%s' instances found -- map-authoring gap"):format(categoryId))
			end

			print(("SpawnSelection.Apply: %s available=%d adjustedFraction=%.4f selected=%d deactivated=%d"):format(
				categoryId, #available, adjustedFraction, keepCount, deactivatedCount))
		end
	end

	lastSummary = summary
end

function SpawnSelection.GetSummary()
	return lastSummary
end

local started = false

function SpawnSelection.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchCleanup.RegisterTeardownStep("SpawnSelection", function()
		trove:Clean()
		inactiveContainer = nil
	end)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "WaitingForPlayers" then
			SpawnSelection.Apply()
		end
	end)
end

return SpawnSelection
