-- Resolves a monster id + stage into one frozen, ready-to-read config table.
--
-- Resolution order:
--   1. the monster's Configs/<Id> file  (capabilities, brain, states, limits)
--   2. its Stats, declared inline in that file
--   3. sparse stage overrides merged upward (stage 1 is the complete base)
--   4. Limits clamped last
--
-- Stats used to fall back to a shared MonsterStats module. That existed only
-- so the GreyCube placeholder had one home for its numbers while the framework
-- was built around it; with GreyCube gone, every monster carries its own stats
-- and there is no shared table to drift out of sync with.
--
-- The result is table.freeze'd. Nothing mutates a resolved config -- Restage
-- and Evolution swap the whole table by reference, which is what makes those
-- operations atomic from a mid-tick reader's point of view. Freezing turns a
-- stray write into an immediate error instead of a stat that silently drifts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterCapabilities = require(ReplicatedStorage.Modules.Monster.MonsterCapabilities)
local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local Configs = require(ReplicatedStorage.Modules.Monster.Configs)

local MonsterConfig = {}

-- [monsterId .. ":" .. stage] = resolved. Resolution is deterministic and the
-- result is frozen, so one shared table per (id, stage) is safe and means
-- Restage doesn't re-merge on every phase change.
local cache = {}

function MonsterConfig.Definition(monsterId: string)
	return Configs[monsterId]
end

function MonsterConfig.All()
	return Configs
end

-- Stage 1 must be a complete table; later stages are sparse overrides merged in
-- ascending order, so a stage entry only lists what actually changed.
local function mergeStages(statsByStage, stage: number, monsterId: string)
	local base = statsByStage[1]
	if not base then
		warn(("MonsterConfig: monster '%s' has no Stage 1 base table"):format(monsterId))
		return nil
	end

	if stage <= 1 then
		return table.clone(base)
	end

	local merged = table.clone(base)
	for s = 2, stage do
		local override = statsByStage[s]
		if override then
			for key, value in pairs(override) do
				merged[key] = value
			end
		end
	end
	return merged
end

-- Applied last, after stage merges and (from step 10) evolution multipliers.
-- Public so Evolution can reuse it rather than reimplementing the ceiling.
function MonsterConfig.ClampStats(stats, limits)
	if not limits then
		return stats
	end

	for key, limit in pairs(limits) do
		local value = stats[key]
		if type(value) == "number" then
			if limit.Min and value < limit.Min then
				stats[key] = limit.Min
			elseif limit.Max and value > limit.Max then
				stats[key] = limit.Max
			end
		end
	end

	return stats
end

local function resolveStats(definition, monsterId: string, stage: number)
	if not definition.Stats then
		warn(("MonsterConfig: monster '%s' declares no Stats table"):format(monsterId))
		return nil
	end
	return mergeStages(definition.Stats, stage, monsterId)
end

function MonsterConfig.Get(monsterId: string, stage: number?)
	local resolvedStage = stage or MonsterConstants.DefaultStage
	local key = monsterId .. ":" .. tostring(resolvedStage)

	local cached = cache[key]
	if cached then
		return cached
	end

	local definition = Configs[monsterId]
	if not definition then
		warn(("MonsterConfig.Get: unknown monster '%s'"):format(tostring(monsterId)))
		return nil
	end

	local stats = resolveStats(definition, monsterId, resolvedStage)
	if not stats then
		return nil
	end

	MonsterConfig.ClampStats(stats, definition.Limits)

	local capabilities = MonsterCapabilities.Resolve(definition.Capabilities, monsterId)

	local resolved = {
		Id           = monsterId,
		DisplayName  = definition.DisplayName or monsterId,
		Stage        = resolvedStage,

		Capabilities = capabilities,
		Components   = MonsterCapabilities.ComponentsFor(capabilities),
		-- States a capability makes ELIGIBLE. The Brain intersects this with
		-- definition.States (which carries the per-state weights) at step 4.
		StateSet     = MonsterCapabilities.StatesFor(capabilities),
		Stimuli      = MonsterCapabilities.StimuliFor(capabilities),

		Stats        = table.freeze(stats),
		Limits       = definition.Limits,
		Model        = definition.Model,
		Brain        = definition.Brain,
		States       = definition.States,
		Perception   = definition.Perception,
		Navigation   = definition.Navigation,
		Aggression   = definition.Aggression,
		Combat       = definition.Combat,
		Evolution    = definition.Evolution,
		Presentation = definition.Presentation,
	}

	table.freeze(resolved)
	cache[key] = resolved
	return resolved
end

-- Boot assert, same posture as MatchStates.Validate / MatchPhases.Validate: a
-- malformed monster should be a loud boot failure, not a monster that spawns
-- and then behaves strangely an hour into a match.
function MonsterConfig.Validate()
	for id, definition in pairs(Configs) do
		assert(type(definition) == "table", ("MonsterConfig: '%s' is not a table"):format(id))
		assert(definition.Id == nil or definition.Id == id,
			("MonsterConfig: '%s' declares mismatched Id '%s'"):format(id, tostring(definition.Id)))
		assert(type(definition.Capabilities) == "table",
			("MonsterConfig: '%s' has no Capabilities list"):format(id))

		for _, name in ipairs(definition.Capabilities) do
			assert(MonsterCapabilities.All[name],
				("MonsterConfig: '%s' declares unknown capability '%s'"):format(id, name))
		end

		for key, limit in pairs(definition.Limits or {}) do
			assert(type(limit) == "table",
				("MonsterConfig: '%s' Limits.%s must be a table"):format(id, key))
			assert(limit.Min == nil or limit.Max == nil or limit.Min <= limit.Max,
				("MonsterConfig: '%s' Limits.%s has Min above Max"):format(id, key))
		end

		-- Aggression rates MUST be in [0,1]. A negative rate is the dangerous
		-- case: rate^dt with a fractional dt is NaN, NaN fails every comparison,
		-- and the monster silently wedges forever with nothing in Output --
		-- thresholds stop firing and the level bands stop resolving. A rate
		-- above 1 diverges from the target instead of converging. Both are
		-- plausible typos ("Decay = -0.1" reads like "decay faster"), so they
		-- fail at boot rather than an hour into a match.
		local aggression = definition.Aggression
		if aggression then
			for _, field in ipairs({ "Rise", "Decay" }) do
				local rate = aggression[field]
				assert(rate == nil or (type(rate) == "number" and rate >= 0 and rate <= 1),
					("MonsterConfig: '%s' Aggression.%s must be a number in [0,1]"):format(id, field))
			end

			for name, threshold in pairs(aggression.Thresholds or {}) do
				assert(type(threshold) == "number" and threshold >= 0 and threshold <= 1,
					("MonsterConfig: '%s' Aggression.Thresholds.%s must be a number in [0,1]")
						:format(id, tostring(name)))
			end

			for name, modifier in pairs(aggression.Modifiers or {}) do
				assert(type(modifier) == "table",
					("MonsterConfig: '%s' Aggression.Modifiers.%s must be a table"):format(id, tostring(name)))
				assert(modifier.Weight == nil or type(modifier.Weight) == "number",
					("MonsterConfig: '%s' Aggression.Modifiers.%s.Weight must be a number")
						:format(id, tostring(name)))
			end
		end

		assert(type(definition.Stats) == "table",
			("MonsterConfig: '%s' has no Stats table -- every monster declares its own"):format(id))
		assert(MonsterConfig.Get(id, 1),
			("MonsterConfig: '%s' has no resolvable Stage 1 stats"):format(id))
	end
end

return MonsterConfig
