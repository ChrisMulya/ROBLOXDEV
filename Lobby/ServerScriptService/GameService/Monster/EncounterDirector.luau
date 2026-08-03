-- The seam MAINHANDOFF's "No encounter director" debt row asked for:
-- MonsterService.Spawn had zero production callers before this file existed.
-- Subscribes to MatchManager.StateChanged, reads MatchStates.MonstersSpawn
-- (never branches on the state name itself), and spawns one monster per
-- hand-placed spawn point once gameplay allows it.
--
-- A feature-layer module requiring DOWN into the Match layer (MatchManager,
-- MatchCleanup) -- must not live in Match/, same rule KitLifecycleHook
-- documents for itself.
--
-- Spawn points are Workspace content, not code: tag a BasePart or Model with
-- IsMonsterSpawn = true (optionally MonsterId, defaults "GreyCube", and
-- Stage, defaults 1) the same way Phase 7.5's capture targets were hand-
-- placed with IsMonster/IsObjective. No spawn points placed yet -- this
-- module tolerates that (warns once, spawns nothing) rather than requiring
-- Workspace content to exist, same posture as CameraInventory's missing-
-- Assets fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)
local MonsterService = require(script.Parent.MonsterService)

local EncounterDirector = {}

local spawnedModels: { Model } = {}

local function findSpawnPoints(): { Instance }
	local points = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if (descendant:IsA("BasePart") or descendant:IsA("Model")) and descendant:GetAttribute("IsMonsterSpawn") then
			table.insert(points, descendant)
		end
	end
	return points
end

local function cframeOf(instance: Instance): CFrame
	if instance:IsA("Model") then
		return instance:GetPivot()
	end
	return (instance :: BasePart).CFrame
end

local function spawnEncounter()
	local points = findSpawnPoints()
	if #points == 0 then
		warn("EncounterDirector: no IsMonsterSpawn points in Workspace -- spawning nothing")
		return
	end

	for _, point in ipairs(points) do
		local monsterId = point:GetAttribute("MonsterId") or "GreyCube"
		local stage = point:GetAttribute("Stage")
		local model = MonsterService.Spawn(monsterId, cframeOf(point), stage)
		if model then
			table.insert(spawnedModels, model)
		end
	end
end

local function despawnEncounter()
	for _, model in ipairs(spawnedModels) do
		MonsterService.Despawn(model)
	end
	table.clear(spawnedModels)
end

local started = false

function EncounterDirector.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	MatchManager.StateChanged:Connect(function(newState: string)
		if MatchStates.MonstersSpawn(newState) then
			spawnEncounter()
		end
	end)

	MatchCleanup.RegisterTeardownStep("MonsterTeardown", despawnEncounter)
end

return EncounterDirector
