-- Standalone line-of-sight raycast for a placed Motion Sensor. Neither
-- existing LOS implementation is reusable from here:
-- Navigation:HasLineOfSight is a method on a per-monster component instance
-- (no monster owns a sensor), and VisionSensor's isBlocked is file-local.
-- This is a deliberate, scoped copy of VisionSensor's raycast shape --
-- RespectCanCollide = true, both endpoints lifted off the floor -- not a
-- refactor of either: VisionSensor's own header explains why sight LOS and
-- navigation LOS are kept apart, and the same reasoning applies to a third
-- caller.
--
-- Inherited consequence: RespectCanCollide = true means solid, colliding
-- geometry (including a glass window) blocks detection.

local SensorVision = {}

-- Chest height on this rig -- a floor-to-floor ray grazes the ground itself
-- on any slope and reports a wall that isn't there. Same constant Navigation
-- and VisionSensor both use for their own LOS height lift.
local LOS_HEIGHT = 3

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

function SensorVision.HasLineOfSight(fromPos: Vector3, toPos: Vector3, exclude: { Instance }): boolean
	raycastParams.FilterDescendantsInstances = exclude

	local origin = fromPos + Vector3.new(0, LOS_HEIGHT, 0)
	local target = toPos + Vector3.new(0, LOS_HEIGHT, 0)
	local delta = target - origin
	if delta.Magnitude < 1e-3 then
		return true
	end

	local result = workspace:Raycast(origin, delta, raycastParams)
	return result == nil
end

return SensorVision
