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

-- Ground probe envelope for the direct-route check. Same values and the same
-- reasoning as Navigation:ResolveReachable -- up first so a sample sunk
-- slightly into the floor still finds it, then down far enough to catch a step
-- or ramp but not so far that a sample over a stairwell finds the storey below.
local GROUND_PROBE_UP = 6
local GROUND_PROBE_DOWN = 24

-- Horizontal only: the monster's root and the player's root sit at different
-- heights, and on stairs the Y difference would otherwise read as distance.
local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function pathLength(waypoints): number
	local total = 0
	for i = 2, #waypoints do
		total += (waypoints[i].Position - waypoints[i - 1].Position).Magnitude
	end
	return total
end

local function hasJumpWaypoint(waypoints): boolean
	for _, waypoint in ipairs(waypoints) do
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			return true
		end
	end
	return false
end

function HumanoidPathLocomotion.new(instance, navConfig)
	navConfig = navConfig or {}

	-- Own RaycastParams rather than borrowing Navigation's: Navigation owns
	-- this module, so reaching back up for them would close a dependency
	-- cycle. Same configuration and the same reasoning for RespectCanCollide
	-- as Navigation -- only solid geometry should count as floor or wall, or
	-- decorative non-colliding parts would read as ground over a real hole.
	local probeParams = RaycastParams.new()
	probeParams.FilterType = Enum.RaycastFilterType.Exclude
	probeParams.FilterDescendantsInstances = { instance.model }
	probeParams.RespectCanCollide = true

	return setmetatable({
		instance      = instance,
		navConfig     = navConfig,
		agentParams   = navConfig.AgentParams or {},
		agentRadius   = (navConfig.AgentParams and navConfig.AgentParams.AgentRadius) or 0,
		probeParams   = probeParams,
		waypoints     = nil,
		waypointIndex = 1,
		pathedTo      = nil,
		lastComputeAt = 0,
		computing     = false,
		lastStatus    = nil,
		-- Set when the probe below has cleared a straight walk to the goal, so
		-- MoveTo steers at the goal itself and ignores the navmesh's route.
		directRoute   = false,
	}, HumanoidPathLocomotion)
end

-- Can the monster just WALK from `from` to `to`, ignoring what the navmesh
-- thinks? Two independent questions, and both must pass:
--
--   * Is anything solid in the way? A spherecast of AgentRadius, so this asks
--     "can a body this wide pass", not "is the centre line clear" -- the same
--     question PickRoamPoint asks, for the same reason.
--   * Is the floor continuous ENOUGH? Sampled along the segment. A run of
--     missing floor no wider than GapTolerance is a slit the Humanoid crosses
--     without input, and a step no taller than GapTolerance is one it climbs.
--     Either exceeding the tolerance means this is a real hole or a real
--     ledge, and the navmesh was right to route around it.
--
-- This deliberately second-guesses PathfindingService, which is why it lives
-- here next to the pathfinding it overrides rather than beside Navigation's
-- general-purpose probes.
function HumanoidPathLocomotion:_isDirectRouteWalkable(from: Vector3, to: Vector3): boolean
	local cfg = self.navConfig
	local tolerance = cfg.GapTolerance or MonsterConstants.DefaultNavGapTolerance
	local maxDistance = cfg.DirectRouteMaxDistance or MonsterConstants.DefaultNavDirectRouteMaxDistance

	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local distance = flat.Magnitude
	if distance < 1e-3 or distance > maxDistance then
		return false
	end
	local direction = flat.Unit

	local radius = math.max(self.agentRadius, 0.5)
	-- Swept FLAT from `from`, which is the root position and therefore already
	-- at body height -- lifting it further (as a probe starting from a ground
	-- point would have to) would raise the sweep to head height and miss
	-- exactly the knee-high clutter this is meant to catch. The direction is
	-- flattened, so the sweep holds that height for its whole length.
	if workspace:Spherecast(from, radius, direction * distance, self.probeParams) then
		return false
	end

	-- Half the tolerance, so a gap exactly at the limit cannot hide between
	-- two samples.
	local step = math.max(tolerance / 2, 0.5)
	local drop = Vector3.new(0, -(GROUND_PROBE_UP + GROUND_PROBE_DOWN), 0)
	local missingRun, lastGroundY = 0, nil

	for i = 0, math.floor(distance / step) do
		local point = from + direction * math.min(i * step, distance)
		local hit = workspace:Raycast(point + Vector3.new(0, GROUND_PROBE_UP, 0), drop, self.probeParams)

		if hit then
			if lastGroundY and math.abs(hit.Position.Y - lastGroundY) > tolerance then
				return false
			end
			lastGroundY = hit.Position.Y
			missingRun = 0
		else
			missingRun += step
			if missingRun > tolerance then
				return false
			end
		end
	end

	return true
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

		local cfg = self.navConfig

		if status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			self.waypoints = waypoints
			-- Waypoint 1 is where we already are.
			self.waypointIndex = 2
			self.pathedTo = goal
			self.directRoute = false

			-- Second-guess the navmesh in exactly two cases, both of which mean
			-- "a gap split the mesh":
			--
			--   * The route is much longer than the straight line -- it walked
			--     around the gap.
			--   * The route JUMPS. With AgentCanJump on, the navmesh bridges a
			--     small slit with a jump link instead of detouring, so the path
			--     is short and the detour test alone would never fire -- and the
			--     monster would hop over an imperfection it should stride across.
			--     Walk first, jump only where walking genuinely won't do.
			--
			-- Everywhere else the probe is skipped, so the common case pays
			-- nothing for this.
			local straight = flatDistance(origin, goal)
			local detourRatio = cfg.DirectRouteDetourRatio or MonsterConstants.DefaultNavDirectRouteDetourRatio
			local detoured = straight > 1e-3 and pathLength(waypoints) > straight * detourRatio
			local jumps = hasJumpWaypoint(waypoints)

			if (detoured or jumps) and self:_isDirectRouteWalkable(origin, goal) then
				self.directRoute = true
				self.waypoints = nil

				if MonsterConstants.DebugPathfinding then
					warn(("[Path] %s: overriding navmesh route (%s) over %.0f studs -- direct walk is clear within gap tolerance")
						:format(self.instance.monsterId, jumps and "jump link" or "detour", straight))
				end
			end
		else
			-- Unreachable for these AgentParams. Drop the stale path so MoveTo
			-- falls back to walking straight at the goal.
			self.waypoints = nil

			-- A refused path over a walkable slit is the same gap problem as a
			-- detour, just expressed as NoPath. When the probe clears it this is
			-- a COMMITTED direct route, not a blind straight-line: pathedTo is
			-- set so the next tick steers instead of recomputing every cooldown
			-- against geometry that will refuse it again.
			self.directRoute = self:_isDirectRouteWalkable(origin, goal)
			self.pathedTo = self.directRoute and goal or nil

			if not self.directRoute then
				self.instance.bus:Fire("PathBlocked", {})
			end

			if MonsterConstants.DebugPathfinding then
				if self.directRoute then
					warn(("[Path] %s: %s over %.0f studs -- but direct walk is clear within gap tolerance, committing to it")
						:format(self.instance.monsterId, tostring(status), flatDistance(origin, goal)))
				else
					warn(("[Path] %s: %s over %.0f studs -- falling back to straight-line, which will snag on geometry")
						:format(self.instance.monsterId, tostring(status), flatDistance(origin, goal)))
				end
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
	-- Cleared with the path it was derived from: the next journey has its own
	-- geometry and must be probed on its own terms, not inherit this one's
	-- verdict.
	self.directRoute = false
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
	self.directRoute = false
end

return HumanoidPathLocomotion
