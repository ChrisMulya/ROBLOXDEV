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

	-- Reserved, no raiser yet -- same graceful-gap pattern as Sound/Sprint
	-- above. Intended for Perception:Inject (also currently uncalled): a
	-- monster injecting this into ITSELF, never published to the bus and
	-- never subscribed to, meaning "I reached where my target was and they
	-- weren't there, go search." What Chase actually does today on that same
	-- edge is call Targeting:Forget() directly, not raise this kind -- an
	-- earlier version of this comment described the Inject path as live; it
	-- was never wired up.
	LostTarget   = "LostTarget",
}

return StimulusKinds
