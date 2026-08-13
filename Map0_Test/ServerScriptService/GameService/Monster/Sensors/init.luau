-- Stimulus kind -> sensor module.
--
-- A capability's Stimuli list is what selects sensors (CanSee -> "Vision" ->
-- VisionSensor), so a monster subscribes to exactly the senses it declares and
-- constructs nothing for the rest. A deaf monster has no HearingSensor object,
-- not a HearingSensor that early-returns.
--
-- "Vision" resolves to a PULL sensor (VisionSensor.Pull is unset -> Perception
-- treats absence as pull); "Footstep" and "CameraFlash" resolve to PUSH
-- sensors (HearingSensor.Pull / FlashSensor.Pull == false) that subscribe to
-- the StimulusBus instead of scanning. See Components/Perception for the
-- split.
--
-- "Photographed" still resolves to nil here on purpose: CanFeelPhoto already
-- declares it (see StimulusKinds), but no publisher exists yet. Perception
-- skips a nil resolve the same way Components.Get skips a planned-but-unbuilt
-- component.
--
-- "Sound" now resolves to LureSensor -- SpeakerService (a placed Compact
-- Speaker) is its first publisher. CanHear already declared Sound in its
-- Stimuli list from the start, so no MonsterCapabilities change was needed
-- to wire this up.

local Sensors = {}

local byStimulus = {
	Vision      = require(script.VisionSensor),
	Footstep    = require(script.HearingSensor),
	CameraFlash = require(script.FlashSensor),
	Sound       = require(script.LureSensor),
}

-- Not stimulus-selected: Perception's fallback when nothing else resolves.
Sensors.Proximity = require(script.ProximitySensor)

function Sensors.ForStimulus(kind: string)
	return byStimulus[kind]
end

return Sensors
