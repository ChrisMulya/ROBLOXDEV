-- The availability + requirement authority for the Exit System. Owns:
--   - whether MainExit/AlternateExit are currently usable (derived, never
--     stored independently of MissionProgress)
--   - the Alternate requirement, selected once per match
--   - the record of who has escaped and through which exit
--
-- Never stores a mission counter of its own -- reads MissionProgress.Get()
-- on demand and re-derives. MissionProgress must never require this module
-- (R2: this is a feature-layer module reaching down into the Match layer,
-- not the reverse).
--
-- CanExit is written onto the exit instance for the map/VFX layer to read,
-- but ExitService never trusts that replica -- it re-derives from
-- ExitState.IsAvailable() at interaction time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local Signal = require(ReplicatedStorage.Modules.Shared.Signal)
local ExitTypes = require(ReplicatedStorage.Modules.Exit.ExitTypes)
local ExitConfig = require(ReplicatedStorage.Modules.Exit.ExitConfig)
local ExitRequirements = require(ReplicatedStorage.Modules.Exit.ExitRequirements)

local MissionProgress = require(script.Parent.Parent.Match.MissionProgress)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)
local MatchTimeEvents = require(script.Parent.Parent.MatchTime.MatchTimeEvents)
local ExitRegistry = require(script.Parent.ExitRegistry)

local ExitState = {}

-- Fires whenever availability or the requirement actually changed. No
-- payload -- same convention as MissionProgress.Changed; callers re-read
-- IsAvailable()/GetRequirement()/GetSnapshot().
ExitState.Changed = Signal.new()

local mainAvailable = false
local alternateAvailable = false
local alternateRequirement: ExitRequirements.ExitRequirement? = nil

-- A map authors 2-5 Alternate exits, but only ONE of them opens per match --
-- rolled at the unlock hour alongside the requirement. So Alternate
-- availability is two facts, not one: the TYPE is available (the requirement
-- is satisfied) and this particular INSTANCE is the chosen one. Main has no
-- such split, which is why the type-level flags above stay as they were and
-- this is an extra filter rather than a rewrite into per-instance state.
local selectedAlternate: Instance? = nil

-- [userId] = { exitType: string, atHour: number?, atClock: number }
local escaped: { [number]: { exitType: string, atHour: number?, atClock: number } } = {}

-- Independent of math.random/any other consumer's seed state. Created once
-- at boot rather than re-created per match: the requirement's unpredictability
-- comes from being sampled once per match at an unpredictable real-world
-- moment (whenever hour 27 is reached), not from reseeding.
local rng = Random.new()

-- The single place the type-level flag and the per-instance Alternate roll are
-- combined. Everything that asks "is THIS exit usable" -- the CanExit
-- attribute below, ExitService's dwell test, ExitVisuals' tint, ExitLabel's
-- sign -- goes through here (via IsInstanceAvailable) so a non-chosen
-- Alternate can never read as open through one path and sealed through
-- another.
local function instanceIsOpen(instance: Instance, typeName: string, typeAvailable: boolean): boolean
	if not typeAvailable then
		return false
	end
	if typeName == "Alternate" then
		return selectedAlternate ~= nil and instance == selectedAlternate
	end
	return true
end

local function applyCanExit(typeName: string, value: boolean)
	for _, instance in ipairs(ExitRegistry.AllOfType(typeName)) do
		instance:SetAttribute(ExitTypes.AvailabilityAttribute, instanceIsOpen(instance, typeName, value))
	end
end

-- Rolls which Alternate opens this match. Called once, at the unlock hour,
-- BEFORE the requirement is evaluated, so availability and selection land in
-- the same pass.
--
-- AllOfType iterates a hash table, so its order varies run to run; the sort
-- makes the roll itself the only source of randomness, which is what keeps
-- this reproducible for a given rng state when debugging a "wrong exit
-- opened" report.
local function selectAlternate()
	local candidates = ExitRegistry.AllOfType("Alternate")
	if #candidates == 0 then
		warn("ExitState: no Alternate exits registered at the unlock hour -- none will open this match")
		return
	end

	table.sort(candidates, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	selectedAlternate = candidates[rng:NextInteger(1, #candidates)]
end

-- Re-derives both exits' availability from the current mission snapshot.
-- Only touches instance attributes/prompts for whichever exit's availability
-- actually flipped, and only fires Changed when something did -- mirrors
-- MissionProgress.Changed's "fires whenever a published value actually
-- changed" contract.
local function recompute()
	local snapshot = MissionProgress.Get()

	local newMain = ExitRequirements.IsMainSatisfied(snapshot)
	local newAlternate = false
	if alternateRequirement then
		newAlternate = ExitRequirements.IsSatisfied(alternateRequirement, snapshot)
	end

	local changed = false

	if newMain ~= mainAvailable then
		mainAvailable = newMain
		applyCanExit("Main", mainAvailable)
		changed = true
	end

	if newAlternate ~= alternateAvailable then
		alternateAvailable = newAlternate
		applyCanExit("Alternate", alternateAvailable)
		changed = true
	end

	if changed then
		ExitState.Changed:Fire()
	end
end

-- MatchTimeEvents handler for the hour-27 milestone. Guarded even though
-- MatchTimeEvents.Dispatch cannot fire an entry twice within one match --
-- the guard keeps "selected exactly once" a local, readable invariant rather
-- than one that depends on reading MatchTimeEvents' cursor logic.
local function onAlternateUnlock(_hour: number)
	if alternateRequirement then
		return
	end

	selectAlternate()
	alternateRequirement = ExitRequirements.SelectRandom(rng, MissionProgress.Get())

	-- recompute() only fires Changed if availability itself flipped, but the
	-- requirement going from nil to a real value is new information on its
	-- own (ExitReplicator needs to publish the requirement kind even if the
	-- Alternate stays locked) -- so fire unconditionally here too. A
	-- consumer re-reading state twice in one tick is harmless; Signal fires
	-- are deferred and cheap.
	recompute()
	ExitState.Changed:Fire()
end

function ExitState.IsAvailable(typeName: string): boolean
	if typeName == "Main" then
		return mainAvailable
	elseif typeName == "Alternate" then
		return alternateAvailable
	end
	return false
end

-- "Is this exact exit usable right now" -- the type flag AND, for Alternate,
-- the per-match roll. Callers that act on a specific instance must use this,
-- never IsAvailable(TypeOf(instance)), which answers a strictly weaker
-- question.
function ExitState.IsInstanceAvailable(instance: Instance): boolean
	local typeName = ExitTypes.TypeOf(instance)
	if not typeName then
		return false
	end
	return instanceIsOpen(instance, typeName, ExitState.IsAvailable(typeName))
end

-- nil before the unlock hour, and on a map that authored no Alternate exits.
function ExitState.GetSelectedAlternate(): Instance?
	return selectedAlternate
end

function ExitState.GetRequirement(): ExitRequirements.ExitRequirement?
	return alternateRequirement
end

function ExitState.GetSnapshot()
	return {
		mainAvailable = mainAvailable,
		alternateAvailable = alternateAvailable,
		alternateRequirement = alternateRequirement,
	}
end

function ExitState.RecordEscape(userId: number, exitType: string, hour: number?)
	escaped[userId] = { exitType = exitType, atHour = hour, atClock = os.clock() }
end

function ExitState.GetEscape(userId: number)
	return escaped[userId]
end

-- Clears everything back to pre-match state. Called on
-- MatchManager.StateChanged -> WaitingForPlayers, the same trigger
-- MissionProgress.Reset() uses, so a second match on the same server rolls a
-- fresh requirement instead of reusing the last one.
function ExitState.Reset()
	mainAvailable = false
	alternateAvailable = false
	alternateRequirement = nil
	selectedAlternate = nil
	escaped = {}

	applyCanExit("Main", false)
	applyCanExit("Alternate", false)
end

local started = false

function ExitState.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	-- Registry before registrant: this Register call must land before
	-- MatchTimeService.Start() begins sampling, or the hour-27 entry could
	-- miss the first Dispatch of a match that's already past it (Debug
	-- schedules run fast enough for this to matter). GameBoot enforces the
	-- ordering.
	MatchTimeEvents.Register("ExitAlternateUnlock", ExitConfig.AlternateUnlockHour, onAlternateUnlock)

	MissionProgress.Changed:Connect(recompute)

	-- The chosen Alternate being destroyed mid-match would otherwise leave a
	-- dangling selection that no live instance can ever match, so the type
	-- would read available while nothing on the map is. Drop the selection and
	-- republish instead: the Alternate is simply gone for this match.
	ExitRegistry.Unregistered:Connect(function(instance)
		if selectedAlternate ~= instance then
			return
		end
		selectedAlternate = nil
		applyCanExit("Alternate", alternateAvailable)
		ExitState.Changed:Fire()
	end)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "WaitingForPlayers" then
			ExitState.Reset()
		elseif newState == "Playing" then
			local snapshot = MissionProgress.Get()
			if (snapshot.objectivesTotal + snapshot.documentsTotal) <= 0 then
				warn("ExitState: map has zero soft objectives and zero documents -- MainExit can never open this match")
			end
		end
	end)
end

return ExitState
