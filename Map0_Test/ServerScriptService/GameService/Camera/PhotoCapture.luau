-- Owns the raycast-based detection used to resolve what a camera shot hit.
-- This is the seam future photo-scoring / MonsterBehavior.OnPhotographed
-- hooks attach to -- callers get back a result table, not a print statement.
--
-- Detection is angular candidate selection -> geometry proof -> line-of-sight
-- confirm (the plan this shipped against, plans/photo-capture-detection.md,
-- no longer exists on disk -- this file and its own comments are the only
-- remaining source). The aim cone half-angle is
-- byte-identical to the old 5x5 grid's outer ring (atan(2 * spreadRadius)) --
-- every accuracy gain comes from removing false negatives INSIDE that cone,
-- never from widening it. USE_CONE_DETECTION gates the new path so the
-- proven 5x5 path stays reachable as an instant rollback during migration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CaptureTargets = require(ReplicatedStorage.Modules.Reward.CaptureTargets)
local CaptureRegistry = require(ServerScriptService.GameService.Reward.CaptureRegistry)

local PhotoCapture = {}

local USE_CONE_DETECTION = true

-- Capped so a shot near a cluster of live targets still costs a bounded
-- number of raycasts (worst case: MAX_CANDIDATES * (2 phase-2 probes + 3 LOS
-- samples)).
local MAX_CANDIDATES = 4
local LOS_INSET_STUDS = 0.5
local EPSILON = 0.05

--------------------------------------------------------------------------
-- Legacy 5x5 spread raycast (kept for rollback -- see USE_CONE_DETECTION)
--------------------------------------------------------------------------

local SPREAD_OFFSETS = {-2, -1, 0, 1, 2}

-- Precomputed once at module load (previously rebuilt on every single shot)
-- and genuinely ordered center-out by radius, so a near-center ray always
-- wins over a far-corner one.
local orderedOffsets = {}
do
	for _, dx in ipairs(SPREAD_OFFSETS) do
		for _, dy in ipairs(SPREAD_OFFSETS) do
			table.insert(orderedOffsets, { dx, dy })
		end
	end
	table.sort(orderedOffsets, function(a, b)
		return (a[1] * a[1] + a[2] * a[2]) < (b[1] * b[1] + b[2] * b[2])
	end)
end

local function buildBasis(direction: Vector3)
	local worldUp = Vector3.new(0, 1, 0)
	if math.abs(direction:Dot(worldUp)) > 0.999 then
		worldUp = Vector3.new(1, 0, 0)
	end

	local right = direction:Cross(worldUp).Unit
	local up = right:Cross(direction).Unit
	return right, up
end

local function fireLegacySpread(origin: Vector3, direction: Vector3, range: number, spreadRadius: number, raycastParams: RaycastParams)
	local right, up = buildBasis(direction)

	for _, offset in ipairs(orderedOffsets) do
		local dx, dy = offset[1], offset[2]
		local spreadDirection = (direction + right * dx * spreadRadius + up * dy * spreadRadius).Unit

		local result = workspace:Raycast(origin, spreadDirection * range, raycastParams)
		if result then
			local capturable, targetType = CaptureTargets.Resolve(result.Instance)
			if capturable then
				return {
					subject = capturable,
					targetType = targetType,
					hitPosition = result.Position,
					distanceStuds = (result.Position - origin).Magnitude,
				}
			end
		end
	end

	return nil
end

--------------------------------------------------------------------------
-- Cone-based detection: angular candidate -> geometry proof -> LOS confirm
--------------------------------------------------------------------------

-- Bounding sphere in world space. Model uses GetBoundingBox (accounts for
-- every descendant, not just PrimaryPart); BasePart uses its own CFrame/Size.
-- Radius is the box's half-diagonal, a safe (slightly generous) sphere around
-- the box -- this only feeds candidate SELECTION, never the geometry proof
-- that actually awards a hit.
local function getBoundingSphere(instance: Instance): (Vector3, number)
	if instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		return cframe.Position, size.Magnitude / 2
	elseif instance:IsA("BasePart") then
		return instance.Position, instance.Size.Magnitude / 2
	end
	return instance:GetPivot().Position, 0
end

-- Smallest angle (radians) between `direction` and any point on the target's
-- bounding sphere, clamped to >= 0. A target whose sphere straddles the aim
-- ray (angle < angularRadius) returns 0 -- it's dead-on.
local function angularOffsetToSphere(origin: Vector3, direction: Vector3, center: Vector3, radius: number): (number, number)
	local toTarget = center - origin
	local distance = toTarget.Magnitude
	if distance <= EPSILON then
		return 0, distance
	end

	local cosAngle = math.clamp(direction:Dot(toTarget / distance), -1, 1)
	local angle = math.acos(cosAngle)
	local angularRadius = if radius < distance then math.asin(math.clamp(radius / distance, 0, 1)) else math.pi / 2

	return math.max(0, angle - angularRadius), distance
end

-- Broad phase: every live capturable instance whose bounding sphere
-- intersects the aim cone, nearest-angle-first (ties broken by distance).
-- Pure vector math, zero raycasts.
local function collectCandidates(origin: Vector3, direction: Vector3, range: number, coneHalfAngle: number)
	local candidates = {}

	for _, instance in ipairs(CaptureRegistry.All()) do
		if not instance:IsDescendantOf(workspace) then
			continue
		end

		local center, radius = getBoundingSphere(instance)
		local angularOffset, distance = angularOffsetToSphere(origin, direction, center, radius)
		if distance - radius <= range and angularOffset <= coneHalfAngle then
			table.insert(candidates, {
				instance = instance,
				center = center,
				angularOffset = angularOffset,
				distance = distance,
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.angularOffset ~= b.angularOffset then
			return a.angularOffset < b.angularOffset
		end
		return a.distance < b.distance
	end)

	return candidates
end

-- Rotates `toward` no further than `maxAngle` away from `direction` (both
-- unit vectors). A large candidate's bounding sphere can satisfy the
-- broad-phase cone test (angularOffsetToSphere) via its EDGE while its
-- CENTER sits well outside the cone -- probing raw toward-center in that
-- case would fire a ray no player aim produced, which is exactly the
-- "invisible hitbox" the aim cone exists to prevent. Clamping guarantees
-- every phase-2 probe stays inside the same cone the broad phase used.
local function clampToCone(direction: Vector3, toward: Vector3, maxAngle: number): Vector3
	local dot = math.clamp(direction:Dot(toward), -1, 1)
	local angle = math.acos(dot)
	if angle <= maxAngle then
		return toward
	end

	local axis = direction:Cross(toward)
	if axis.Magnitude <= EPSILON then
		return direction
	end

	return (CFrame.fromAxisAngle(axis.Unit, maxAngle) * direction).Unit
end

-- Narrow phase: proves real geometry belonging to this exact candidate lies
-- inside the cone. Include-filtered so clutter (foliage, glass, other
-- players) cannot eat the ray -- this is what a bounding-volume check alone
-- can't do, and what the old 5x5's first-hit rays never guaranteed. Both
-- probe directions are clamped inside the same cone the broad phase used, so
-- a large or off-center candidate can only be proven by geometry that is
-- actually within the player's aim tolerance.
local function proveGeometry(origin: Vector3, direction: Vector3, range: number, candidate, coneHalfAngle: number)
	local includeParams = RaycastParams.new()
	includeParams.FilterType = Enum.RaycastFilterType.Include
	includeParams.FilterDescendantsInstances = { candidate.instance }

	local toCenter = candidate.center - origin
	local probeDirections = { direction }
	if toCenter.Magnitude > EPSILON then
		table.insert(probeDirections, clampToCone(direction, toCenter.Unit, coneHalfAngle))
	end

	for _, probeDirection in ipairs(probeDirections) do
		local result = workspace:Raycast(origin, probeDirection * range, includeParams)
		if result then
			return result
		end
	end

	return nil
end

-- LOS confirm: from origin toward one or more sample points on the proven
-- hit, cast a normal Exclude ray that DOES respect collision (unlike the
-- narrow-phase probe) and ignores water. A hit strictly before the sample
-- point means something solid is in the way -- occluded. Partially occluded
-- targets pass as soon as one sample point is clear, matching what the
-- player actually sees through the viewfinder.
local function hasLineOfSight(origin: Vector3, point: Vector3, losParams: RaycastParams): boolean
	local toPoint = point - origin
	local distance = toPoint.Magnitude
	if distance <= EPSILON then
		return true
	end

	local result = workspace:Raycast(origin, toPoint, losParams)
	if not result then
		return true
	end

	return (result.Position - origin).Magnitude >= distance - EPSILON
end

local function fireConeDetection(origin: Vector3, direction: Vector3, range: number, spreadRadius: number, raycastParams: RaycastParams)
	-- Same outer ring the legacy grid used to sample -- the cone is not
	-- widened, only sampled differently.
	local coneHalfAngle = math.atan(2 * spreadRadius)

	local candidates = collectCandidates(origin, direction, range, coneHalfAngle)

	local baseExclusions = {}
	if raycastParams.FilterType == Enum.RaycastFilterType.Exclude then
		for _, instance in ipairs(raycastParams.FilterDescendantsInstances) do
			table.insert(baseExclusions, instance)
		end
	end

	for index = 1, math.min(MAX_CANDIDATES, #candidates) do
		local candidate = candidates[index]
		local hit = proveGeometry(origin, direction, range, candidate, coneHalfAngle)
		if hit then
			local losExclusions = table.clone(baseExclusions)
			table.insert(losExclusions, candidate.instance)

			local losParams = RaycastParams.new()
			losParams.FilterType = Enum.RaycastFilterType.Exclude
			losParams.FilterDescendantsInstances = losExclusions
			losParams.RespectCanCollide = true
			losParams.IgnoreWater = true

			local hitOffset = hit.Position - origin
			local inset = if hitOffset.Magnitude > LOS_INSET_STUDS
				then hit.Position - hitOffset.Unit * LOS_INSET_STUDS
				else hit.Position

			local samplePoints = { hit.Position, candidate.center, inset }
			for _, point in ipairs(samplePoints) do
				if hasLineOfSight(origin, point, losParams) then
					local capturable, targetType = CaptureTargets.Resolve(hit.Instance)
					if capturable then
						return {
							subject = capturable,
							targetType = targetType,
							hitPosition = hit.Position,
							distanceStuds = (hit.Position - origin).Magnitude,
						}
					end
					break
				end
			end
		end
	end

	return nil
end

--------------------------------------------------------------------------

-- Returns a result table { subject, targetType, hitPosition, distanceStuds }
-- on a hit, or nil on a miss. targetType comes from CaptureTargets.Resolve --
-- PhotoCapture doesn't know or care what a Monster or Objective IS, only
-- that the walk found a registered attribute.
function PhotoCapture.Fire(origin: Vector3, direction: Vector3, range: number, spreadRadius: number, raycastParams: RaycastParams)
	if USE_CONE_DETECTION then
		return fireConeDetection(origin, direction, range, spreadRadius, raycastParams)
	end
	return fireLegacySpread(origin, direction, range, spreadRadius, raycastParams)
end

return PhotoCapture
