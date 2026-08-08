-- Bridges MatchTimeEvents to Components/Evolution. Two jobs:
--
--   1. Register one MatchTimeEvents entry per unique hour any monster
--      declares a tier at, so the scheduled event actually fires.
--   2. Apply, at spawn, any tier whose hour has already passed -- so a
--      monster spawned at hour 30 is evolved immediately rather than waiting
--      for an event that already fired for everyone else (blueprint §18).
--
-- Scanning MonsterConfig.All() rather than hardcoding "Witching at 27" is
-- what makes adding a second tier, or a second monster with its own tiers, a
-- config-only change -- this module never names a monster or a tier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MonsterConfig = require(ReplicatedStorage.Modules.Monster.MonsterConfig)
local MatchTimeEvents = require(ServerScriptService.GameService.MatchTime.MatchTimeEvents)
local MatchTimeService = require(ServerScriptService.GameService.MatchTime.MatchTimeService)
local MonsterRegistry = require(script.Parent.MonsterRegistry)

local MonsterEvolution = {}

-- Every tier across every monster's Stage-1 definition, so this only reads
-- config shape and never touches Stats resolution. Stage doesn't affect which
-- tiers exist or their AtHour, only what they multiply.
local function everyTier(): { { monsterId: string, tierName: string, atHour: number } }
	local out = {}
	for monsterId, definition in pairs(MonsterConfig.All()) do
		local tiers = definition.Evolution and definition.Evolution.Tiers
		for tierName, tier in pairs(tiers or {}) do
			table.insert(out, { monsterId = monsterId, tierName = tierName, atHour = tier.AtHour })
		end
	end
	return out
end

-- Evolves every LIVE monster whose own config declares a tier at this exact
-- hour. Deliberately does not assume "the tier that fired is the tier every
-- monster has" -- two monster types could each declare a same-named tier at
-- different hours, or different tier names at the same hour.
local function evolveAt(hour: number)
	MonsterRegistry.ForEach(function(_model, instance)
		local tiers = instance.config.Evolution and instance.config.Evolution.Tiers
		if not tiers then
			return
		end
		for tierName, tier in pairs(tiers) do
			if tier.AtHour == hour then
				instance:Evolve(tierName)
			end
		end
	end)
end

-- Applies every tier whose hour has already passed, in ascending hour order,
-- to ONE freshly spawned instance. Ascending order matters the moment a
-- monster ever declares two tiers: applying out of order would multiply the
-- later tier onto a base the earlier one was supposed to have already raised.
--
-- Evolution:Apply is idempotent per instance, so calling this and then having
-- MatchTimeEvents' own dispatch ALSO reach this monster later (a spawn
-- landing in the same hour as the scheduled event, a race between spawn order
-- and dispatch order) double-fires harmlessly -- the second call is a no-op.
function MonsterEvolution.ApplyCurrentTiers(instance)
	local hour = MatchTimeService.GetHour()
	if not hour then
		return
	end

	local tiers = instance.config.Evolution and instance.config.Evolution.Tiers
	if not tiers then
		return
	end

	local due = {}
	for tierName, tier in pairs(tiers) do
		if tier.AtHour <= hour then
			table.insert(due, { name = tierName, atHour = tier.AtHour })
		end
	end
	table.sort(due, function(a, b)
		return a.atHour < b.atHour
	end)

	for _, entry in ipairs(due) do
		instance:Evolve(entry.name)
	end
end

local started = false

function MonsterEvolution.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Dedupe hours: several monsters or tiers sharing an hour register ONE
	-- MatchTimeEvents entry, not one per tier -- MatchTimeEvents itself has no
	-- dedupe, and firing the same hour twice would double-run evolveAt
	-- harmlessly (idempotent) but pointlessly.
	local registeredHours = {}
	for _, entry in ipairs(everyTier()) do
		if not registeredHours[entry.atHour] then
			registeredHours[entry.atHour] = true
			MatchTimeEvents.Register(("MonsterEvolution:%d"):format(entry.atHour), entry.atHour, function(hour)
				evolveAt(hour)
			end)
		end
	end
end

return MonsterEvolution
