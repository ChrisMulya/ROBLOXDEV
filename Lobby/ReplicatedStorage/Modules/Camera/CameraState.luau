-- Pure state cell for the camera session: InCamera/Stable flags and their
-- listeners. Owns no Instances -- Lighting effects live in CameraEffects,
-- GUI/CameraMode/mouse ownership lives in CameraSession. Mutated only by
-- CameraSession; everything else should only read.

local CameraState = {}

local inCamera = false
local stable = true
local movementSettings = nil

local listeners = {}
local stableListeners = {}

local function fireListeners(value)
	for _, callback in ipairs(listeners) do
		task.spawn(callback, value)
	end
end

local function fireStableListeners(value)
	for _, callback in ipairs(stableListeners) do
		task.spawn(callback, value)
	end
end

function CameraState.Get(): boolean
	return inCamera
end

-- Intended for CameraSession only.
function CameraState.SetInCamera(value: boolean)
	if inCamera == value then return end
	inCamera = value
	if not inCamera then
		stable = true
	end
	fireListeners(inCamera)
end

function CameraState.GetStable(): boolean
	return stable
end

function CameraState.SetStable(value: boolean)
	if not inCamera then return end
	if stable == value then return end
	stable = value
	fireStableListeners(value)
end

-- Returns a disconnect function.
function CameraState.OnChanged(callback): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Returns a disconnect function.
function CameraState.OnStableChanged(callback): () -> ()
	table.insert(stableListeners, callback)
	return function()
		local index = table.find(stableListeners, callback)
		if index then
			table.remove(stableListeners, index)
		end
	end
end

-- Intended for CameraSession only.
function CameraState.SetMovementSettings(settings)
	movementSettings = settings
end

function CameraState.GetWalkSpeedMultiplier(): number
	if not inCamera or not movementSettings then
		return 1
	end
	return movementSettings.INCAMERA_WALK_SPEED_MULTIPLIER
end

return CameraState
