-- Central registry of stimulus kind strings. MonsterCapabilities (which kinds
-- a capability subscribes to) and the publishers (Stimulus/FootstepEmitter,
-- Stimulus/FlashStimulusAdapter) both name these instead of each carrying its
-- own string literal -- a typo'd kind would otherwise silently mean "nobody
-- ever receives this," with no error anywhere to catch it.
--
-- "Vision" is deliberately absent. It is sensed by VisionSensor pulling the
-- world every Perception tick, not by anything publishing to the bus, so it
-- has no place here -- see Components/Perception's Pull/push split.
--
-- Sound and Sprint are declared (CanHear already lists them) but have no
-- publisher yet -- Sensors.ForStimulus resolves them to nil until one exists,
-- same graceful-gap pattern Components.Get uses for planned components.

local StimulusKinds = {
	Footstep     = "Footstep",
	Sound        = "Sound",
	Sprint       = "Sprint",
	CameraFlash  = "CameraFlash",
	Photographed = "Photographed",

	-- Injected by a monster into ITSELF (Perception:Inject), never published to
	-- the bus and never subscribed to -- it is not something that happens in
	-- the world, it is a monster handing itself something to investigate.
	--
	-- Chase raises it on reaching a target's last known position and not
	-- finding them there, so Check runs a real search of the area instead of
	-- the monster standing on the spot for the rest of PursuitDuration.
	-- Deliberately NOT gated by a capability: a monster that can chase can
	-- always investigate where its target went, and requiring CanHear for that
	-- would be nonsense.
	LostTarget   = "LostTarget",
}

return StimulusKinds
