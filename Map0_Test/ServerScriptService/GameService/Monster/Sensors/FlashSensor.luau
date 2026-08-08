-- Sees camera flashes via the StimulusBus. Same push shape as HearingSensor;
-- see that file's header for why push sensors subscribe once instead of
-- scanning every tick, and Components/Perception for how the two routes
-- differ from VisibleTargets.
--
-- Deliberately does NOT apply VisionSensor's FOV cone or line-of-sight raycast.
-- A flash is a light going off in a dark room -- omnidirectional and unblocked
-- by a doorway is the correct model, not a bug to fix later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)
local StimulusBus = require(ServerScriptService.GameService.Stimulus.StimulusBus)

local FlashSensor = {}
FlashSensor.__index = FlashSensor
FlashSensor.Name = "Flash"
FlashSensor.Pull = false

-- 120 -- deliberately well beyond both hearing (50) and Monster1's sight
-- (DetectRadius 80). A flash is the loudest thing a player can do, and it is
-- the one they choose to do, so it reaching further than anything else is what
-- makes photographing a real decision rather than a free action.
local DEFAULT_RANGE = 120

function FlashSensor.new(instance, _sensorConfig)
	local self = setmetatable({
		instance = instance,
		queue    = {},
	}, FlashSensor)

	instance.trove:Add(StimulusBus.Subscribe(StimulusKinds.CameraFlash, function(stimulus)
		self:_onStimulus(stimulus)
	end))

	return self
end

function FlashSensor:GetRange(): number
	local config = self.instance.config
	local perception = config.Perception
	local sensorConfig = perception and perception.Sensors and perception.Sensors[FlashSensor.Name]
	return (sensorConfig and sensorConfig.Range) or DEFAULT_RANGE
end

function FlashSensor:_onStimulus(stimulus)
	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return
	end

	local distance = (stimulus.Position - rootPart.Position).Magnitude
	local range = self:GetRange()

	if StimulusBus.Debug then
		warn(("[Flash] %s at %.1f studs (range %.1f) -> %s")
			:format(tostring(stimulus.Kind), distance, range,
				distance <= range and "SEEN" or "too far"))
	end

	if distance > range then
		return
	end

	table.insert(self.queue, stimulus)
end

function FlashSensor:Sense(out: { any })
	if #self.queue == 0 then
		return
	end

	for _, stimulus in ipairs(self.queue) do
		table.insert(out, stimulus)
	end
	table.clear(self.queue)
end

function FlashSensor:Destroy()
	table.clear(self.queue)
end

return FlashSensor
