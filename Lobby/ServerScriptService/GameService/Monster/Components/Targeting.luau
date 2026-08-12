-- Sole writer of Blackboard.Target.
--
-- Target looks like it needs several writers -- Perception proposes one, Chase
-- commits to one, Combat clears it on a kill, Reset clears it on leash. That
-- isn't a licence to break the single-writer rule; it means the key needs an
-- OWNER. Everyone else calls Request/Clear and the arbitration lives here, in
-- one readable place.
--
-- Always constructed (MonsterCapabilities.AlwaysOn): a monster with no target
-- is still a monster, and something has to own the key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local Targeting = {}
Targeting.__index = Targeting

Targeting.Name = "Targeting"
Targeting.Writes = {
	"Target",
	"LastKnownPos",
	"LastSeenAt",
	"LastSeenDirection",
	"LoSLostAt",
	"TrailPos",
	"TrailAt",
}
Targeting.TickRate = 0.1

function Targeting.new(instance, _config)
	local self = setmetatable({
		instance = instance,
		-- Who we are still pursuing after losing sight of them. Needed because
		-- Clear drops Blackboard.Target by design, and without remembering the
		-- player there is nothing to match a heard stimulus against.
		lostTarget = nil,
		-- Rolling {Position, Timestamp} samples taken ONLY in Request, i.e. only
		-- while a target is genuinely visible. LastSeenDirection is derived
		-- exclusively from this -- never from a later position, never from a
		-- footstep.
		sightHistory = {},
	}, Targeting)

	local blackboard = instance.blackboard
	blackboard.Target = nil
	blackboard.LastKnownPos = nil
	-- Sight-only from here on: Request is the only writer. FollowTrail no
	-- longer touches this pair -- see TrailPos/TrailAt.
	blackboard.LastSeenAt = 0
	-- Visual escape direction at the moment sight broke. nil when the target
	-- read as stationary or there weren't enough samples.
	blackboard.LastSeenDirection = nil
	-- Timestamp LOS actually broke, written once by Clear.
	blackboard.LoSLostAt = nil
	-- Non-visual: newest HEARD position of the player already being pursued.
	-- Deliberately separate from LastKnownPos -- writing a heard position
	-- there would silently promote a footstep to a sighting.
	blackboard.TrailPos = nil
	blackboard.TrailAt = nil

	return self
end

-- Horizontal displacement across the sighting window, or nil if the target
-- read as stationary (below DirectionMinDisplacement) or there weren't at
-- least two samples to compare. Y is zeroed -- this drives ground-plane
-- projection and SearchPoint bearing, not a 3D heading.
function Targeting:_computeLastSeenDirection(): Vector3?
	local history = self.sightHistory
	if #history < 2 then
		return nil
	end

	local oldest = history[1]
	local newest = history[#history]
	local delta = newest.Position - oldest.Position
	delta = Vector3.new(delta.X, 0, delta.Z)

	local investigationConfig = self.instance.config.Investigation
	local minDisplacement = (investigationConfig and investigationConfig.DirectionMinDisplacement)
		or MonsterConstants.DefaultDirectionMinDisplacement
	if delta.Magnitude < minDisplacement then
		return nil
	end

	return delta.Unit
end

function Targeting:Start() end

-- Commits to a target. Re-requesting the current target just refreshes its
-- last-known position, which is what keeps a chase alive frame to frame.
function Targeting:Request(player: Player, position: Vector3, _reason: string?): boolean
	local blackboard = self.instance.blackboard
	local previous = blackboard.Target

	-- A different player being sighted invalidates any in-progress history --
	-- otherwise a direction could be computed across two different people's
	-- positions.
	if previous ~= player then
		table.clear(self.sightHistory)
	end

	local now = os.clock()
	table.insert(self.sightHistory, { Position = position, Timestamp = now })

	local investigationConfig = self.instance.config.Investigation
	local window = (investigationConfig and investigationConfig.DirectionSampleWindow)
		or MonsterConstants.DefaultDirectionSampleWindow
	while #self.sightHistory > 1 and now - self.sightHistory[1].Timestamp > window do
		table.remove(self.sightHistory, 1)
	end

	blackboard.Target = player
	blackboard.LastKnownPos = position
	blackboard.LastSeenAt = now
	-- Reacquired by sight; there is no trail to follow any more.
	self.lostTarget = nil

	if previous ~= player then
		self.instance.bus:Fire("TargetAcquired", { UserId = player.UserId })
		return true
	end
	return false
end

-- Clears the committed target but DELIBERATELY keeps LastKnownPos: losing
-- sight of someone is not the same as forgetting where they were, and the
-- pursuit behaviour depends on that distinction. Also stamps LoSLostAt and
-- derives LastSeenDirection from the sighting history, both exactly once,
-- here -- the single instant LOS actually broke.
function Targeting:Clear(_reason: string?)
	local blackboard = self.instance.blackboard
	if blackboard.Target == nil then
		return
	end

	-- Captured BEFORE nulling: remembered so a stimulus this player causes can
	-- still redirect the pursuit -- see FollowTrail.
	self.lostTarget = blackboard.Target
	blackboard.Target = nil

	blackboard.LoSLostAt = os.clock()
	blackboard.LastSeenDirection = self:_computeLastSeenDirection()

	self.instance.bus:Fire("TargetLost", {})
end

function Targeting:Forget()
	local blackboard = self.instance.blackboard
	blackboard.Target = nil
	blackboard.LastKnownPos = nil
	blackboard.LastSeenAt = 0
	blackboard.LastSeenDirection = nil
	blackboard.LoSLostAt = nil
	blackboard.TrailPos = nil
	blackboard.TrailAt = nil
	self.lostTarget = nil
	table.clear(self.sightHistory)
end

function Targeting:Get(): Player?
	return self.instance.blackboard.Target
end

-- Promotes the nearest thing Perception saw into a committed target, and drops
-- a target that stopped being visible. Reproduces what Chase.Update used to do
-- inline every tick.
function Targeting:Tick(_dt: number)
	local blackboard = self.instance.blackboard
	local visible = blackboard.VisibleTargets

	if visible and #visible > 0 then
		local nearest = visible[1]
		self:Request(nearest.player, nearest.position, "Perceived")
		return
	end

	if blackboard.Target then
		self:Clear("NotVisible")
	end

	self:FollowTrail()
end

-- Chase what you can HEAR of someone you have already committed to, not the
-- stale spot you last saw them.
--
-- Without this, breaking line of sight while sprinting sends the monster to
-- where you WERE and leaves it there -- so the correct play is to run past a
-- corner and keep running, and the monster is beaten by geometry rather than
-- by anything the player did well. With it, staying loud keeps giving your
-- position away, and the counter-play is the one the movement design already
-- built: stop sprinting. Walking is under FootstepEmitter's noise threshold,
-- so going quiet genuinely breaks the trail.
--
-- Three constraints keep this from becoming "monsters hunt by sonar":
--
--   * It only ever REDIRECTS an existing pursuit. It cannot start one -- that
--     still requires sight, via Request. A monster that has not seen you is
--     unaffected no matter how loud you are.
--   * It expires with the pursuit window. Once PursuitDuration lapses the
--     trail is dropped, so a later noise cannot resurrect a dead chase; it
--     goes through Check like any other stimulus.
--   * The stimulus must be from the pursued player (Source identity). Someone
--     else's footsteps are not a lead on where you went.
--
-- Note this uses Source only to decide RELEVANCE and takes the position from
-- the stimulus itself -- it never resolves Source to that player's live
-- character position, which is the rule that keeps hearing from being sight.
function Targeting:FollowTrail()
	local player = self.lostTarget
	if not player then
		return
	end

	local blackboard = self.instance.blackboard

	-- Anchor covers sight AND an already-running trail: a trail being
	-- refreshed tick after tick must not read as lapsed just because the
	-- original SIGHTING is old. LastSeenAt no longer advances on its own here
	-- (that promotion moved to TrailPos/TrailAt), so this max is what keeps
	-- an active trail alive for its own PursuitDuration.
	local anchor = math.max(blackboard.LastSeenAt, blackboard.TrailAt or 0)

	-- Pursuit lapsed: drop the trail rather than let a stray noise revive it.
	local pursuitDuration = self.instance.config.Stats.PursuitDuration or 0
	if os.clock() - anchor > pursuitDuration then
		self.lostTarget = nil
		blackboard.TrailPos = nil
		blackboard.TrailAt = nil
		return
	end

	if not player.Parent then
		self:Forget()
		return
	end

	-- Newest stimulus THIS player caused since we last knew where they were.
	-- Scans the list rather than reading LastStimulus, which is newest-wins
	-- across every source and kind -- another player's footstep or a flash
	-- would otherwise mask the one lead that matters.
	--
	-- Backwards, stopping at the first entry older than LastSeenAt. Perception
	-- appends, so the list runs oldest-to-newest and the answer is near the
	-- end; a forward scan would walk up to 20 seconds of retained footsteps
	-- (several per second, per player) on every tick to find it. Ordering is
	-- only approximate WITHIN a tick, where several sensors drain in sensor
	-- order rather than timestamp order -- microseconds apart, far below the
	-- LastSeenAt boundary this breaks on.
	local stimuli = blackboard.Stimuli
	if not stimuli then
		return
	end

	local best
	for index = #stimuli, 1, -1 do
		local stimulus = stimuli[index]
		if stimulus.Timestamp <= anchor then
			break
		end
		if stimulus.Source == player then
			best = stimulus
			break
		end
	end

	if not best then
		return
	end

	-- Never LastKnownPos/LastSeenAt: those stay sight-only. This is heard
	-- information, kept in its own pair so nothing downstream can mistake it
	-- for a sighting.
	blackboard.TrailPos = best.Position
	blackboard.TrailAt = best.Timestamp
	-- Wakes the Brain so Chase re-evaluates against the new position instead of
	-- waiting out its poll interval.
	self.instance.bus:Fire("TrailUpdated", { UserId = player.UserId })
end

function Targeting:Destroy() end

return Targeting
