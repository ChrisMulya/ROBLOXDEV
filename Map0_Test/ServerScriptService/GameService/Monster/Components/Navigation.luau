-- Movement. Owns a Locomotion strategy and nothing else -- it does not decide
-- WHERE to go, only how to get there. States call MoveTo with a destination.
--
-- Not constructed at all for a monster without CanNavigate: a stationary
-- monster costs zero movement budget rather than running a disabled code path.

local Navigation = {}
Navigation.__index = Navigation

Navigation.Name = "Navigation"
Navigation.Writes = { "NavStatus" }

local Locomotion = require(script.Parent.Parent.Locomotion)

-- Cast above the floor, or the ground plane itself is the first thing every
-- roam probe hits and no point is ever reachable.
local ROAM_RAY_HEIGHT = 3
-- Literal gap left between the monster's BODY and the wall. The sweep below is
-- a spherecast sized to AgentRadius, so body width is already accounted for
-- and this is the visible sliver of daylight, not a centre-point offset.
local WALL_MARGIN = 0.2
-- A roam point closer than this to where it was picked from is not worth
-- walking to; the caller treats it as "nowhere to go" and tries again later.
local MIN_ROAM_DISTANCE = 2
-- Ground probe envelope. Up first (so a point sunk slightly into the floor
-- still finds it), then down far enough to catch a step or a ramp but not so
-- far that a point over a stairwell resolves to the storey below.
local GROUND_PROBE_UP = 6
local GROUND_PROBE_DOWN = 24
-- Height both ends of a line-of-sight test are lifted to. Patrol markers sit on
-- the floor, and a floor-to-floor ray grazes the ground itself on any slope or
-- step and reports a wall that isn't there. Chest height on this rig.
local LOS_HEIGHT = 3
-- How long the body can go without covering STUCK_DISTANCE before MoveTo
-- reports "stuck" -- pressed against a wall, snagged on a corner, or grinding
-- on a straight-line fallback with no path. 3s is generous even for Wander's
-- slowest state (Check at 0.75x): the smallest configured WalkSpeed still
-- covers this distance in a fraction of a second when actually moving, so a
-- miss here means the body genuinely isn't translating, not that it's slow.
local STUCK_WINDOW = 3
local STUCK_DISTANCE = 2
-- A destination close enough to the one already being tracked counts as "the
-- same journey" for stuck purposes. Without this, a caller re-issuing the
-- literal same Vector3 every tick (as several states do) would look like a
-- brand new journey every tick and the stuck window would never accumulate.
local STUCK_SAME_TARGET_EPSILON = 0.5

function Navigation.new(instance, config)
	local navConfig = config.Navigation or {}
	local strategy = Locomotion.Get(navConfig.Locomotion)

	local self = setmetatable({
		instance    = instance,
		locomotion  = strategy.new(instance, navConfig),
		wasArrived  = false,
		stuckAnchor = nil,
		agentRadius = (navConfig.AgentParams and navConfig.AgentParams.AgentRadius) or 0,
	}, Navigation)

	-- Same reasoning as VisionSensor for RespectCanCollide: only solid geometry
	-- should block, or invisible trigger volumes and decorative non-colliding
	-- parts would shrink every roam radius for no visible reason.
	local roamParams = RaycastParams.new()
	roamParams.FilterType = Enum.RaycastFilterType.Exclude
	roamParams.FilterDescendantsInstances = { instance.model }
	roamParams.RespectCanCollide = true
	self.roamParams = roamParams

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { instance.model }
	overlapParams.RespectCanCollide = true
	-- Only ever asked "is anything there at all", never "what".
	overlapParams.MaxParts = 1
	self.overlapParams = overlapParams

	instance.blackboard.NavStatus = "Idle"

	return self
end

function Navigation:Start() end

-- Speed is per-STATE, not a single number per monster. Stats.WalkSpeed is the
-- pursuit speed -- the one tuned against the player's SprintSpeed -- and a
-- monster ambling a patrol route at full chase speed reads as permanently
-- alerted, which throws away the tell that it has actually noticed you.
--
-- Resolution order: the monster's own config first (States.<Name>.SpeedScale),
-- then the state module's declared default, then 1. Scaling rather than a
-- second stat means stage bumps and evolution multipliers reach patrol speed
-- for free, and there is no second number to keep under Limits.
--
-- Resolved HERE rather than inside a Locomotion strategy: locomotion is "how
-- to move", and which state is active is emphatically not its business. It
-- gets told a speed.
function Navigation:GetSpeed(): number?
	local base = self.instance.config.Stats.WalkSpeed
	if not base then
		return nil
	end

	local machine = self.instance.stateMachine
	local stateName = machine and machine.current
	if not stateName then
		return base
	end

	local stateConfig = self.instance.config.States and self.instance.config.States[stateName]
	local scale = (stateConfig and stateConfig.SpeedScale)
		or (machine.module and machine.module.SpeedScale)
		or 1

	return base * scale
end

-- Turns any candidate destination into one the monster can actually stand on,
-- or nil if it cannot. Two independent failure modes, both of which produce
-- the same symptom -- a monster grinding against geometry or walking at
-- nothing -- and neither of which pathfinding reports usefully:
--
--   * No floor. A point over a ledge, a stairwell or the void has nothing to
--     walk to. Snapping to the ground beneath also FIXES THE Y, which matters
--     on slopes and multi-storey geometry: a caller working from a stimulus
--     position or a spawn anchor otherwise carries that origin's height into
--     a destination on a different floor.
--   * Inside something. A point buried in a wall or a prop is unreachable at
--     any speed; the monster paths as close as it can and then presses.
--
-- Public because Reset (its spawn anchor) and Patrol (its authored route)
-- need the same guarantee as the random roam points, and an authored Vector3
-- is if anything MORE likely to be slightly inside a wall than a random one.
function Navigation:ResolveReachable(point: Vector3): Vector3?
	local from = point + Vector3.new(0, GROUND_PROBE_UP, 0)
	local drop = Vector3.new(0, -(GROUND_PROBE_UP + GROUND_PROBE_DOWN), 0)

	local ground = workspace:Raycast(from, drop, self.roamParams)
	if not ground then
		return nil
	end

	-- Probe at body height, not at the feet: a sphere centred on the floor
	-- would count the floor itself as an obstruction.
	local probeRadius = math.max(self.agentRadius, 0.5)
	local probeCentre = ground.Position + Vector3.new(0, probeRadius + 0.5, 0)
	if #workspace:GetPartBoundsInRadius(probeCentre, probeRadius, self.overlapParams) > 0 then
		return nil
	end

	return ground.Position
end

-- Is there unobstructed space between two points? Full 360 degrees -- this is
-- deliberately NOT a vision test and takes no facing into account. It answers
-- "is that thing behind a wall", which is what Patrol needs to stop picking a
-- destination on the far side of one.
--
-- Distinct from VisionSensor's LOS check, which is about whether the monster
-- can SEE a target and is gated by a FOV cone. Sharing one function would
-- eventually mean one of the two callers silently getting the other's cone.
--
-- `ignore` is the destination marker itself: an author who leaves CanCollide on
-- an invisible marker would otherwise have that marker block the ray to itself.
-- Hitting it means everything up to it was clear, so that reads as visible.
function Navigation:HasLineOfSight(from: Vector3, to: Vector3, ignore: Instance?): boolean
	local origin = from + Vector3.new(0, LOS_HEIGHT, 0)
	local target = to + Vector3.new(0, LOS_HEIGHT, 0)
	local delta = target - origin
	if delta.Magnitude < 1e-3 then
		return true
	end

	local hit = workspace:Raycast(origin, delta, self.roamParams)
	if not hit then
		return true
	end
	if ignore and (hit.Instance == ignore or hit.Instance:IsDescendantOf(ignore)) then
		return true
	end
	return false
end

-- Sweeps a body-width spherecast from origin along direction for up to
-- distance, truncates short of anything it hits, and hands the result to
-- ResolveReachable. Shared by PickRoamPoint (random direction) and
-- Investigation's Visual candidate (a specific escape heading) -- both are
-- "walk this way, but not into a wall".
--
-- Why the check is needed at all: an unvalidated point routinely lands inside
-- a wall. PathfindingService then returns NoPath, HumanoidPathLocomotion drops
-- to straight-lining at the target, and Humanoid:Move drives the monster into
-- the wall and holds it there -- it never "arrives", so it presses against the
-- surface until the state gives up on its own timer. That is the wall-hugging.
--
-- SPHERECAST, not a raycast. A zero-width ray happily threads a gap narrower
-- than the monster, so the destination passes validation and then the body
-- cannot follow. Sweeping a sphere of AgentRadius asks the question that
-- actually matters -- "can something this wide get there" -- and its hit
-- distance is already measured from the body surface, which is what makes
-- WALL_MARGIN a literal gap rather than a centre-point fudge.
--
-- direction must already be a unit vector. Returns nil when there is nowhere
-- worth walking to, so callers can re-roll or fall back rather than
-- committing to a zero-length or unreachable trip.
function Navigation:ProjectAlong(origin: Vector3, direction: Vector3, distance: number): Vector3?
	local from = origin + Vector3.new(0, ROAM_RAY_HEIGHT, 0)
	local probeRadius = math.max(self.agentRadius, 0.5)
	local sweep = workspace:Spherecast(from, probeRadius, direction * distance, self.roamParams)

	local usable = distance
	if sweep then
		-- Distance the sphere CENTRE travelled before its surface touched, so
		-- the body is already clear; the margin is pure daylight on top.
		usable = sweep.Distance - WALL_MARGIN
	end

	if usable < MIN_ROAM_DISTANCE then
		return nil
	end

	return self:ResolveReachable(origin + direction * usable)
end

-- A random point within radius of origin that the monster can reach and stand
-- on. Shared by Wander and Check, which both used to roll their own unchecked
-- point and hand it straight to MoveTo.
--
-- Uniform within the disc, not within the radius: sqrt() on the random draw
-- stops points bunching toward the centre, which would leave the monster
-- pacing the same few studs instead of covering the area.
function Navigation:PickRoamPoint(origin: Vector3, radius: number): Vector3?
	local angle = math.random() * (2 * math.pi)
	local distance = math.sqrt(math.random()) * radius
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

	return self:ProjectAlong(origin, direction, distance)
end

-- Body-displacement stuck check, not a wall-contact check: the question is
-- "is this thing actually translating through space while it's trying to",
-- which catches wall-hugging, corner-snagging and a straight-line fallback
-- grinding on geometry all the same way, with no raycast of its own.
--
-- Keyed off the DESTINATION, not the caller: a caller re-issuing the same
-- Vector3 every tick (most states do) must accumulate across those calls, but
-- a caller switching to a genuinely different destination -- including one
-- issued right after Stop() went idle for a while, e.g. a deliberate pause
-- that never called MoveTo at all -- must not inherit a stale multi-second-old
-- window and report stuck on its very first tick.
function Navigation:_checkStuck(position: Vector3, targetPosition: Vector3): boolean
	local now = os.clock()
	local anchor = self.stuckAnchor

	if not anchor or (anchor.target - targetPosition).Magnitude > STUCK_SAME_TARGET_EPSILON then
		self.stuckAnchor = { position = position, at = now, target = targetPosition }
		return false
	end

	if (position - anchor.position).Magnitude > STUCK_DISTANCE then
		anchor.position = position
		anchor.at = now
		return false
	end

	return now - anchor.at >= STUCK_WINDOW
end

-- Second return is STUCK, not an error condition -- most callers ignore it
-- (Lua drops unused returns) and get the pre-existing single-value behaviour.
-- A caller that wants "give up and try something else" reads it explicitly.
function Navigation:MoveTo(targetPosition: Vector3, dt: number): (boolean, boolean)
	local arrived = self.locomotion:MoveTo(targetPosition, dt, self:GetSpeed())

	local stuck = false
	if arrived then
		self.stuckAnchor = nil
	else
		stuck = self:_checkStuck(self.instance.rootPart.Position, targetPosition)
	end
	self.instance.blackboard.NavStatus = if arrived then "Arrived" elseif stuck then "Stuck" else "Moving"

	-- EDGE-triggered, not level-triggered. Locomotion reports "arrived" on
	-- every tick it is already there, and Chase keeps calling MoveTo at the
	-- last known position for the whole PursuitDuration -- up to 20s. Firing
	-- per tick would allocate and freeze a payload each time and wake the
	-- Brain at the tick rate, defeating its own 0.2s throttle.
	if arrived ~= self.wasArrived then
		self.wasArrived = arrived
		if arrived then
			-- The Brain re-evaluates on Arrived rather than waiting out its
			-- tick interval, so a monster that reaches a search point picks its
			-- next state immediately instead of standing still for up to 200ms.
			self.instance.bus:Fire("Arrived", {})
		end
	end

	return arrived, stuck
end

function Navigation:Stop()
	self.locomotion:Stop()
	self.instance.blackboard.NavStatus = "Idle"
	-- Reset the edge so the next journey can report arrival again.
	self.wasArrived = false
	-- A caller that stops mid-journey is abandoning it on purpose (Patrol's
	-- point-pause is the exception -- it never calls Stop at all, precisely so
	-- MoveDirection stays zeroed without touching this). Whatever destination
	-- comes next should get a fresh window, not the old one's remaining time.
	self.stuckAnchor = nil
end

function Navigation:Destroy()
	self.locomotion:Destroy()
end

return Navigation
