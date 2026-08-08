-- Doing nothing, deliberately. The floor of the scoring system: always
-- eligible, lowest possible utility, so the Brain always has a valid pick and
-- the state machine can never be stateless.
--
-- Not the same as "no state". A monster in Idle is a monster that has looked
-- at its options and found nothing worth doing.

local Idle = {}

Idle.Name = "Idle"
Idle.Band = 0
Idle.Interruptible = true
-- Matches Chase so detection latency doesn't change with the active state.
Idle.TickRate = 0.1

-- Constant floor. Anything with an actual reason to run beats this.
function Idle.Score(_instance, _blackboard): number?
	return 0.01
end

function Idle.Enter(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
end

function Idle.Update(_instance, _dt) end

function Idle.Exit(_instance) end

return Idle
