-- Investigate the last thing Perception heard or saw flash. One state for
-- both stimulus kinds -- "walk to a remembered position and search it" is the
-- same behaviour whether a footstep or a camera flash produced the position
-- (blueprint D4). If flash investigation ever needs to differ from footstep
-- investigation, that is a parameter on this state, not a new one.
--
-- Three phases, driven by memory.phase:
--
--   travel -- path to the stimulus position
--   hold   -- stand still and look around (InvestigationHold)
--   search -- sweep random points within SearchRadius of the stimulus, pausing
--             at each, until a per-investigation randomised budget expires
--
-- The search phase exists because travel + a short hold read as the monster
-- touching the spot and instantly losing interest. Randomising the budget per
-- investigation keeps repeat visits from playing out on a learnable timer.
--
-- Band 0, same as Idle: a visible target (Chase, Band 1) always outranks an
-- investigation, so a stimulus arriving mid-chase never interrupts it. That
-- is the whole "multiple simultaneous stimuli" story for Chase-vs-Check --
-- no extra mechanism, just band precedence already in the Brain.
--
-- Deliberately reads Blackboard.LastStimulus, never LastKnownPos. LastKnownPos
-- is Targeting's key and means "I SAW someone here" -- Chase pursues it.
-- Writing a heard position there would silently promote a footstep to a
-- sighting. Two keys, two meanings; Check only ever touches its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local Check = {}

Check.Name = "Check"
Check.Band = 0
Check.Interruptible = true
Check.TickRate = 0.1
-- Between wandering (0.5) and pursuit (1.0). Investigating is purposeful --
-- it heard something -- but it has not seen anyone, so charging at full chase
-- speed would spend the difference between "alerted" and "hunting" that the
-- speed change exists to communicate.
Check.SpeedScale = 0.75

-- Sustained utility while an investigation is actually running. Without this
-- the score would decay with the stimulus's age and drop out from under a
-- search that is still in progress: InvestigationWindow is 8s but a search can
-- run 20s+, so the monster would abandon its own sweep partway through. The
-- freshness window governs whether to START investigating; the search budget
-- governs when to STOP. Comfortably above Wander's 0.3.
local ACTIVE_UTILITY = 0.8

-- Per-instance bookkeeping Check owns outright -- not a Blackboard key,
-- because nothing outside Check ever needs to read it, and single-writer
-- claims are for keys other components/states legitimately consult.
local function memoryFor(instance)
	local memory = instance.checkMemory
	if not memory then
		memory = {}
		instance.checkMemory = memory
	end
	return memory
end

local function perceptionConfig(instance)
	return instance.config.Perception or {}
end

local function beginInvestigation(memory, record)
	memory.activeAt = record.Timestamp
	memory.phase = "travel"
	memory.holdUntil = nil
	memory.searchUntil = nil
	memory.searchPoint = nil
	memory.pauseUntil = nil
end


function Check.Score(instance, blackboard): number?
	local record = blackboard.LastStimulus
	if not record then
		return nil
	end

	local memory = memoryFor(instance)
	if memory.investigatedAt and record.Timestamp <= memory.investigatedAt then
		-- Already searched this one out. A newer stimulus (strictly greater
		-- Timestamp -- Perception's newest-wins) clears this the moment it
		-- arrives; until then there is nothing new to check.
		return nil
	end

	-- Mid-investigation of THIS stimulus: stay eligible regardless of its age.
	if memory.phase and memory.activeAt == record.Timestamp then
		return ACTIVE_UTILITY
	end

	local config = perceptionConfig(instance)
	local window = config.InvestigationWindow or MonsterConstants.DefaultInvestigationWindow
	local age = os.clock() - record.Timestamp
	if age > window then
		return nil
	end

	-- Graded by recency x strength, same shape as the Stimulus aggression
	-- modifier: a strong, brand-new stimulus is more worth dropping Wander for
	-- than a weak, aging one.
	local recency = 1 - (age / window)
	local strength = math.clamp(record.Strength or 1, 0, 1)
	return math.clamp(recency * strength, 0, 1)
end

function Check.Enter(instance)
	-- Restarts the investigation from travel on every entry, including a
	-- re-entry after Chase interrupted one. A monster that broke off to chase
	-- someone and lost them should search the noise again from the top, not
	-- resume a half-expired budget.
	local record = instance.blackboard.LastStimulus
	if record then
		beginInvestigation(memoryFor(instance), record)
	end
end

function Check.Update(instance, dt: number)
	local blackboard = instance.blackboard
	local record = blackboard.LastStimulus
	local navigation = instance:GetComponent("Navigation")
	if not record or not navigation then
		return
	end

	local memory = memoryFor(instance)
	local config = perceptionConfig(instance)
	local now = os.clock()

	-- A FRESHER stimulus interrupts whatever phase is running and restarts at
	-- the new position. Perception only ever raises LastStimulus.Timestamp, so
	-- a strictly greater one means genuinely new evidence.
	if memory.activeAt == nil or record.Timestamp > memory.activeAt then
		beginInvestigation(memory, record)
	end

	-- Finished, waiting for the Brain (up to one 0.2s tick) to score Check
	-- down and move on. Doing anything here would restart the phases.
	if memory.investigatedAt and memory.activeAt and memory.investigatedAt >= memory.activeAt then
		return
	end

	if memory.phase == "travel" then
		local arrived, stuck = navigation:MoveTo(record.Position, dt)
		if stuck then
			-- Can't physically reach the stimulus position -- searching
			-- nearby wouldn't help, since PickRoamPoint validates points
			-- around record.Position in isolation, not reachability from
			-- wherever the monster is actually stuck. Give up on THIS
			-- investigation the same way a completed one ends, so Wander or
			-- Patrol picks a real destination from where the monster is now
			-- rather than grinding on the same wall for the rest of Check's
			-- eligibility window.
			memory.investigatedAt = memory.activeAt
			memory.phase = nil
			return
		end
		if arrived then
			memory.phase = "hold"
			memory.holdUntil = now
				+ (config.InvestigationHold or MonsterConstants.DefaultInvestigationHold)
		end
		return
	end

	if memory.phase == "hold" then
		-- Deliberately does not call Navigation:Stop() -- MoveTo already
		-- stopped issuing commands on arrival, and Stop() would reset the
		-- Arrived edge for no reason.
		if now >= memory.holdUntil then
			local minSeconds = config.SearchDurationMin or MonsterConstants.DefaultSearchDurationMin
			local maxSeconds = config.SearchDurationMax or MonsterConstants.DefaultSearchDurationMax
			memory.phase = "search"
			memory.searchUntil = now + minSeconds + math.random() * math.max(maxSeconds - minSeconds, 0)
		end
		return
	end

	-- search
	if now >= memory.searchUntil then
		-- Marks the stimulus this investigation was actually ABOUT (activeAt),
		-- never whatever is current -- an interrupt would have restarted the
		-- phases above, so those can only differ if something went wrong.
		memory.investigatedAt = memory.activeAt
		memory.phase = nil
		return
	end

	if memory.pauseUntil and now < memory.pauseUntil then
		return
	end

	if not memory.searchPoint then
		-- nil means the roll landed against geometry; leaving searchPoint nil
		-- re-rolls next tick rather than sending the monster into a wall.
		memory.searchPoint = navigation:PickRoamPoint(
			record.Position,
			config.SearchRadius or MonsterConstants.DefaultSearchRadius
		)
		memory.pauseUntil = nil
		if not memory.searchPoint then
			return
		end
	end

	if navigation:MoveTo(memory.searchPoint, dt) then
		memory.searchPoint = nil
		memory.pauseUntil = now + (config.SearchPause or MonsterConstants.DefaultSearchPause)
	end
end

function Check.Exit(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end

	-- investigatedAt is NOT set here: an interruption (Chase taking over) means
	-- this stimulus was never actually searched, so it stays eligible rather
	-- than being marked handled early. phase is left set so Score keeps it
	-- eligible; Enter restarts the phases from travel on the way back in.
	local memory = memoryFor(instance)
	memory.searchPoint = nil
	memory.pauseUntil = nil
end

return Check
