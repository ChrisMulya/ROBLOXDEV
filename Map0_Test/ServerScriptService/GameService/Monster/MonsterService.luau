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

local MonsterService = {}

-- Lazy for the same reason as RewardService's isScoringActive: this module is
-- reachable from both places (content-migration gap) and MatchManager is
-- Game-Server-only.
local function monstersCanSpawn(): boolean
	if not ServerRole.Is("GameServer") then
		return true
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
	model:PivotTo(cframe)
	model.Parent = workspace

	local instance = MonsterInstance.new(model, monsterId, stage)
	if not instance then
		model:Destroy()
		return nil
	end

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
