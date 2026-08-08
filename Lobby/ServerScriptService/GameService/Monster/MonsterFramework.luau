-- The Monster Framework's single boot entry. Replaces EncounterDirector's
-- entry in GameBoot's ordered service list -- the framework starts its own
-- pieces in dependency order so the boot list doesn't have to know about them.
--
-- Placed after MatchTimeEvents / MatchTimeService / MatchCleanup / MatchManager
-- in GameBoot: EncounterDirector subscribes to all four (publisher before
-- subscriber, registry before registrant).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MonsterCapabilities = require(ReplicatedStorage.Modules.Monster.MonsterCapabilities)
local MonsterConfig = require(ReplicatedStorage.Modules.Monster.MonsterConfig)
local Components = require(script.Parent.Components)
local MonsterRegistry = require(script.Parent.MonsterRegistry)
local MonsterScheduler = require(script.Parent.MonsterScheduler)
local MonsterEvolution = require(script.Parent.MonsterEvolution)
local PatrolGraph = require(script.Parent.PatrolGraph)
local EncounterDirector = require(script.Parent.EncounterDirector)

local MonsterFramework = {}

-- Says once, at boot, which components monsters have declared that later steps
-- still have to implement. Without this the phased build is silent about the
-- gap, and "my monster ignores its Evolution config" looks like a bug rather
-- than a step that hasn't landed. Printed per monster, not per spawn.
local function reportPlannedComponents()
	for id in pairs(MonsterConfig.All()) do
		local config = MonsterConfig.Get(id, 1)
		if config then
			local pending = Components.PlannedFor(config.Components)
			if #pending > 0 then
				print(("[MonsterFramework] '%s' declares components not implemented yet: %s")
					:format(id, table.concat(pending, ", ")))
			end
		end
	end
end

local started = false

function MonsterFramework.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Loud boot failure on a malformed capability table or monster config beats
	-- a monster that spawns and behaves strangely an hour into a match. Same
	-- posture as MatchStates.Validate / MatchPhases.Validate in GameBoot.
	MonsterCapabilities.Validate()
	MonsterConfig.Validate()
	reportPlannedComponents()

	-- Registry before scheduler (the scheduler iterates it), both before the
	-- director (it spawns into them). Evolution before the director too: its
	-- MatchTimeEvents.Register calls must land before the director spawns
	-- anything that ApplyCurrentTiers would need to catch up. PatrolGraph
	-- before the director for the same shape of reason: a monster that spawns
	-- before the graph has scanned the map would find zero PatrolPoints and
	-- fall through to Wander for its whole first Brain tick.
	MonsterRegistry.Start()
	MonsterScheduler.Start()
	MonsterEvolution.Start()
	PatrolGraph.Start()
	EncounterDirector.Start()
end

return MonsterFramework
