-- Humanoid + PathfindingService. The real walker.
--
-- The load-bearing constraint: PathfindingService:ComputeAsync YIELDS. Calling
-- it inline would stall the scheduler tick and therefore every other monster.
-- So MoveTo never computes; it consumes the most recently completed path and
-- kicks off a recompute in a task.spawn when the target has moved enough.
--
-- Steering uses Humanoid:Move, NOT Humanoid:MoveTo. This is the difference
-- between gliding and stuttering, and it is not a style preference:
--
--   MoveTo(position) has ARRIVAL SEMANTICS. The humanoid decelerates as it
--   approaches the position and stops on reaching it. Pointed at a navmesh
--   waypoint -- and they sit roughly 4 studs apart -- that means braking into
--   every single one, which reads as a glide/stop/glide shuffle all the way
--   down the path. It also carries an internal ~8s timeout that halts the
--   humanoid outright on a long leg.
--
--   Move(unitDirection) has no arrival, no deceleration and no timeout. It
--   sets MoveDirection and the humanoid runs flat out until told otherwise.
--   Arrival becomes OUR job, which we already do against the goal anyway.
--
-- Three rules learned the hard way, each of which produced a visible stutter:
--
--   * ALWAYS issue a movement command every tick. Returning without one lets
--     MoveDirection go stale or zero.
--   * Arrival is measured against the GOAL, never against running out of
--     waypoints. Exhausting the path means "the path was short", not "we're
--     there".
--   * Waypoint advancement must tolerate OVERSHOOT. At 22 studs/sec and a
--     0.1s tick the monster covers 2.2 studs per tick, so a fixed 2-stud
--     "reached" radius gets skipped straight past -- and then the monster
--     steers BACKWARD to a waypoint it already passed. See _advanceWaypoints.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local HumanoidPathLocomotion = {}
HumanoidPathLocomotion.__index = HumanoidPathLocomotion
HumanoidPathLocomotion.Name = "HumanoidPath"

-- Recompute when the goal moves more than this from the goal we pathed to.
local REPATH_DISTANCE = 8
-- Floor on recompute frequency, per monster. Pathfinding is the most expensive
-- thing a monster does; a chase that repaths every tick will not scale.
local REPATH_COOLDOWN = 0.4
-- Floor on how close counts as reaching a WAYPOINT. Must stay well under the
-- navmesh's own waypoint spacing (~4 studs) or the monster treats every fresh
-- waypoint as already reached and burns the whole path in one tick. The
-- EFFECTIVE radius scales with speed at runtime -- see _advanceWaypoints.
local WAYPOINT_EPSILON = 2
-- How close counts as reaching the GOAL. Separate from the above on purpose.
local ARRIVE_DISTANCE = 3

-- Horizontal only: the monster's root and the player's root sit at different
-- heights, and on stairs the Y difference would otherwise read as distance.
local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function HumanoidPathLocomotion.new(instance, navConfig)
	navConfig = navConfig or {}

	return setmetatable({
		instance      = instance,
		agentParams   = navConfig.AgentParams or {},
		waypoints     = nil,
		waypointIndex = 1,
		pathedTo      = nil,
		lastComputeAt = 0,
		computing     = false,
		lastStatus    = nil,
	}, HumanoidPathLocomotion)
end

function HumanoidPathLocomotion:_computeAsync(goal: Vector3)
	if self.computing then
		return
	end
	self.computing = true
	self.lastComputeAt = os.clock()

	task.spawn(function()
		local rootPart = self.instance.rootPart
		if not rootPart or not rootPart.Parent then
			self.computing = false
			return
		end

		local origin = rootPart.Position
		local path = PathfindingService:CreatePath(self.agentParams)
		local ok = pcall(function()
			path:ComputeAsync(origin, goal)
		end)

		-- The instance may have been destroyed while we yielded.
		if self.instance.destroyed then
			self.computing = false
			return
		end

		local status = ok and path.Status or nil
		self.lastStatus = status

		if status == Enum.PathStatus.Success then
			self.waypoints = path:GetWaypoints()
			-- Waypoint 1 is where we already are.
			self.waypointIndex = 2
			self.pathedTo = goal
		else
			-- Unreachable for these AgentParams. Drop the stale path so MoveTo
			-- falls back to walking straight at the goal, and leave pathedTo
			-- nil so the next tick retries rather than assuming this path holds.
			self.waypoints = nil
			self.pathedTo = nil
			self.instance.bus:Fire("PathBlocked", {})

			if MonsterConstants.DebugPathfinding then
				warn(("[Path] %s: %s over %.0f studs -- falling back to straight-line, which will snag on geometry")
					:format(self.instance.monsterId, tostring(status), flatDistance(origin, goal)))
			end
		end

		self.computing = false
	end)
end

-- speed is supplied by Navigation, which resolves it per active state; this
-- module deliberately does not read Stats.WalkSpeed itself. Falls back to the
-- stat only if a caller omits it.
function HumanoidPathLocomotion:MoveTo(targetPosition: Vector3, dt: number, speed: number?): boolean
	local rootPart = self.instance.rootPart
	local humanoid = self.instance.humanoid
	if not rootPart or not rootPart.Parent or not humanoid then
		return false
	end

	local walkSpeed = speed or self.instance.config.Stats.WalkSpeed
	if walkSpeed and humanoid.WalkSpeed ~= walkSpeed then
		humanoid.WalkSpeed = walkSpeed
	end

	local position = rootPart.Position

	-- Arrival is against the goal, never against waypoint exhaustion.
	--
	-- Zeroing MoveDirection here is REQUIRED, and was the bug that came with
	-- switching from MoveTo to Move. MoveTo had arrival semantics -- reaching
	-- the target stopped the humanoid by itself -- so returning early was
	-- harmless. Move has none: MoveDirection persists from the previous tick,
	-- so an early return leaves the monster gliding straight through the point
	-- it just arrived at, forever, until some state happens to call Stop().
	--
	-- Every "arrive then pause" behaviour hits this: Wander's pause between
	-- points, Check's hold and its pause at each search point, Reset sitting on
	-- its spawn anchor, Chase idling on a stale LastKnownPos. All of them stop
	-- calling MoveTo (or call it and get this early return) for a stretch of
	-- seconds, which is exactly when the stale direction runs away with them.
	if flatDistance(position, targetPosition) <= ARRIVE_DISTANCE then
		humanoid:Move(Vector3.zero, false)
		return true
	end

	local needsPath = self.pathedTo == nil
		or flatDistance(targetPosition, self.pathedTo) > REPATH_DISTANCE
	if needsPath and os.clock() - self.lastComputeAt >= REPATH_COOLDOWN then
		self:_computeAsync(targetPosition)
	end

	self:_advanceWaypoints(position, humanoid, walkSpeed, dt)

	-- Unconditional: every tick ends with a movement command. Straight-lining
	-- when there is no path is worse than pathing but keeps it moving; the
	-- DebugPathfinding warn above says when that is happening.
	local waypoints = self.waypoints
	local steerTarget = targetPosition
	if waypoints and self.waypointIndex <= #waypoints then
		steerTarget = waypoints[self.waypointIndex].Position
	end

	-- Flattened: feeding a Y component into Move fights gravity and the
	-- humanoid's own state machine on slopes and stairs.
	local delta = Vector3.new(steerTarget.X - position.X, 0, steerTarget.Z - position.Z)
	if delta.Magnitude > 0.001 then
		humanoid:Move(delta.Unit, false)
	end

	return false
end

-- Consume every waypoint already behind us, not just one per tick: a fresh
-- path can start behind the monster, and advancing one at a time would walk it
-- backwards to catch up.
function HumanoidPathLocomotion:_advanceWaypoints(position: Vector3, humanoid: Humanoid, walkSpeed: number?, dt: number)
	local waypoints = self.waypoints
	if not waypoints then
		return
	end

	-- Scaled to how far this monster actually travels in one tick, so a faster
	-- monster does not skip past waypoints a fixed radius would have caught.
	-- 1.5x is margin for a long frame.
	local reachRadius = math.max(WAYPOINT_EPSILON, (walkSpeed or 0) * dt * 1.5)

	while self.waypointIndex <= #waypoints do
		local waypoint = waypoints[self.waypointIndex]
		local distance = flatDistance(position, waypoint.Position)
		local reached = distance <= reachRadius

		-- Overshoot guard. Even with the scaled radius, a long frame or a
		-- corner can leave the monster past a waypoint but outside its radius;
		-- being closer to the NEXT one is proof this one is behind us. Without
		-- this the monster turns around to touch a waypoint it already passed,
		-- which is the worst-looking stutter of the lot.
		if not reached then
			local nextWaypoint = waypoints[self.waypointIndex + 1]
			reached = nextWaypoint ~= nil
				and flatDistance(position, nextWaypoint.Position) < distance
		end

		if not reached then
			break
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		self.waypointIndex += 1
	end
end

-- Zeroing MoveDirection is MANDATORY, not tidiness. Move has no arrival to
-- stop it: a direction set and never cleared glides the monster off forever,
-- so every state that stops moving must reach this.
function HumanoidPathLocomotion:Stop()
	local humanoid = self.instance.humanoid
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end
	self.waypoints = nil
	self.pathedTo = nil
end

function HumanoidPathLocomotion:Destroy()
	-- Same reason as Stop: a monster whose brain is torn down but whose model
	-- outlives it by a frame should not keep walking.
	local humanoid = self.instance.humanoid
	if humanoid and humanoid.Parent then
		humanoid:Move(Vector3.zero, false)
	end
	self.waypoints = nil
	self.pathedTo = nil
end

return HumanoidPathLocomotion
