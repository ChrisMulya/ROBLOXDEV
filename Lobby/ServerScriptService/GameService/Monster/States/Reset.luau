-- Return to the spawn anchor and drop everything the monster was holding.
--
-- Band 2 and always forced: a leashed or stuck monster must be recoverable no
-- matter what state it's wedged in, so Reset ignores MinStateDuration and
-- Interruptible.
--
-- Scores off Stats.LeashDistance; a monster that does not define one can never
-- enter this state. Every shipped monster defines it well ABOVE its maximum
-- chase envelope (DetectRadius + WalkSpeed * PursuitDuration at the highest
-- stage), so Reset stays a recovery path for a stuck monster rather than
-- something that fires during a legitimate pursuit.

local Reset = {}

Reset.Name = "Reset"
Reset.Band = 2
Reset.Interruptible = true
Reset.TickRate = 0.1
-- Same pace as Wander/Patrol, not full chase speed. Reset is a stuck monster
-- walking home, not a monster hunting -- moving it at Chase's speed reads as
-- a sprint back to base, which is the wrong tell for "I gave up."
Reset.SpeedScale = 0.5

function Reset.Score(instance, blackboard): number?
	local leash = instance.config.Stats.LeashDistance
	local anchor = blackboard.SpawnPosition
	local rootPart = instance.rootPart
	if not leash or not anchor or not rootPart then
		return nil
	end

	local distance = (rootPart.Position - anchor).Magnitude
	if distance <= leash then
		return nil
	end

	-- Scales past the leash so that the further out it gets, the more strongly
	-- it wants to come back -- capped at 1.
	return math.clamp((distance - leash) / leash, 0.1, 1)
end

function Reset.Enter(instance)
	local targeting = instance:GetComponent("Targeting")
	if targeting then
		targeting:Forget()
	end

	-- Resolved once per entry, not per tick: SpawnPosition never moves, and
	-- ResolveReachable costs a raycast plus an overlap query.
	--
	-- SpawnPosition is the monster's root position at spawn, which comes
	-- straight from a hand-placed IsMonsterSpawn marker -- so it is exactly as
	-- likely to sit inside a wall or floating over a ledge as any authored
	-- point. Falling back to the raw anchor when it will not resolve is
	-- deliberate: a monster that cannot path home should still try, because
	-- the alternative is one that gives up and stands wherever it got stuck.
	local navigation = instance:GetComponent("Navigation")
	local anchor = instance.blackboard.SpawnPosition
	if not navigation or not anchor then
		return
	end

	local resolved = navigation:ResolveReachable(anchor)
	if not resolved and not instance.resetAnchorWarned then
		instance.resetAnchorWarned = true
		warn(("Reset: '%s' spawn anchor at %s has no reachable ground -- check the IsMonsterSpawn marker's placement")
			:format(instance.monsterId, tostring(anchor)))
	end
	instance.resetAnchor = resolved or anchor
end

function Reset.Update(instance, dt: number)
	local anchor = instance.resetAnchor or instance.blackboard.SpawnPosition
	local navigation = instance:GetComponent("Navigation")
	if anchor and navigation then
		navigation:MoveTo(anchor, dt)
	end
end

-- The only movement state whose Exit did not stop navigation. Not a live bug
-- -- every state Reset can hand off to either stops in Enter (Idle, Lurk,
-- Attack) or issues its own move immediately (Wander, Patrol, Check, Chase) --
-- but leaving one movement state out of that invariant is how the next one
-- gets written without it too.
function Reset.Exit(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
end

return Reset
