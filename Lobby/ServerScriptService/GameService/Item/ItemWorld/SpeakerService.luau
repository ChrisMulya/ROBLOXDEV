-- Lure behaviour for every placed Compact Speaker.
--
-- Two-stage by design: placing the speaker (the CompactSpeaker tool) leaves an
-- INERT object in the world -- silent, no lure, no expiry, no contact rule.
-- Using the CompactSpeakerRemotes the placement left in your slot is what
-- ARMS it, and only then does it start its noise/lure window. So a player can
-- plant one early and set it off from a distance when it's actually useful,
-- rather than the placement itself being the whole commitment.
--
-- Publishes to StimulusBus and never touches MonsterService directly -- range
-- is a receiver-side concept in this architecture (see Monster/Sensors/
-- LureSensor), so "lure within 140 studs" is a sensor with that range, not a
-- radius on the publish call here.
--
-- Monster contact destroys an ACTIVE speaker immediately. Not a .Touched
-- connection -- the rig's HumanoidRootPart is CanCollide false and buried in
-- the torso, the same reason Monster/Components/Combat ships a "Reach"
-- distance-scan mode instead of "Contact" for real monsters. This reuses that
-- same distance-scan shape. An inert speaker ignores contact entirely; there
-- is nothing yet to interrupt.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)
local StimulusBus = require(ServerScriptService.GameService.Stimulus.StimulusBus)
local DeployablePlacement = require(script.Parent.DeployablePlacement)
local DeployableRegistry = require(script.Parent.DeployableRegistry)
local MonsterRegistry = require(ServerScriptService.GameService.Monster.MonsterRegistry)

local SpeakerService = {}

local TICK_INTERVAL = 0.5
-- Re-published roughly once a second for the speaker's whole active window, so
-- a monster that finishes some other investigation mid-window can still be
-- drawn in by a fresh stimulus rather than only the initial one.
local PUBLISH_INTERVAL = 1
-- Small deliberate hitbox around the speaker itself, not the lure radius.
local CONTACT_RADIUS = 4

-- [model] = { record, lifetime, active, expiresAt, lastPublishAt, placedAt }
local tracked = {}

local function positionOf(model: Instance): Vector3
	if model:IsA("Model") then
		return model:GetPivot().Position
	end
	return (model :: BasePart).Position
end

-- Lazy lookup, same resilience pattern as ShopCatalog.ResolveTemplate -- the
-- Sounds tree is hand-placed in Studio, so a missing clip degrades to a silent
-- (but still functional) lure rather than erroring out the whole activation.
local function resolveSoundTemplate(): Sound?
	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	local toolFolder = sounds and sounds:FindFirstChild("Tool")
	local sound = toolFolder and toolFolder:FindFirstChild("CompactSpeakerSound")
	return (sound and sound:IsA("Sound")) and sound or nil
end

local function startSound(state)
	local part = DeployablePlacement.ResolvePart(state.record.model)
	if not part then
		warn("SpeakerService: placed speaker has no BasePart to emit from")
		return
	end

	local template = resolveSoundTemplate()
	if not template then
		warn("SpeakerService: no CompactSpeakerSound under ReplicatedStorage.Sounds.Tool -- lure runs silent")
		return
	end

	local sound = template:Clone()
	-- Looped so a clip shorter than the active window still fills the whole of
	-- it. Nothing stops this explicitly: the Sound is parented INTO the speaker,
	-- so destroying the speaker (expiry or monster contact) takes the audio with
	-- it, and there is no second teardown path to keep in sync.
	sound.Looped = true
	-- Created server-side and parented to a replicated part, so every client
	-- hears it positionally -- not just the player who set it off. Rolloff and
	-- volume stay exactly as authored in Studio.
	sound.Parent = part
	sound:Play()
end

-- Registers a freshly placed speaker as INERT. lifetime is how long it runs
-- once armed, not how long it sits waiting.
function SpeakerService.Track(record, lifetime: number)
	tracked[record.model] = {
		record = record,
		lifetime = lifetime,
		active = false,
		expiresAt = 0,
		lastPublishAt = 0,
		placedAt = os.clock(),
	}
	record.trove:Add(function()
		tracked[record.model] = nil
	end)
end

-- Arms this player's oldest still-inert speaker. Oldest-first because a player
-- with two slots can place two speakers and hold two sets of remotes, and
-- nothing ties one remote to one speaker -- first placed is first fired, which
-- is at least predictable. Returns false when they have nothing left to set
-- off, so the caller can report it rather than silently consuming the remotes.
function SpeakerService.Activate(player: Player): boolean
	local target, targetPlacedAt = nil, math.huge
	for _, state in pairs(tracked) do
		if not state.active and state.record.owner == player and state.placedAt < targetPlacedAt then
			target, targetPlacedAt = state, state.placedAt
		end
	end

	if not target then
		return false
	end

	target.active = true
	target.expiresAt = os.clock() + target.lifetime
	target.lastPublishAt = 0
	startSound(target)
	return true
end

local function sweep()
	local now = os.clock()
	for model, state in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
			continue
		end

		-- Inert: placed but never armed. Costs nothing and waits indefinitely
		-- (match cleanup / owner disconnect still tear it down through
		-- DeployableRegistry, same as any other deployable).
		if not state.active then
			continue
		end

		if now >= state.expiresAt then
			-- Unregister owns the destroy, and the record's Trove is what stops
			-- the publishing in the same operation -- no orphan lure can outlive
			-- the object that was supposed to be emitting it.
			DeployableRegistry.Unregister(model)
			continue
		end

		local speakerPos = positionOf(model)

		local touched = false
		MonsterRegistry.ForEach(function(_monsterModel, instance)
			if touched then
				return
			end
			local rootPart = instance.rootPart
			if rootPart and rootPart.Parent and (rootPart.Position - speakerPos).Magnitude <= CONTACT_RADIUS then
				touched = true
			end
		end)
		if touched then
			DeployableRegistry.Unregister(model)
			continue
		end

		if now - state.lastPublishAt >= PUBLISH_INTERVAL then
			state.lastPublishAt = now
			-- Source = nil is legal -- Perception:Inject uses it the same way
			-- for a stimulus with no player attached.
			StimulusBus.Publish({
				Kind = StimulusKinds.Sound,
				Position = speakerPos,
				Timestamp = now,
				Strength = 1,
				Source = nil,
			})
		end
	end
end

local accumulator = 0
local started = false

function SpeakerService.Start()
	if started then
		return
	end
	started = true

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK_INTERVAL then
			return
		end
		accumulator = 0
		sweep()
	end)
end

return SpeakerService
