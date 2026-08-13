-- Hears a Compact Speaker's lure via the StimulusBus. Structurally a copy of
-- HearingSensor -- PUSH, not pull, no LOS (sound goes through walls) -- but
-- with a much wider default range: a deployed lure is meant to pull a
-- monster from far further away than an ordinary footstep.
--
-- Subscribes to the same StimulusKinds.Sound kind HearingSensor's own
-- CanHear.Stimuli list already declares (it was publisher-less until
-- SpeakerService started using it) -- so any monster with CanHear picks this
-- up with zero MonsterConfig changes, exactly like HearingSensor does for
-- Footstep.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)
local StimulusBus = require(ServerScriptService.GameService.Stimulus.StimulusBus)

local LureSensor = {}
LureSensor.__index = LureSensor
LureSensor.Name = "Lure"
LureSensor.Pull = false

local DEFAULT_RANGE = 140

function LureSensor.new(instance, _sensorConfig)
	local self = setmetatable({
		instance = instance,
		queue = {},
	}, LureSensor)

	instance.trove:Add(StimulusBus.Subscribe(StimulusKinds.Sound, function(stimulus)
		self:_onStimulus(stimulus)
	end))

	return self
end

function LureSensor:GetRange(): number
	local config = self.instance.config
	local perception = config.Perception
	local sensorConfig = perception and perception.Sensors and perception.Sensors[LureSensor.Name]
	return (sensorConfig and sensorConfig.Range) or DEFAULT_RANGE
end

function LureSensor:_onStimulus(stimulus)
	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local distance = (stimulus.Position - rootPart.Position).Magnitude
	if distance > self:GetRange() then
		return
	end

	table.insert(self.queue, stimulus)
end

function LureSensor:Sense(out: { any })
	if #self.queue == 0 then
		return
	end
	for _, stimulus in ipairs(self.queue) do
		table.insert(out, stimulus)
	end
	table.clear(self.queue)
end

function LureSensor:Destroy()
	table.clear(self.queue)
end

return LureSensor
