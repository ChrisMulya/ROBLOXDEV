-- Gathers world stimuli. Draws no conclusions.
--
-- Perception owns a set of Sensors, selected by the monster's capabilities:
-- CanSee contributes the "Vision" stimulus, which resolves to VisionSensor.
-- It writes what it saw to the Blackboard and announces it on the Bus; whether
-- any of that is worth chasing is Targeting's and the Brain's problem.
--
-- Two sensor SHAPES share one interface. PULL sensors (Vision, Proximity)
-- scan the world themselves on every Sense(out) call. PUSH sensors (Hearing,
-- Flash) subscribed to the StimulusBus at construction and just drain an
-- internal queue when Sense(out) is called. Both implement the same
-- `:Sense(out)` signature -- a sensor's `.Pull` field (default true; false for
-- a push sensor) is how Perception tells them apart, because they feed
-- different Blackboard keys and must not be mixed into one list:
-- VisibleTargets is "who I can see right now"; Stimuli/LastStimulus is
-- "something happened over there." Writing a heard footstep into
-- VisibleTargets would promote it to a sighting and let Chase pursue a
-- position nobody actually saw.

local Perception = {}
Perception.__index = Perception

Perception.Name = "Perception"
Perception.Writes = { "VisibleTargets", "Stimuli", "LastStimulus" }
Perception.TickRate = 0.1

-- Bounds blackboard.Stimuli growth regardless of a monster's own
-- Aggression.Modifiers.Stimulus.MemorySeconds tuning, which Perception has no
-- reason to know about. Comfortably above any sane MemorySeconds default (8).
local STIMULUS_MEMORY_CEILING = 20

local Sensors = require(script.Parent.Parent.Sensors)

local function trimStimuli(list: { any }, now: number): { any }
	local kept = {}
	for _, stimulus in ipairs(list) do
		if now - stimulus.Timestamp <= STIMULUS_MEMORY_CEILING then
			table.insert(kept, stimulus)
		end
	end
	return kept
end

function Perception.new(instance, config)
	local self = setmetatable({
		instance = instance,
		-- Pull sensors: ticked every Perception.Tick.
		sensors     = {},
		-- Push sensors: subscribed once here, drained every Perception.Tick.
		pushSensors = {},
	}, Perception)

	local sensorConfigs = (config.Perception and config.Perception.Sensors) or {}

	-- Capability-driven: config.Stimuli is the union of every declared
	-- capability's Stimuli list. A monster subscribes to exactly what it
	-- declared and builds nothing for the rest.
	for kind in pairs(config.Stimuli or {}) do
		local sensorModule = Sensors.ForStimulus(kind)
		if sensorModule then
			local sensor = sensorModule.new(instance, sensorConfigs[sensorModule.Name])
			if sensorModule.Pull == false then
				table.insert(self.pushSensors, sensor)
			else
				table.insert(self.sensors, sensor)
			end
		end
	end

	-- "Senses nothing" degrades to "senses contact" rather than to a monster
	-- that can never react to anything.
	if #self.sensors == 0 and #self.pushSensors == 0 then
		table.insert(self.sensors, Sensors.Proximity.new(instance, sensorConfigs.Proximity))
	end

	instance.blackboard.VisibleTargets = {}

	return self
end

function Perception:Start() end

function Perception:Tick(_dt: number)
	local blackboard = self.instance.blackboard

	local visible = {}
	for _, sensor in ipairs(self.sensors) do
		sensor:Sense(visible)
	end

	-- Nearest first. Targeting takes results[1] as the obvious candidate, so
	-- sorting here means every consumer agrees on what "nearest" is.
	table.sort(visible, function(a, b)
		return a.distance < b.distance
	end)

	blackboard.VisibleTargets = visible

	if #visible > 0 then
		self.instance.bus:Fire("Perceived", { Count = #visible })
	end

	local stimuli = {}
	for _, sensor in ipairs(self.pushSensors) do
		sensor:Sense(stimuli)
	end

	self:_absorb(stimuli)
end

-- The single path by which anything reaches Blackboard.Stimuli/LastStimulus,
-- whether it came from a sensor or from Inject. Newest wins (blueprint D4): a
-- flash mid-investigation of a footstep retargets rather than queuing, and a
-- fresher footstep from a second player overrides an older one from the first.
function Perception:_absorb(stimuli: { any })
	if #stimuli == 0 then
		return
	end

	local blackboard = self.instance.blackboard
	local now = os.clock()
	local combined = trimStimuli(blackboard.Stimuli or {}, now)
	local newest = blackboard.LastStimulus

	for _, stimulus in ipairs(stimuli) do
		table.insert(combined, stimulus)
		if not newest or stimulus.Timestamp >= newest.Timestamp then
			newest = stimulus
		end
	end

	blackboard.Stimuli = combined
	blackboard.LastStimulus = newest
	-- Wakes the Brain: "StimulusReceived" is in Brain.WAKE_EVENTS, so Check
	-- becomes eligible on the next Brain tick rather than waiting out its poll.
	self.instance.bus:Fire("StimulusReceived", { Kind = newest.Kind })
end

-- Hand this monster something to investigate that no sensor produced.
--
-- Perception is the sole writer of Stimuli/LastStimulus, so callers go through
-- here instead of touching the keys -- the same ownership rule Targeting
-- enforces for Target via Request/Clear/Forget. Reserved, zero callers today:
-- "they were here and now they are not" is instead handled by
-- Targeting:Forget (Chase does NOT call this, despite an earlier version of
-- this comment saying it did). The intended future caller is the blueprint's
-- ScriptedSensor (director-injected set pieces), which does not exist yet
-- either.
function Perception:Inject(kind: string, position: Vector3, strength: number?)
	self:_absorb({ {
		Kind      = kind,
		Position  = position,
		Timestamp = os.clock(),
		Strength  = strength or 1,
		Source    = nil,
	} })
end

function Perception:Destroy()
	for _, sensor in ipairs(self.sensors) do
		sensor:Destroy()
	end
	table.clear(self.sensors)

	for _, sensor in ipairs(self.pushSensors) do
		sensor:Destroy()
	end
	table.clear(self.pushSensors)
end

return Perception
