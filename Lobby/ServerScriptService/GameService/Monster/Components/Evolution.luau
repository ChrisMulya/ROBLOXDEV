-- Mutates a monster's stats at a scripted moment (blueprint step 10: hour 27,
-- "the Witching hour"). Reactive, not periodic -- no Tick. Something else
-- decides WHEN (MonsterEvolution, driven by MatchTimeEvents); this only knows
-- HOW to apply a tier once told to.
--
-- SCOPE OF THIS PASS: Stats only. A tier's Stats table is a set of
-- MULTIPLIERS applied to the monster's current stats, then clamped by
-- Limits -- the pipeline the blueprint declares:
--   stage-merged base -> Set -> Add -> Multiply -> Clamp
-- "Set" is MonsterConfig's stage merge, "Add" has no user yet, "Multiply" and
-- "Clamp" are this component.
--
-- A tier's schema also allows Capabilities/States/Aggression/Perception/
-- Abilities fields (see the blueprint's example config) for a monster that
-- gains a new ability at evolution. None of those apply yet -- granting a
-- capability post-spawn means constructing a component MonsterInstance never
-- built and adding a state Brain.candidates never considered, and neither
-- Abilities (step 11) nor Teleport (step 11) exist to be granted. Declaring
-- one of those fields on a tier warns loudly rather than silently no-op'ing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConfig = require(ReplicatedStorage.Modules.Monster.MonsterConfig)
local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local Evolution = {}
Evolution.__index = Evolution
Evolution.Name = "Evolution"

local UNSUPPORTED_FIELDS = { "Capabilities", "States", "Aggression", "Perception", "Abilities" }

function Evolution.new(instance, _config)
	return setmetatable({
		instance     = instance,
		-- [tierName] = true. Not a Blackboard key -- nothing outside this
		-- component needs it, and Reapply is the only other reader.
		appliedTiers = {},
	}, Evolution)
end

function Evolution:Start() end

local function warnUnsupportedFields(monsterId: string, tierName: string, tier)
	for _, field in ipairs(UNSUPPORTED_FIELDS) do
		if tier[field] ~= nil then
			warn(("Evolution: '%s' tier '%s' declares %s, which this pass does not apply -- only Stats mutates")
				:format(monsterId, tierName, field))
		end
	end
end

-- Multiplies CURRENT Stats, not a freshly-resolved stage base, by the tier's
-- multipliers. Multiplying from current is what lets this compose regardless
-- of whether a stage change happens before or after evolution -- see Reapply,
-- which relies on this being safe to call again against whatever config.Stats
-- currently holds.
local function multiplyStats(currentStats, tierStats, limits)
	local result = table.clone(currentStats)
	if tierStats then
		for key, multiplier in pairs(tierStats) do
			local base = result[key]
			if type(base) == "number" and type(multiplier) == "number" then
				result[key] = base * multiplier
			end
		end
	end
	return MonsterConfig.ClampStats(result, limits)
end

-- Wholesale table swap, never a field mutation. Every reader takes
-- config.Stats fresh each use, so the swap is atomic from a mid-tick reader's
-- point of view -- the same invariant MonsterInstance:SetStage relies on.
function Evolution:_applyTier(tier)
	local instance = self.instance
	local newStats = multiplyStats(instance.config.Stats, tier.Stats, instance.config.Limits)

	local newConfig = table.clone(instance.config)
	newConfig.Stats = table.freeze(newStats)
	instance.config = table.freeze(newConfig)
end

-- Applies a tier by name. Idempotent: re-applying an already-applied tier is
-- a no-op unless it declares Stacks = true, which is what stops the "spawned
-- after the event AND heard the event" double-apply the blueprint calls out
-- (see MonsterEvolution.ApplyCurrentTiers).
function Evolution:Apply(tierName: string): boolean
	local instance = self.instance
	local tiers = instance.config.Evolution and instance.config.Evolution.Tiers
	local tier = tiers and tiers[tierName]
	if not tier then
		warn(("Evolution: '%s' has no tier '%s'"):format(instance.monsterId, tierName))
		return false
	end

	if self.appliedTiers[tierName] and tier.Stacks ~= true then
		return false
	end

	warnUnsupportedFields(instance.monsterId, tierName, tier)
	self:_applyTier(tier)
	self.appliedTiers[tierName] = true

	-- Deliberately does NOT reset state, target or position -- a monster that
	-- evolves mid-chase keeps chasing. Nothing here touches the Blackboard.
	instance.model:SetAttribute(MonsterConstants.Attributes.EvolutionTier, tierName)
	instance.bus:Fire("Evolved", { Tier = tierName })
	return true
end

-- Re-multiplies every already-applied tier onto whatever config.Stats holds
-- RIGHT NOW. Called by MonsterInstance:SetStage after it swaps in a
-- freshly-resolved stage config -- without this, a stage change after
-- evolution would silently discard the evolution's multipliers, which is
-- exactly the "two systems fighting" the blueprint requires composing away.
--
-- Safe against the match schedule this ships with: MonsterPhases' only stage
-- change (1->2) lands at hour 24, before the hour-27 evolution event, so this
-- never actually fires in the current schedule. It exists for the schedule
-- that changes that ordering.
function Evolution:Reapply()
	local instance = self.instance
	local tiers = instance.config.Evolution and instance.config.Evolution.Tiers
	if not tiers then
		return
	end
	for tierName in pairs(self.appliedTiers) do
		local tier = tiers[tierName]
		if tier then
			self:_applyTier(tier)
		end
	end
end

function Evolution:Destroy()
	table.clear(self.appliedTiers)
end

return Evolution
