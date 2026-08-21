-- Spawn / restage / despawn. Owns model construction and the workspace-facing
-- attributes; the live set lives in MonsterRegistry and the tick loop lives in
-- MonsterScheduler.
--
-- This module used to hold both. The Heartbeat in particular was connected at
-- MODULE SCOPE, so requiring MonsterService from anywhere started ticking --
-- see MonsterScheduler for why that's gone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local MonsterConfig = require(ReplicatedStorage.Modules.Monster.MonsterConfig)
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)
local MonsterFactory = require(script.Parent.MonsterFactory)
local MonsterInstance = require(script.Parent.MonsterInstance)
local MonsterRegistry = require(script.Parent.MonsterRegistry)
local MonsterEvolution = require(script.Parent.MonsterEvolution)

local MonsterService = {}

-- Lazy: MatchManager is Game-Server-only. Fails closed off the Game Server;
-- MonsterFramework.Start() already asserts GameServer so this is belt-and-
-- braces, not the only guard.
local function monstersCanSpawn(): boolean
	if not ServerRole.Is("GameServer") then
		return false
	end
	local MatchManager = require(script.Parent.Parent.Match.MatchManager)
	return MatchStates.MonstersSpawn(MatchManager.Get())
end

-- Code-built monsters, keyed by config.Model.Builder. Empty since the GreyCube
-- placeholder was removed -- every monster is now an authored asset under
-- ReplicatedStorage/Assets/Monster.
--
-- The seam stays because it is the only way to get a monster with no art yet:
-- add a function here returning an UNPARENTED, unpositioned Model, then set
-- Model = { Source = "Builder", Builder = "<name>" } in its config.
-- MonsterFactory pivots, anchors and parents it.
local MODEL_BUILDERS = {}

-- Studs of air under the rig's feet at spawn. Enough to clear a marker that
-- overlaps the floor slightly, small enough that the drop is not visible.
local SPAWN_CLEARANCE = 2

-- How far to raise a model so its lowest point clears the spawn CFrame by
-- SPAWN_CLEARANCE. Measured off the bounding box rather than a hardcoded rig
-- height so a taller monster added later needs no edit here.
local function spawnLift(model: Model): number
	local pivot = model:GetPivot()
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	return (pivot.Position.Y - bottom) + SPAWN_CLEARANCE
end

function MonsterService.Spawn(monsterId: string, cframe: CFrame, stage: number?): Model?
	if not monstersCanSpawn() then
		warn("MonsterService.Spawn: monsters aren't allowed to spawn outside of active gameplay")
		return nil
	end

	local config = MonsterConfig.Get(monsterId, stage)
	if not config then
		return nil
	end

	local model = MonsterFactory.Create(config, MODEL_BUILDERS)
	if not model then
		return nil
	end

	-- Ask CaptureTargets for the attribute name rather than spelling it: that
	-- module owns what IsMonster means, and setting it is what makes the
	-- monster photographable with zero camera-code changes. If the Monster row
	-- were ever removed there, monsters SHOULD stop being tagged -- hence a
	-- warn rather than a hardcoded fallback that would silently outvote it.
	local isMonsterAttribute = CaptureTargets.AttributeFor("Monster")
	if isMonsterAttribute then
		model:SetAttribute(isMonsterAttribute, true)
	else
		warn("MonsterService.Spawn: CaptureTargets has no Monster type -- monster will not be photographable")
	end
	model:SetAttribute(MonsterConstants.Attributes.MonsterId, monsterId)
	model:SetAttribute(MonsterConstants.Attributes.Stage, stage or MonsterConstants.DefaultStage)

	-- Pivot BEFORE parenting. An unanchored rig parented first and positioned
	-- second is simulated at the origin for a frame and can end up under the
	-- floor or interpenetrating geometry.
	--
	-- Lifted so the rig's LOWEST point starts SPAWN_CLEARANCE above the caller's
	-- CFrame rather than its pivot sitting on it. The pivot is HumanoidRootPart,
	-- roughly mid-torso, so pivoting straight onto a floor-level marker buried
	-- the legs in the floor -- and a rig that spawns already interpenetrating is
	-- as likely to be resolved downward through the geometry as upward out of
	-- it, which is the "spawns beneath the world and noclips" case. Dropping a
	-- short distance onto the floor has no such ambiguity.
	model:PivotTo(cframe + Vector3.new(0, spawnLift(model), 0))
	model.Parent = workspace

	local instance = MonsterInstance.new(model, monsterId, stage)
	if not instance then
		model:Destroy()
		return nil
	end

	-- Blueprint §18: a monster spawned after an evolution hour has already
	-- passed must get the tier immediately -- it will never hear the
	-- MatchTimeEvents dispatch for an hour the clock is already past.
	-- Idempotent against that dispatch reaching this same monster later (a
	-- spawn racing the scheduled event in the same hour), so no ordering
	-- requirement between this and MonsterRegistry.Add below.
	MonsterEvolution.ApplyCurrentTiers(instance)

	MonsterRegistry.Add(model, instance)

	-- The other teardown path is MonsterScheduler's orphan sweep, for models
	-- unparented via `model.Parent = nil` (Destroying does not fire for that).
	-- Registry.Remove is idempotent, so whichever runs first wins.
	model.Destroying:Connect(function()
		MonsterRegistry.Remove(model)
	end)

	return model
end

function MonsterService.Restage(model: Model, stage: number): boolean
	local instance = MonsterRegistry.Get(model)
	if not instance then
		return false
	end
	return instance:SetStage(stage)
end

function MonsterService.Despawn(model: Model)
	if MonsterRegistry.Get(model) then
		model:Destroy() -- fires Destroying above, which unregisters and cleans up
	end
end

return MonsterService
