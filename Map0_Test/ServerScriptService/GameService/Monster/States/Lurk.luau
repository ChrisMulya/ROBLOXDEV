-- Hold position, get more agitated the closer a target gets, without ever
-- revealing itself by moving. CanLurk deliberately carries no CanNavigate
-- requirement (MonsterCapabilities) -- a Lurk monster that pathed toward
-- what it's lurking near would just be a slow, telegraphed Chase, which
-- defeats the point of a stationary ambush type.
--
-- "Unseen" means not yet a committed Target: the moment Targeting promotes
-- someone (blackboard.Target set), Chase (Band 1) already outranks Lurk
-- (Band 0) regardless of score, so Lurk does not need to check for that
-- itself beyond declining to score once a Target exists.
--
-- Reads blackboard.VisibleTargets, same as every other state -- Lurk does NOT
-- run its own proximity scan. A monster that wants Lurk to mean something
-- must therefore also declare a sensor that populates VisibleTargets (CanSee,
-- possibly with a wide FOV and RequiresLOS = false to feel omnidirectional).
-- This is a real per-monster authoring requirement, not a framework gap --
-- see the blueprint's D7 notes.

local Lurk = {}

Lurk.Name = "Lurk"
Lurk.Band = 0
Lurk.Interruptible = true
Lurk.TickRate = 0.2

function Lurk.Score(instance, blackboard): number?
	if blackboard.Target then
		return nil
	end

	local visible = blackboard.VisibleTargets
	if not visible or not visible[1] then
		return nil
	end

	local range = instance.config.Stats.DetectRadius
	if not range or range <= 0 then
		return nil
	end

	return 1 - math.clamp(visible[1].distance / range, 0, 1)
end

function Lurk.Enter(instance)
	-- Guards against entering Lurk mid-motion from an interrupted Wander/Patrol
	-- -- Lurk itself never issues a MoveTo, so this is the only place it could
	-- ever need to stop one.
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
end

function Lurk.Update(_instance, _dt) end

function Lurk.Exit(_instance) end

return Lurk
