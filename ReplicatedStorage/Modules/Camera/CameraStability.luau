-- Pure "is the player moving or airborne" test. Thresholds come from
-- CameraStats.<id>.Stability so a future steadier/shakier camera can differ
-- by data alone.

local CameraStability = {}

-- thresholds: { MoveThreshold, VelocityThreshold }
function CameraStability.IsMoving(humanoid: Humanoid, rootPart: BasePart?, thresholds): boolean
	if humanoid.MoveDirection.Magnitude > thresholds.MoveThreshold then
		return true
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return true
	end

	if rootPart and rootPart.AssemblyLinearVelocity.Magnitude > thresholds.VelocityThreshold then
		return true
	end

	return false
end

return CameraStability
