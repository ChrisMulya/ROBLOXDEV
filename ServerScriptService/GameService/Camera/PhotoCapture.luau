-- Owns the 5x5 spread raycast used to resolve what a camera shot hit. This
-- is the seam future photo-scoring / MonsterBehavior.OnPhotographed hooks
-- attach to -- callers get back a result table, not a print statement.

local PhotoCapture = {}

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

local function findCapturableFromHit(hitInstance: Instance?)
	local current = hitInstance
	while current and current ~= workspace do
		if current:GetAttribute("CanCapture") then
			return current
		end
		current = current.Parent
	end
	return nil
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

-- Returns a result table { subject, hitPosition, distanceStuds } on a hit,
-- or nil on a miss.
function PhotoCapture.Fire(origin: Vector3, direction: Vector3, range: number, spreadRadius: number, raycastParams: RaycastParams)
	local right, up = buildBasis(direction)

	for _, offset in ipairs(orderedOffsets) do
		local dx, dy = offset[1], offset[2]
		local spreadDirection = (direction + right * dx * spreadRadius + up * dy * spreadRadius).Unit

		local result = workspace:Raycast(origin, spreadDirection * range, raycastParams)
		if result then
			local capturable = findCapturableFromHit(result.Instance)
			if capturable then
				return {
					subject = capturable,
					hitPosition = result.Position,
					distanceStuds = (result.Position - origin).Magnitude,
				}
			end
		end
	end

	return nil
end

return PhotoCapture
