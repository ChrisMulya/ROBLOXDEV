local MonsterMovement = {}

-- Kinematic movement: drives the root part's CFrame directly rather than
-- Humanoid:MoveTo. A lone unwelded part has nothing to keep it upright under
-- Humanoid's movement force -- it spins in place instead of walking. This is
-- also simpler to reason about for a boxy placeholder. Swapping to a real
-- rig + Humanoid animation (or PathfindingService) later is a change in this
-- file only -- the (agent, targetPosition, dt) contract doesn't change.
function MonsterMovement.MoveTo(agent, targetPosition: Vector3, dt: number)
	local rootPart = agent.rootPart
	if not rootPart or not rootPart.Parent then return end

	local current = rootPart.Position
	-- XZ-plane only; MVP assumes flat ground (see MONSTERS.md build order step
	-- 4 for ground-following/pathfinding).
	local flatTarget = Vector3.new(targetPosition.X, current.Y, targetPosition.Z)
	local toTarget = flatTarget - current
	local distance = toTarget.Magnitude
	if distance < 0.05 then return end

	local step = math.min(distance, agent.stats.WalkSpeed * dt)
	local newPosition = current + toTarget.Unit * step

	rootPart.CFrame = CFrame.new(newPosition, Vector3.new(flatTarget.X, newPosition.Y, flatTarget.Z))
end

return MonsterMovement
