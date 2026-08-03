-- State authority for the Objective System. Owns GetState/SetState/Complete/
-- Reset and the StateChanged signal. Never computes a reward value -- see
-- Reward/RewardService for the two generic seams (RegisterContextProvider,
-- Awarded) this module hooks into instead of the Reward System knowing
-- anything about objectives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ObjectiveStates = require(ReplicatedStorage.Modules.Objective.ObjectiveStates)
local ObjectiveTypes = require(ReplicatedStorage.Modules.Objective.ObjectiveTypes)
local ObjectiveRegistry = require(script.Parent.ObjectiveRegistry)
-- Hoisted from bottom-of-file (was line 143 of 158). Bottom placement gave no
-- actual cycle protection -- Luau raises on "required recursively" regardless
-- of statement position -- it only hid the coupling from a maintainer
-- skimming the header. See RewardService.RegisterContextProvider/Awarded
-- below for the two generic seams this actually uses.
local RewardService = require(script.Parent.Parent.Reward.RewardService)

local ObjectiveService = {}

-- (player: Player?, instance: Instance, newState: string, oldState: string)
-- player is nil for Shared-ownership changes.
ObjectiveService.StateChanged = Signal.new()

-- Player-ownership state: [userId] = weak-keyed { [instance] = stateName }.
-- Weak-keyed so a destroyed objective doesn't pin memory, same pattern as
-- CaptureGuard's per-player cooldown table.
local playerStates = {}

local function playerTable(userId: number)
	local states = playerStates[userId]
	if not states then
		states = setmetatable({}, { __mode = "k" })
		playerStates[userId] = states
	end
	return states
end

-- Without this, a player who leaves and rejoins the same server keeps their
-- old objective completions (playerTable finds the stale table by userId),
-- and the outer table itself grows by one entry per player forever.
Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
end)

local function ownershipFor(instance: Instance): string
	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).Ownership
end

local function initialStateFor(instance: Instance): string
	return ObjectiveTypes.Get(ObjectiveTypes.TypeOf(instance)).InitialState
end

-- Shared state lives directly on the instance's ObjectiveState attribute --
-- attributes replicate to every client automatically, which is the repo's
-- existing broadcast mechanism (IsMonster, Stage, KeepDuringCamera). See
-- ObjectiveReplicator for the Player-ownership remote path attributes can't
-- express.
local function getSharedState(instance: Instance): string
	return instance:GetAttribute("ObjectiveState") or initialStateFor(instance)
end

local function setSharedState(instance: Instance, state: string)
	instance:SetAttribute("ObjectiveState", state)
end

function ObjectiveService.GetState(player: Player?, instance: Instance): string
	if ownershipFor(instance) == "Shared" then
		return getSharedState(instance)
	end

	if not player then
		return initialStateFor(instance)
	end

	local states = playerTable(player.UserId)
	return states[instance] or initialStateFor(instance)
end

function ObjectiveService.SetState(player: Player?, instance: Instance, state: string): boolean
	if not ObjectiveStates.IsValid(state) then
		warn(("ObjectiveService: unknown state '%s'"):format(tostring(state)))
		return false
	end

	if ownershipFor(instance) == "Shared" then
		local oldState = getSharedState(instance)
		if oldState == state then
			return true
		end
		setSharedState(instance, state)
		ObjectiveService.StateChanged:Fire(nil, instance, state, oldState)
		return true
	end

	if not player then
		warn("ObjectiveService: SetState on a Player-owned objective requires a player")
		return false
	end

	local states = playerTable(player.UserId)
	local oldState = states[instance] or initialStateFor(instance)
	if oldState == state then
		return true
	end
	states[instance] = state
	ObjectiveService.StateChanged:Fire(player, instance, state, oldState)
	return true
end

function ObjectiveService.Complete(player: Player, instance: Instance): boolean
	return ObjectiveService.SetState(player, instance, "Completed")
end

-- instance nil = every registered objective. For a Player-owned objective,
-- player must be given (there is no "reset this for everyone" for
-- Player-owned state -- each player's run ends independently). For a
-- Shared objective, player is ignored. Types with ResetPolicy == "Never"
-- are skipped. Returns how many objectives were actually reset.
function ObjectiveService.Reset(player: Player?, instance: Instance?): number
	local resetCount = 0

	local function resetOne(targetInstance: Instance)
		local typeDef = ObjectiveTypes.Get(ObjectiveTypes.TypeOf(targetInstance))
		if typeDef.ResetPolicy == "Never" then
			return
		end

		if typeDef.Ownership == "Shared" then
			if ObjectiveService.SetState(nil, targetInstance, typeDef.InitialState) then
				resetCount += 1
			end
		elseif player then
			if ObjectiveService.SetState(player, targetInstance, typeDef.InitialState) then
				resetCount += 1
			end
		end
	end

	if instance then
		resetOne(instance)
	else
		for _, targetInstance in ipairs(ObjectiveRegistry.All()) do
			resetOne(targetInstance)
		end
	end

	return resetCount
end

-- Wiring into the Reward System's two generic seams. RewardService never
-- learns what an objective is: the provider only ever adds plain
-- objectiveRegistered/objectiveState fields, and the Awarded subscriber only
-- acts when targetType == "Objective".
RewardService.RegisterContextProvider(function(player, subject, context)
	if not ObjectiveRegistry.IsRegistered(subject) then
		return { objectiveRegistered = false }
	end
	return { objectiveRegistered = true, objectiveState = ObjectiveService.GetState(player, subject) }
end)

RewardService.Awarded:Connect(function(player, context, _result)
	if context.targetType == "Objective" then
		ObjectiveService.Complete(player, context.subject)
	end
end)

return ObjectiveService
