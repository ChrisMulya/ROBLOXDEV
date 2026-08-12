-- Match-scoped, shared mission progress: photo score, soft-objective
-- completion, and Document pickups collected. No
-- per-player state -- every player's view is identical by construction. See
-- MissionReplicator for the client-facing sync. Game Server only.
--
-- Documents are counted from PickupService.Collected, not from a marker
-- attribute the way objectives are: a collected pickup is Destroyed, so
-- there is no instance left to mark. The denominator is therefore
-- "collected + still registered" rather than a registry walk alone -- that
-- keeps the total stable as pickups leave the world, and it recovers the
-- right figure for a document authored or streamed in mid-match.
--
-- Objective completion is NOT kept in a table here. It is a runtime
-- attribute on the objective instance itself, MissionObjectiveCompleted --
-- deliberately separate from ObjectiveState (which ObjectiveService.Reset
-- returns to Available on death for OnRunEnd objectives) so a
-- death-and-rephotograph loop cannot re-increment the shared counter. See
-- ObjectiveService.Reset and EndGame.ClearPlayerTools for the path this is
-- immune to. IsObjective itself is never touched -- CaptureTargets owns that
-- attribute, and clearing it would desync ObjectiveRegistry's membership
-- count and deny later players their per-player reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local ObjectiveRegistry = require(script.Parent.Parent.Objective.ObjectiveRegistry)
local ObjectiveService = require(script.Parent.Parent.Objective.ObjectiveService)
local RewardService = require(script.Parent.Parent.Reward.RewardService)
local PickupTypes = require(ReplicatedStorage.Modules.Pickup.PickupTypes)
local PickupRegistry = require(script.Parent.Parent.Pickup.PickupRegistry)
local PickupService = require(script.Parent.Parent.Pickup.PickupService)
local MatchManager = require(script.Parent.MatchManager)

local MissionProgress = {}

-- Fires whenever a published value actually changed. No payload -- callers
-- re-read Get().
MissionProgress.Changed = Signal.new()

local COMPLETED_ATTRIBUTE = "MissionObjectiveCompleted"

local DOCUMENT_TYPE = "Document"

local photoScore = 0
local documentsCollected = 0

-- One ObjectiveRegistry.All() walk yields both figures, so the denominator
-- and numerator can never disagree -- an objective destroyed mid-match takes
-- its completion marker with it, dropping both counts together.
local function countObjectives(): (number, number)
	local completed = 0
	local total = 0
	for _, instance in ipairs(ObjectiveRegistry.All()) do
		total += 1
		if instance:GetAttribute(COMPLETED_ATTRIBUTE) then
			completed += 1
		end
	end
	return completed, total
end

local function countRemainingDocuments(): number
	local remaining = 0
	for _, instance in ipairs(PickupRegistry.All()) do
		if PickupTypes.TypeOf(instance) == DOCUMENT_TYPE then
			remaining += 1
		end
	end
	return remaining
end

function MissionProgress.Get(): { [string]: number }
	local objectivesCompleted, objectivesTotal = countObjectives()
	local documentsTotal = documentsCollected + countRemainingDocuments()
	return {
		photoScore = photoScore,
		objectivesCompleted = objectivesCompleted,
		objectivesTotal = objectivesTotal,
		documentsCollected = documentsCollected,
		documentsTotal = documentsTotal,
	}
end

-- Clears the score and every completion marker. Called on
-- MatchManager.StateChanged -> WaitingForPlayers, the same trigger
-- MatchEarnings.Reset() uses.
function MissionProgress.Reset()
	photoScore = 0
	documentsCollected = 0

	for _, instance in ipairs(ObjectiveRegistry.All()) do
		if instance:GetAttribute(COMPLETED_ATTRIBUTE) then
			instance:SetAttribute(COMPLETED_ATTRIBUTE, nil)
		end
	end

	MissionProgress.Changed:Fire()
end

-- RewardService.Awarded fires unconditionally after Grant, even though
-- Grant's own boolean return is discarded by AwardFromCapture -- so a failed
-- grant (e.g. player left mid-capture) still reaches here. Guarding on
-- resultCode == "Awarded" and a non-nil amounts table is what keeps that from
-- inflating the shared total.
-- Every awarded capture counts, not just Monster: this is the combined photo
-- score for the match, monsters and objectives alike. Not filtered by
-- targetType on purpose -- CaptureTargets is a registry where adding a type
-- is a new row there and never a code change, so a future capture type pays
-- into this total without touching this file.
local function onAwarded(_player: Player, _context, result)
	if result.resultCode ~= "Awarded" or not result.amounts then
		return
	end

	local score = result.amounts.Score or 0
	if score == 0 then
		return
	end

	photoScore += score
	MissionProgress.Changed:Fire()
end

-- Subscribing to ObjectiveService.StateChanged rather than RewardService.Awarded
-- keeps one code path correct for both ownership models: Player-owned
-- objectives fire once per player and the marker collapses those to one;
-- Shared objectives fire once globally already.
local function onObjectiveStateChanged(_player: Player?, instance: Instance, newState: string, _oldState: string)
	if newState ~= "Completed" then
		return
	end
	if instance:GetAttribute(COMPLETED_ATTRIBUTE) then
		return
	end

	instance:SetAttribute(COMPLETED_ATTRIBUTE, true)
	MissionProgress.Changed:Fire()
end

-- Fires only after PickupService has already claimed and destroyed the
-- instance, so one collect can never be counted twice, and a handler that
-- refused (or failed) never reaches here at all.
local function onPickupCollected(_player: Player, info)
	if info.typeName ~= DOCUMENT_TYPE then
		return
	end

	documentsCollected += 1
	MissionProgress.Changed:Fire()
end

local started = false

function MissionProgress.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	RewardService.Awarded:Connect(onAwarded)
	ObjectiveService.StateChanged:Connect(onObjectiveStateChanged)
	PickupService.Collected:Connect(onPickupCollected)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "WaitingForPlayers" then
			MissionProgress.Reset()
		end
	end)
end

return MissionProgress
