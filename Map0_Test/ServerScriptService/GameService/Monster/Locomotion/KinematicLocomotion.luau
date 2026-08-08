-- Direct CFrame stepping on an ANCHORED root part. Extracted verbatim from
-- MonsterMovement.MoveTo.
--
-- A lone unwelded part has nothing to keep it upright under Humanoid movement
-- force -- it spins in place instead of walking -- so the placeholder monster
-- is anchored and moved by hand. XZ-plane only: it assumes flat ground and
-- will walk into geometry.
--
-- HumanoidPathLocomotion (step 6) is the opposite in both respects: unanchored,
-- Humanoid-driven, navmesh-aware. Both satisfy the same interface, so which one
-- a monster uses is config.Navigation.Locomotion and nothing else changes.

local KinematicLocomotion = {}
KinematicLocomotion.__index = KinematicLocomotion
KinematicLocomotion.Name = "Kinematic"

-- Below this the monster is "there" -- prevents jitter from stepping back and
-- forth across the target by sub-stud amounts.
local ARRIVE_EPSILON = 0.05

function KinematicLocomotion.new(instance, navConfig)
	return setmetatable({
		instance  = instance,
		navConfig = navConfig or {},
	}, KinematicLocomotion)
end

-- Returns true once the target is reached. speed is supplied by Navigation,
-- which resolves it per active state; the stat is only a fallback for a caller
-- that omits it.
function KinematicLocomotion:MoveTo(targetPosition: Vector3, dt: number, speed: number?): boolean
	local rootPart = self.instance.rootPart
	if not rootPart or not rootPart.Parent then
		return false
	end

	local walkSpeed = speed or self.instance.config.Stats.WalkSpeed
	if not walkSpeed then
		return false
	end

	local current = rootPart.Position
	local flatTarget = Vector3.new(targetPosition.X, current.Y, targetPosition.Z)
	local toTarget = flatTarget - current
	local distance = toTarget.Magnitude
	if distance < ARRIVE_EPSILON then
		return true
	end

	local step = math.min(distance, walkSpeed * dt)
	local newPosition = current + toTarget.Unit * step

	rootPart.CFrame = CFrame.new(newPosition, Vector3.new(flatTarget.X, newPosition.Y, flatTarget.Z))
	return false
end

function KinematicLocomotion:Stop() end

function KinematicLocomotion:Destroy() end

return KinematicLocomotion
