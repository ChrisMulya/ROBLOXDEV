-- Pursue the committed target; keep going to their last known position for
-- PursuitDuration after losing them.
--
-- Same behaviour as the old States/Chase.luau, redistributed: sensing moved to
-- Perception, target commitment to Targeting, movement to Navigation, damage
-- to Combat. What's left here is the actual policy -- "close the distance, and
-- don't give up immediately."
--
-- Update returns nothing. It used to return the next state (and always
-- returned nil); the Brain owns that decision now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StimulusKinds = require(ReplicatedStorage.Modules.Stimulus.StimulusKinds)

local Chase = {}

Chase.Name = "Chase"
Chase.Band = 1
Chase.Interruptible = true
Chase.TickRate = 0.1
-- The reference: Stats.WalkSpeed IS the chase speed, so this is 1 by
-- definition. Stated explicitly rather than left to the default because every
-- other state's SpeedScale is a fraction of this one.
Chase.SpeedScale = 1

-- Utility of chasing a VISIBLE target, gated on aggression.
--
-- Returns nil below Thresholds.Chase -- the monster sees you and declines. A
-- monster whose config declares no Thresholds.Chase is ungated and scores
-- exactly as it did before step 7, so deleting that one config line is the
-- revert if aggression turns out to be mistuned.
--
-- Above the threshold the score is graded rather than binary, so a future Lurk
-- or Check can outscore a half-hearted chase. It is floored at 0.5 rather than
-- ramping from 0: a chase that has qualified must still beat Idle's constant
-- 0.01, and a score near 0 at the threshold would make that a coin flip.
--
-- Attack/release asymmetry: it takes more anger to START chasing than to keep
-- chasing. Without it, a player hovering at the commit distance flips the
-- monster between Chase and Idle -- and since Idle.Enter calls Navigation:Stop,
-- that reads as the walk/halt stutter, twice a second under MinStateDuration.
-- The Brain's hysteresis cannot cover this: it only compares states that both
-- score, and below the threshold Chase returns nil and is not a candidate.
local function committedUtility(instance, blackboard): number?
	local settings = instance.config.Aggression
	local thresholds = settings and settings.Thresholds
	local threshold = thresholds and thresholds.Chase
	if not threshold then
		return 1
	end

	if instance.stateMachine and instance.stateMachine.current == Chase.Name then
		threshold = thresholds.ChaseRelease or threshold * 0.6
	end

	local aggression = blackboard.Aggression or 0
	if aggression < threshold then
		return nil
	end

	if threshold >= 1 then
		return 1
	end
	return 0.5 + 0.5 * ((aggression - threshold) / (1 - threshold))
end

-- Eligible while there's a target, or a last known position that hasn't gone
-- stale.
function Chase.Score(instance, blackboard): number?
	if blackboard.Target then
		return committedUtility(instance, blackboard)
	end

	-- The pursuit window is deliberately NOT aggression-gated. Proximity is the
	-- dominant driver and it reads 0 the moment you break line of sight, so
	-- gating here would let aggression decay past the threshold after ~4s and
	-- silently override PursuitDuration -- two authorities on how long a monster
	-- keeps looking for you. PursuitDuration is the one that survives.
	--
	-- Scored below any committed chase so a target that becomes visible again
	-- always wins over walking to where they used to be.
	if blackboard.LastKnownPos then
		local pursuitDuration = instance.config.Stats.PursuitDuration or 0
		if os.clock() - blackboard.LastSeenAt <= pursuitDuration then
			return 0.5
		end
	end

	return nil
end

function Chase.Enter(_instance) end

-- D7: no longer calls Combat directly. Attack (Band 2) now owns "target is
-- within reach" and outranks Chase the instant it becomes eligible, so by the
-- time Chase.Update would run on a tick where the target IS in reach, the
-- Brain has already switched the active state to Attack -- Brain ticks before
-- StateMachine every MonsterInstance.Tick, so this is not a race. The old
-- direct combat:TryKill call here was already redundant before Attack
-- existed: Combat's "Reach" mode kills autonomously on its own Tick
-- regardless of AI state, and "Contact" mode kills off Touched, equally
-- independent of state. Chase's only job now is closing the distance.
function Chase.Update(instance, dt: number)
	local blackboard = instance.blackboard
	local navigation = instance:GetComponent("Navigation")

	local target = blackboard.Target
	if target then
		local position = blackboard.LastKnownPos
		if position and navigation then
			navigation:MoveTo(position, dt)
		end
		return
	end

	-- Lost them. Walk to where they were; on giving up, forget entirely --
	-- which drops Chase.Score to nil and lets the Brain pick something else.
	local lastKnown = blackboard.LastKnownPos
	if not lastKnown then
		return
	end

	local targeting = instance:GetComponent("Targeting")

	-- PursuitDuration caps how long the WALK may take, not how long to stand
	-- around once it is over.
	local pursuitDuration = instance.config.Stats.PursuitDuration or 0
	if os.clock() - blackboard.LastSeenAt > pursuitDuration then
		if targeting then
			targeting:Forget()
		end
		return
	end

	if not navigation then
		return
	end

	if not navigation:MoveTo(lastKnown, dt) then
		return
	end

	-- Arrived, and they are not here.
	--
	-- Doing nothing at this point is the bug this branch exists to fix: Chase
	-- would keep re-issuing MoveTo at a position it already occupies, which
	-- returns "arrived" immediately every tick, so the monster stood on the
	-- spot for the entire remaining PursuitDuration -- up to 20 seconds of
	-- looking broken.
	--
	-- Hand the position to Check instead. It already knows how to work an
	-- area: hold, then sweep random points around it for a randomised 10-20s.
	-- Forgetting is what makes that possible -- Chase is Band 1 and Check is
	-- Band 0, so Check can never outscore an eligible Chase; Chase has to
	-- become ineligible before the search can start.
	local perception = instance:GetComponent("Perception")
	if perception then
		perception:Inject(StimulusKinds.LostTarget, lastKnown, 1)
	end
	if targeting then
		targeting:Forget()
	end
end

function Chase.Exit(_instance) end

return Chase
