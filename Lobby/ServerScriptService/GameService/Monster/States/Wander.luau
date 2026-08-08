-- Idle motion: pick a random point near the spawn anchor, walk to it, pause,
-- pick another. The low-priority default for a monster that can navigate but
-- has nothing better to do -- pairs with Check (D4): a monster that just
-- finished investigating a stimulus releases here rather than standing still.
--
-- Ineligible the instant a target is known (blackboard.Target OR the lingering
-- blackboard.LastKnownPos a live pursuit window leaves behind) -- Wander is
-- for "nothing is going on," not "I lost them a second ago."

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local Wander = {}

Wander.Name = "Wander"
Wander.Band = 0
Wander.Interruptible = true
-- Slower than Chase/Check on purpose -- wandering has no reason to react at
-- combat cadence, and a coarser tick is cheaper for a state most monsters
-- spend most of their time in.
Wander.TickRate = 0.5
-- Half of Stats.WalkSpeed. That stat is the PURSUIT speed, tuned against the
-- player's sprint; ambling a wander route at it would make the monster look
-- permanently alerted and throw away the tell that it has actually seen you.
-- Per-monster override: States.Wander.SpeedScale.
Wander.SpeedScale = 0.5

local function memoryFor(instance)
	local memory = instance.wanderMemory
	if not memory then
		memory = {}
		instance.wanderMemory = memory
	end
	return memory
end

function Wander.Score(instance, blackboard): number?
	if blackboard.Target or blackboard.LastKnownPos then
		return nil
	end
	-- Low constant. Comfortably above Idle's 0.01 floor; comfortably below any
	-- real Check score (a fresh stimulus should always win) or Chase.
	return 0.3
end

function Wander.Enter(instance)
	local memory = memoryFor(instance)
	memory.target = nil
	memory.pauseUntil = nil
end

function Wander.Update(instance, dt: number)
	local navigation = instance:GetComponent("Navigation")
	if not navigation then
		return
	end

	local memory = memoryFor(instance)

	if memory.pauseUntil then
		if os.clock() < memory.pauseUntil then
			return
		end
		memory.pauseUntil = nil
		memory.target = nil
	end

	if memory.target then
		local arrived = navigation:MoveTo(memory.target, dt)
		if not arrived then
			return
		end
		memory.pauseUntil = os.clock() + MonsterConstants.DefaultWanderPause
		return
	end

	-- Anchored to SpawnPosition, not the monster's current position -- picking
	-- from "here" would let a long walk drift the whole wander area over time.
	local anchor = instance.blackboard.SpawnPosition or instance.rootPart.Position
	local radius = (instance.config.Navigation and instance.config.Navigation.WanderRadius)
		or MonsterConstants.DefaultWanderRadius

	-- nil means the roll landed against geometry and was pulled back to
	-- nothing worth walking to. Leaving target nil re-rolls next tick, which at
	-- Wander's 0.5s cadence is a pause rather than a stall.
	memory.target = navigation:PickRoamPoint(anchor, radius)
end

function Wander.Exit(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
	local memory = memoryFor(instance)
	memory.target = nil
	memory.pauseUntil = nil
end

return Wander
