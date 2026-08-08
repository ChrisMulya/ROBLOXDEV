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
-- IsMonsterSpawn = true (optionally MonsterId, defaulting to
-- MonsterConstants.DefaultMonsterId, and
-- Stage, defaults 1) the same way Phase 7.5's capture targets were hand-
-- placed with IsMonster/IsObjective. No spawn points placed yet -- this
-- module tolerates that (warns once, spawns nothing) rather than requiring
-- Workspace content to exist, same posture as CameraInventory's missing-
-- Assets fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MatchPhases = require(ReplicatedStorage.Modules.MatchTime.MatchPhases)
local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchCleanup = require(script.Parent.Parent.Match.MatchCleanup)
local MatchTimeService = require(script.Parent.Parent.MatchTime.MatchTimeService)
local MonsterService = require(script.Parent.MonsterService)

local EncounterDirector = {}

-- { model, baseStage }. baseStage is the spawn point's authored Stage, kept
-- separately because model:GetAttribute("Stage") holds the EFFECTIVE stage
-- and is rewritten on every re-stage -- reading it back would ratchet the
-- authored floor upwards and make the escalation irreversible.
local spawnedModels: { { model: Model, baseStage: number } } = {}

local function findSpawnPoints(): { Instance }
	local points = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if (descendant:IsA("BasePart") or descendant:IsA("Model")) and descendant:GetAttribute("IsMonsterSpawn") then
			table.insert(points, descendant)
		end
	end
	return points
end

-- The marker's TOP SURFACE, not its centre. A spawn marker is normally a flat
-- part lying on the floor, so its CFrame sits half its thickness UNDER the
-- floor -- spawning there put the rig partly inside the geometry, and a rig
-- that starts interpenetrating resolves by being pushed through rather than
-- out. MonsterService adds the rig's own clearance on top of this.
local function cframeOf(instance: Instance): CFrame
	if instance:IsA("Model") then
		local pivot, size = instance:GetPivot(), instance:GetExtentsSize()
		return pivot + Vector3.new(0, size.Y / 2, 0)
	end
	local part = instance :: BasePart
	return part.CFrame + Vector3.new(0, part.Size.Y / 2, 0)
end

-- The spawn point's authored Stage is a FLOOR, not an override: a point
-- hand-placed at Stage 2 is always at least 2, and the match phase can only
-- ever escalate it. max() rather than a straight assignment keeps the ramp
-- monotonic (difficulty never drops when a phase with a lower stage follows)
-- and makes "no match time" degrade to exactly today's behaviour -- outside
-- a match GetPhase() is nil and the authored stage stands alone.
local function effectiveStage(baseStage: number): number
	local phase = MatchTimeService.GetPhase()
	if not phase then
		return baseStage
	end
	return math.max(baseStage, MatchPhases.GetMonsterStage(phase) or 1)
end

local function spawnEncounter()
	local points = findSpawnPoints()
	if #points == 0 then
		warn("EncounterDirector: no IsMonsterSpawn points in Workspace -- spawning nothing")
		return
	end

	for _, point in ipairs(points) do
		local monsterId = point:GetAttribute("MonsterId") or MonsterConstants.DefaultMonsterId
		local baseStage = point:GetAttribute("Stage") or MonsterConstants.DefaultStage
		local model = MonsterService.Spawn(monsterId, cframeOf(point), effectiveStage(baseStage))
		if model then
			table.insert(spawnedModels, { model = model, baseStage = baseStage })
		end
	end
end

-- Re-stats every live monster when the match phase changes. This is what
-- makes MonsterStats' stage-override merge actually reachable during a
-- match: before this, Stage was read once at spawn and the monsters that
-- existed at 4 PM were the same monsters at 5 AM.
local function restageEncounter()
	for _, entry in ipairs(spawnedModels) do
		MonsterService.Restage(entry.model, effectiveStage(entry.baseStage))
	end
end

local function despawnEncounter()
	for _, entry in ipairs(spawnedModels) do
		MonsterService.Despawn(entry.model)
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

	-- MatchTimeService is started earlier in GameBoot's list, so this
	-- subscription is in place before the clock can fire its first phase
	-- change (publisher before subscriber).
	MatchTimeService.PhaseChanged:Connect(restageEncounter)

	MatchCleanup.RegisterTeardownStep("MonsterTeardown", despawnEncounter)
end

return EncounterDirector
