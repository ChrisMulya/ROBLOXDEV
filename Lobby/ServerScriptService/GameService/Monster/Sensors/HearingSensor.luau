-- Hears footsteps via the StimulusBus. PUSH, not pull: VisionSensor and
-- ProximitySensor scan the world themselves on every Sense(out) call. This
-- sensor does the opposite -- it subscribes once at construction, and a bus
-- handler appends matching, in-range stimuli to a private queue that
-- Sense(out) drains. Perception routes this sensor's output to
-- Stimuli/LastStimulus, not VisibleTargets -- see Components/Perception.
--
-- No line of sight. Sound goes through walls; that is the entire point of a
-- second sense, and CanHear is what a monster declares to get it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)
local StimulusBus = require(ServerScriptService.GameService.Stimulus.StimulusBus)

local HearingSensor = {}
HearingSensor.__index = HearingSensor
HearingSensor.Name = "Hearing"
-- Perception's routing flag: this sensor does not contribute to VisibleTargets.
HearingSensor.Pull = false

-- Deliberately a literal, not a fallback to Stats.DetectRadius the way
-- ProximitySensor and VisionSensor do. Sight range and hearing range are
-- different senses with different envelopes; inheriting DetectRadius would
-- make every monster hear across the map the moment vision gets re-tuned.
--
-- 50 rather than a tighter number because only genuinely fast movement emits
-- a footstep at all now (FootstepEmitter's NOISE_SPEED) -- the gate moved from
-- "how close were you" to "how fast were you", so the radius can afford to be
-- generous without making walking around feel surveilled.
local DEFAULT_RANGE = 50

function HearingSensor.new(instance, _sensorConfig)
	local self = setmetatable({
		instance = instance,
		queue    = {},
	}, HearingSensor)

	-- Trove'd like everything else the instance acquires -- the unsubscribe
	-- function IS the cleanup; no separate bus-side bookkeeping in Destroy.
	instance.trove:Add(StimulusBus.Subscribe(StimulusKinds.Footstep, function(stimulus)
		self:_onStimulus(stimulus)
	end))

	return self
end

-- Read fresh on every stimulus, never cached at construction -- same reason
-- VisionSensor reads its settings fresh: instance.config is replaced wholesale
-- on re-stage and evolution.
function HearingSensor:GetRange(): number
	local config = self.instance.config
	local perception = config.Perception
	local sensorConfig = perception and perception.Sensors and perception.Sensors[HearingSensor.Name]
	return (sensorConfig and sensorConfig.Range) or DEFAULT_RANGE
end

function HearingSensor:_onStimulus(stimulus)
	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local distance = (stimulus.Position - rootPart.Position).Magnitude
	local range = self:GetRange()

	if StimulusBus.Debug then
		warn(("[Hearing] %s at %.1f studs (range %.1f) -> %s")
			:format(tostring(stimulus.Kind), distance, range,
				distance <= range and "HEARD" or "too far"))
	end

	if distance > range then
		return
	end

	table.insert(self.queue, stimulus)
end

function HearingSensor:Sense(out: { any })
	if #self.queue == 0 then
		return
	end

	for _, stimulus in ipairs(self.queue) do
		table.insert(out, stimulus)
	end
	table.clear(self.queue)
end

function HearingSensor:Destroy()
	table.clear(self.queue)
end

return HearingSensor
