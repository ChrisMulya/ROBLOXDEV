-- Client-only state cell for "the player wants to sprint". Pure state, owns no
-- Instances and fires no remotes -- same shape as CameraState.
--
-- Exists because sprint now has more than one input device: Shift on desktop
-- and the mobile sprint button / thumbstick stretch on touch. Both write here,
-- and PlayerMovementController is the single subscriber that applies the
-- stamina gate, fires SprintRequest, and drives top speed and FOV. Without
-- this, each new input device would need its own copy of that sequence.
--
-- `source` is carried through purely for debugging (which device asked); no
-- behavior depends on it.

local SprintIntent = {}

local wanted = false
local lastSource = "None"

local changedEvent = Instance.new("BindableEvent")
-- Fires (wanted: boolean, source: string).
SprintIntent.Changed = changedEvent.Event

function SprintIntent.Get(): boolean
	return wanted
end

function SprintIntent.GetSource(): string
	return lastSource
end

function SprintIntent.Set(value: boolean, source: string?)
	lastSource = source or "Unknown"
	if wanted == value then
		return
	end
	wanted = value
	changedEvent:Fire(wanted, lastSource)
end

return SprintIntent
