-- Band 2, alongside Reset: nothing outranks a kill in progress except a
-- forced transition (another Band-2+ pick, or Evolved/StageChanged). Scores
-- very high -- flat 1 -- the instant a committed target is within
-- Stats.AttackReach; Chase (Band 1) already loses precedence the moment this
-- becomes eligible, which is the entire "Chase --> Attack: dist <= AttackReach"
-- edge from the blueprint's transition diagram. No new mechanism needed for
-- it; band precedence already does the work.
--
-- Interruptible = true, matching Reset's own convention rather than Reset's
-- doc comment's looser "always forced" phrasing: MinStateDuration already
-- provides the stickiness (a non-forced exit needs it to elapse regardless of
-- this flag), and Attack releases the normal way -- by no longer scoring, once
-- the target dies or steps out of reach -- not by being forced out.
--
-- Update deliberately does nothing beyond Enter's stop. Combat is autonomous:
-- "Reach" mode kills on its own Tick regardless of AI state, and "Contact"
-- mode kills off rootPart.Touched, equally independent of state -- see
-- Components/Combat's own header. A player standing next to a "Chasing"
-- monster was always just as dead. Attack's entire job is precedence (hold
-- Band 2 so nothing lower-priority steals the monster mid-kill) and motion
-- (stop walking so it doesn't visibly push through its target) -- there is no
-- second kill path here to keep in sync with Combat's own.

local Attack = {}

Attack.Name = "Attack"
Attack.Band = 2
Attack.Interruptible = true
Attack.TickRate = 0.1

-- Once attacking, the target has to get meaningfully clear before Chase takes
-- back over. Without this margin a player backing away sits right on the reach
-- boundary and flips Attack/Chase at MinStateDuration -- and since Attack.Enter
-- stops navigation, that reads as the monster stalling out every half second
-- exactly when it has caught you.
local RELEASE_MARGIN = 1.6

function Attack.Score(instance, blackboard): number?
	local target = blackboard.Target
	local position = blackboard.LastKnownPos
	if not target or not position then
		return nil
	end

	local combat = instance:GetComponent("Combat")
	if not combat then
		return nil
	end

	local margin = 1
	if instance.stateMachine and instance.stateMachine.current == Attack.Name then
		margin = RELEASE_MARGIN
	end

	if not combat:IsInReach(position, margin) then
		return nil
	end

	return 1
end

function Attack.Enter(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
end

function Attack.Update(_instance, _dt) end

function Attack.Exit(_instance) end

return Attack
