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

local Targeting = {}
Targeting.__index = Targeting

Targeting.Name = "Targeting"
Targeting.Writes = { "Target", "LastKnownPos", "LastSeenAt" }
Targeting.TickRate = 0.1

function Targeting.new(instance, _config)
	local self = setmetatable({
		instance = instance,
		-- Who we are still pursuing after losing sight of them. Needed because
		-- Clear drops Blackboard.Target by design, and without remembering the
		-- player there is nothing to match a heard stimulus against.
		lostTarget = nil,
	}, Targeting)

	local blackboard = instance.blackboard
	blackboard.Target = nil
	blackboard.LastKnownPos = nil
	-- Despite the name this is "when the target's position was last KNOWN",
	-- not strictly last seen: FollowTrail below refreshes it from a stimulus
	-- the pursued player caused. Chase's pursuit window reads it, and that is
	-- the meaning the window wants.
	blackboard.LastSeenAt = 0

	return self
end

function Targeting:Start() end

-- Commits to a target. Re-requesting the current target just refreshes its
-- last-known position, which is what keeps a chase alive frame to frame.
function Targeting:Request(player: Player, position: Vector3, _reason: string?): boolean
	local blackboard = self.instance.blackboard
	local previous = blackboard.Target

	blackboard.Target = player
	blackboard.LastKnownPos = position
	blackboard.LastSeenAt = os.clock()
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
-- pursuit behaviour depends on that distinction.
function Targeting:Clear(_reason: string?)
	local blackboard = self.instance.blackboard
	if blackboard.Target == nil then
		return
	end

	-- Captured BEFORE nulling: remembered so a stimulus this player causes can
	-- still redirect the pursuit -- see FollowTrail.
	self.lostTarget = blackboard.Target
	blackboard.Target = nil
	self.instance.bus:Fire("TargetLost", {})
end

function Targeting:Forget()
	local blackboard = self.instance.blackboard
	blackboard.Target = nil
	blackboard.LastKnownPos = nil
	blackboard.LastSeenAt = 0
	self.lostTarget = nil
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

	-- Pursuit lapsed: drop the trail rather than let a stray noise revive it.
	local pursuitDuration = self.instance.config.Stats.PursuitDuration or 0
	if os.clock() - blackboard.LastSeenAt > pursuitDuration then
		self.lostTarget = nil
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
		if stimulus.Timestamp <= blackboard.LastSeenAt then
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

	blackboard.LastKnownPos = best.Position
	blackboard.LastSeenAt = best.Timestamp
	-- Wakes the Brain so Chase re-evaluates against the new position instead of
	-- waiting out its poll interval.
	self.instance.bus:Fire("TrailUpdated", { UserId = player.UserId })
end

function Targeting:Destroy() end

return Targeting
