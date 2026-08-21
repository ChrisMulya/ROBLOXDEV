-- Investigate the current Investigation channel: a validated destination plus
-- WHY (Visual projection, a heard Trail, or any other Stimulus). Reads
-- Blackboard.InvestigationPosition/Reason/At, written by the Investigation
-- component -- never LastStimulus or LastKnownPos directly. Investigation
-- already enforces "a footstep never becomes a sighting" one level up; Check
-- just consumes its answer. See Investigation's header for the full
-- arbitration rule (newest evidence wins).
--
-- The phase chain BRANCHES on InvestigationReason (blueprint Refinement 2):
--
--   Visual (LOS loss) --
--     losdelay    -- settle ~1s (measured from LoSLostAt) before committing,
--                     a readable "lost you" beat rather than reacting instantly
--     patrolpoint -- relocate to a PatrolPoint continuing the escape route,
--                     found by 360-degree discovery around the projected focus
--     patrolwander-- brief (~5s) roam around that PatrolPoint
--     searchpoint -- walk to a nearby, genuinely relevant SearchPoint
--     scan        -- deliberate slow left/right visual scan at that SearchPoint
--     linger      -- wander the area for a final randomised 4-8s before
--                     giving up and letting Patrol resume
--
--   Trail / Stimulus (heard footstep, camera flash, etc) --
--     travel      -- path directly to the investigation position
--     hold        -- stand still and look around (InvestigationHold)
--     sweep       -- sweep random points within SearchRadius of the position,
--                     pausing at each, until a per-investigation randomised
--                     budget expires
--     searchpoint / scan / linger -- same as above
--
-- Why the branch: a Visual investigation only knows the player was heading
-- SOMEWHERE, not that they are still near LastKnownPos, so travelling to the
-- exact sighting and sweeping around it reads as the monster milling at the
-- corner it lost you at. A Trail/Stimulus investigation has a concrete
-- position worth working directly. searchpoint/scan/linger are shared by
-- both chains -- one localized-investigation tail regardless of how the
-- monster got there.
--
-- Band 0, same as Idle: a visible target (Chase, Band 1) always outranks an
-- investigation, so a stimulus arriving mid-chase never interrupts it. That
-- is the whole "multiple simultaneous stimuli" story for Chase-vs-Check --
-- no extra mechanism, just band precedence already in the Brain. Likewise a
-- newer Trail/Stimulus investigation mid-PatrolPoint-relocation needs no
-- special-case interrupt check: Investigation raises InvestigationAt, Check's
-- restart-on-newer-evidence check (below) fires exactly as it always has, and
-- the branch above picks the new reason's entry phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local PointSelector = require(script.Parent.Parent.Search.PointSelector)
local VisualScan = require(script.Parent.Parent.Behaviors.VisualScan)

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
-- the score would decay with the evidence's age and drop out from under a
-- search that is still in progress: InvestigationWindow/PursuitDuration are
-- short but the phase chain (see header) can run tens of seconds. The
-- freshness window governs whether to START investigating; the phase chain
-- governs when to STOP. Comfortably above Wander's 0.3.
local ACTIVE_UTILITY = 0.8

-- Per-instance bookkeeping Check owns outright -- not a Blackboard key,
-- because nothing outside Check ever needs to read it, and single-writer
-- claims are for keys other components/states legitimately consult.
local function memoryFor(instance)
	local memory = instance.checkMemory
	if not memory then
		-- searchPointCooldowns/patrolPointCooldowns persist across
		-- investigations (the whole instance's lifetime), unlike everything
		-- else beginInvestigation resets -- a checked point should stay
		-- excluded even after the monster gives up and starts a fresh
		-- investigation later.
		memory = { searchPointCooldowns = {}, patrolPointCooldowns = {} }
		instance.checkMemory = memory
	end
	return memory
end

local function perceptionConfig(instance)
	return instance.config.Perception or {}
end

local function investigationConfig(instance)
	return instance.config.Investigation or {}
end

-- SearchPointCooldown lives under Config.Investigation; a helper since
-- multiple call sites (searchpoint stuck, scan finished, Exit-on-interrupt,
-- beginInvestigation's own interrupt cleanup) all need the same duration.
-- Declared here, ahead of beginInvestigation below, rather than in its
-- original position further down the file -- a `local function` is only a
-- valid upvalue for closures defined AFTER it textually; beginInvestigation
-- calling this while it was still declared below would have resolved to a
-- nil global, not this function.
local function cooldownDuration(instance): number
	local cfg = investigationConfig(instance)
	return cfg.InvestigationSearchPointCooldown or MonsterConstants.DefaultInvestigationSearchPointCooldown
end

-- How long a given investigation Reason stays worth grading, mirroring the
-- window Investigation itself already gates candidates against -- kept in
-- sync here only for the recency curve, not for eligibility: eligibility is
-- already decided by whether InvestigationAt exists at all.
local function freshnessWindow(instance, reason: string?): number
	if reason == "Visual" then
		local cfg = investigationConfig(instance)
		local pursuitDuration = instance.config.Stats.PursuitDuration or 0
		local grace = cfg.VisualInvestigationGrace or MonsterConstants.DefaultVisualInvestigationGrace
		return pursuitDuration + grace
	end
	if reason == "Trail" then
		return instance.config.Stats.PursuitDuration or 0
	end
	local cfg = perceptionConfig(instance)
	return cfg.InvestigationWindow or MonsterConstants.DefaultInvestigationWindow
end

-- reason picks the entry phase (blueprint Refinement 2): a Visual
-- investigation settles first, then relocates via PatrolPoint; Trail/
-- Stimulus go straight to travel, as before this refinement.
local function beginInvestigation(instance, navigation, memory, investigationAt: number, reason: string?)
	memory.activeAt = investigationAt
	memory.holdUntil = nil
	memory.searchUntil = nil
	memory.searchPoint = nil
	memory.pauseUntil = nil
	-- SearchPoint / scan / linger bookkeeping. Reset on every entry into a
	-- (re)started investigation. NOT always preceded by Exit -- Check.Update's
	-- mid-investigation restart branch below calls this directly while a scan
	-- or SearchPoint may still be live, so this must do its own cancel/cooldown
	-- rather than assume Exit already did. An orphaned VisualScan never
	-- restores humanoid.AutoRotate on its own -- only Cancel()/Tick-completion
	-- do -- so skipping this left the monster permanently welded to whatever
	-- heading the interrupted scan last held, blind in its direction of travel.
	memory.searchPointsUsed = 0

	if memory.scan then
		memory.scan:Cancel()
	end
	memory.scan = nil

	if memory.currentSearchPoint then
		memory.searchPointCooldowns[memory.currentSearchPoint] = os.clock() + cooldownDuration(instance)
	end
	memory.currentSearchPoint = nil
	memory.currentSearchPointPosition = nil

	memory.lingerUntil = nil
	memory.lingerCenter = nil
	-- PatrolPoint relocation bookkeeping (Visual only).
	memory.patrolPointTarget = nil
	memory.patrolPointPosition = nil
	memory.patrolPointAttempts = 0
	memory.patrolPointDeadline = nil
	memory.patrolWanderUntil = nil

	if reason == "Visual" then
		local cfg = investigationConfig(instance)
		local delay = cfg.LoSLostSettleDelay or MonsterConstants.DefaultLoSLostSettleDelay
		memory.phase = "losdelay"
		-- Load-bearing: for a Visual candidate, Investigation's
		-- _visualCandidate stamps EvidenceAt = LoSLostAt exactly
		-- (Investigation.luau), so this measures from the TRUE loss instant,
		-- not from whenever Check happened to enter this tick.
		memory.losDelayUntil = investigationAt + delay
		-- Required, not cosmetic: Chase.Exit is empty and Check.Enter does
		-- not otherwise stop, so MoveDirection would persist from the
		-- pursuit and the monster would glide through its own pause
		-- (HumanoidPathLocomotion's MoveTo contract).
		if navigation then
			navigation:Stop()
		end
	else
		memory.phase = "travel"
	end
end

local function patrolPointCooldownDuration(instance): number
	local cfg = investigationConfig(instance)
	return cfg.InvestigationPatrolPointCooldown or MonsterConstants.DefaultInvestigationPatrolPointCooldown
end

-- Cools down the failed/unreachable PatrolPoint, counts the attempt, and
-- either stays in "patrolpoint" to retry (patrolPointTarget nil triggers
-- reselection next Update) or -- once PatrolPointSelectAttempts is exhausted
-- -- falls through to SearchPoint investigation directly from wherever the
-- monster currently is. Never loops unboundedly (blueprint R2.8 #13).
local function patrolPointFailed(instance, memory, now: number)
	if memory.patrolPointTarget then
		memory.patrolPointCooldowns[memory.patrolPointTarget] = now + patrolPointCooldownDuration(instance)
	end
	memory.patrolPointTarget = nil
	memory.patrolPointPosition = nil
	memory.patrolPointDeadline = nil
	memory.patrolPointAttempts += 1

	local cfg = investigationConfig(instance)
	local maxAttempts = cfg.PatrolPointSelectAttempts or MonsterConstants.DefaultPatrolPointSelectAttempts
	if memory.patrolPointAttempts >= maxAttempts then
		memory.phase = "searchpoint"
	end
end

-- Enters the terminal wander-then-leave phase (blueprint §4's "enter Wander"
-- beat), implemented here rather than as a real state transition -- see the
-- Deviations section: Wander (0.3) can never outscore Patrol (0.35), so a
-- genuine transition would need a second authority over Wander's
-- eligibility. This phase reuses the sweep phase's own PickRoamPoint
-- primitive, just centred differently and for a shorter, terminal budget.
local function beginLinger(instance, memory, now: number, center: Vector3)
	local cfg = investigationConfig(instance)
	local minSeconds = cfg.PostSearchLingerMin or MonsterConstants.DefaultPostSearchLingerMin
	local maxSeconds = cfg.PostSearchLingerMax or MonsterConstants.DefaultPostSearchLingerMax
	memory.phase = "linger"
	memory.lingerUntil = now + minSeconds + math.random() * math.max(maxSeconds - minSeconds, 0)
	memory.lingerCenter = center
	memory.searchPoint = nil
	memory.pauseUntil = nil
end

function Check.Score(instance, blackboard): number?
	local investigationAt = blackboard.InvestigationAt
	if not investigationAt then
		return nil
	end

	local memory = memoryFor(instance)
	if memory.investigatedAt and investigationAt <= memory.investigatedAt then
		-- Already searched this one out. A newer investigation (strictly
		-- greater InvestigationAt) clears this the moment it arrives; until
		-- then there is nothing new to check.
		return nil
	end

	-- Mid-investigation of THIS evidence: stay eligible regardless of its age.
	if memory.phase and memory.activeAt == investigationAt then
		return ACTIVE_UTILITY
	end

	local window = freshnessWindow(instance, blackboard.InvestigationReason)
	local age = os.clock() - investigationAt
	if window <= 0 or age > window then
		return nil
	end

	-- Graded by recency x strength, same shape as the Stimulus aggression
	-- modifier: a strong, brand-new lead is more worth dropping Wander for
	-- than a weak, aging one. Visual/Trail leads are concrete (the monster
	-- either saw or heard something specific), so they grade at full
	-- strength; only a generic Stimulus carries its own Strength.
	local recency = 1 - (age / window)
	local strength = 1
	if blackboard.InvestigationReason == "Stimulus" and blackboard.LastStimulus then
		strength = math.clamp(blackboard.LastStimulus.Strength or 1, 0, 1)
	end
	return math.clamp(recency * strength, 0, 1)
end

function Check.Enter(instance)
	-- Restarts the investigation from the top on every entry, including a
	-- re-entry after Chase interrupted one. A monster that broke off to chase
	-- someone and lost them should search again from the top, not resume a
	-- half-expired budget.
	local blackboard = instance.blackboard
	local investigationAt = blackboard.InvestigationAt
	if investigationAt then
		local navigation = instance:GetComponent("Navigation")
		beginInvestigation(instance, navigation, memoryFor(instance), investigationAt, blackboard.InvestigationReason)
	end
end

function Check.Update(instance, dt: number)
	local blackboard = instance.blackboard
	local investigationAt = blackboard.InvestigationAt
	local position = blackboard.InvestigationPosition
	local navigation = instance:GetComponent("Navigation")
	if not investigationAt or not position or not navigation then
		return
	end

	local memory = memoryFor(instance)
	local config = perceptionConfig(instance)
	local now = os.clock()

	-- A NEWER investigation interrupts whatever phase is running and restarts
	-- at the new position/reason. Investigation only ever raises
	-- InvestigationAt when it commits genuinely new evidence, so a strictly
	-- greater value means exactly that -- this is also what makes a Trail/
	-- Stimulus investigation arriving mid-PatrolPoint-relocation "just work":
	-- no special-case interrupt check needed, the branch in beginInvestigation
	-- picks the new reason's entry phase.
	if memory.activeAt == nil or investigationAt > memory.activeAt then
		beginInvestigation(instance, navigation, memory, investigationAt, blackboard.InvestigationReason)
	end

	-- Finished, waiting for the Brain (up to one 0.2s tick) to score Check
	-- down and move on. Doing anything here would restart the phases.
	if memory.investigatedAt and memory.activeAt and memory.investigatedAt >= memory.activeAt then
		return
	end

	if memory.phase == "losdelay" then
		-- Visual only (blueprint Refinement 2 R2.2): a settle beat before
		-- committing to a PatrolPoint. Not a stimulus -- nothing is published
		-- to StimulusBus or injected into Perception; this is a phase timer
		-- over information Targeting already wrote. navigation:Stop() already
		-- ran once, in beginInvestigation, on entry.
		if now >= memory.losDelayUntil then
			memory.phase = "patrolpoint"
		end
		return
	end

	if memory.phase == "travel" then
		-- Reason is always Trail or Stimulus here -- a Visual investigation
		-- enters at "losdelay" and never reaches "travel" (Refinement 2).
		local arrived, stuck = navigation:MoveTo(position, dt)
		if stuck then
			-- Can't physically reach it. Give up on THIS investigation the
			-- same way a completed one ends, so Wander or Patrol picks a real
			-- destination from where the monster is now rather than grinding
			-- on the same wall for the rest of Check's eligibility window.
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

	if memory.phase == "patrolpoint" then
		if not memory.patrolPointTarget then
			local investigation = instance:GetComponent("Investigation")
			local directionInfo = investigation and investigation:GetDirectionInfo()
			local rootPart = instance.rootPart
			local origin = rootPart and rootPart.Position
			if not origin then
				memory.phase = "searchpoint"
				return
			end

			-- Focus is InvestigationPosition -- the projected escape point --
			-- so discovery is centred on where the player WENT, not on the
			-- monster (blueprint R2.4). 360 degrees: PointSelector.
			-- SelectPatrolPoint passes no cone, so a point behind the monster
			-- is still a candidate, just ranked lower.
			local part, resolved = PointSelector.SelectPatrolPoint(
				instance, navigation, origin, position, directionInfo, memory)
			if not part then
				-- No PatrolPoint reachable/relevant (blueprint R2.8 #1): fall
				-- through to SearchPoint investigation directly.
				memory.phase = "searchpoint"
				return
			end

			memory.patrolPointTarget = part
			memory.patrolPointPosition = resolved
			local cfg = investigationConfig(instance)
			local timeout = cfg.PatrolPointTravelTimeout or MonsterConstants.DefaultPatrolPointTravelTimeout
			memory.patrolPointDeadline = now + timeout
		end

		-- Anti-stall backstop (blueprint R2.8 #13): displacement-based stuck
		-- detection can miss a monster that is moving but not actually making
		-- progress (slow circling); a hard deadline on the whole phase can't.
		if memory.patrolPointDeadline and now >= memory.patrolPointDeadline then
			patrolPointFailed(instance, memory, now)
			return
		end

		local arrived, stuck = navigation:MoveTo(memory.patrolPointPosition, dt)
		if stuck then
			patrolPointFailed(instance, memory, now)
			return
		end
		if arrived then
			local cfg = investigationConfig(instance)
			local minSeconds = cfg.PatrolPointWanderMin or MonsterConstants.DefaultPatrolPointWanderMin
			local maxSeconds = cfg.PatrolPointWanderMax or MonsterConstants.DefaultPatrolPointWanderMax
			memory.phase = "patrolwander"
			memory.patrolWanderUntil = now + minSeconds + math.random() * math.max(maxSeconds - minSeconds, 0)
		end
		return
	end

	if memory.phase == "patrolwander" then
		-- The "~5 second" investigation at the PatrolPoint (blueprint §4,
		-- extended to R2). Reuses the same PickRoamPoint/searchPoint/
		-- pauseUntil primitive as sweep/linger -- never active concurrently
		-- with those, since phases are mutually exclusive.
		if now >= memory.patrolWanderUntil then
			memory.phase = "searchpoint"
			return
		end

		if memory.pauseUntil and now < memory.pauseUntil then
			return
		end

		if not memory.searchPoint then
			local cfg = investigationConfig(instance)
			local radius = cfg.PatrolPointWanderRadius or MonsterConstants.DefaultPatrolPointWanderRadius
			memory.searchPoint = navigation:PickRoamPoint(memory.patrolPointPosition or position, radius)
			memory.pauseUntil = nil
			if not memory.searchPoint then
				return
			end
		end

		local arrived, stuck = navigation:MoveTo(memory.searchPoint, dt)
		if stuck then
			-- Couldn't physically get there. Drop the point and re-roll next
			-- tick rather than grinding on it for the rest of the budget --
			-- same recovery Wander uses. No pause: the monster has already
			-- been standing still for the whole stuck window.
			memory.searchPoint = nil
		elseif arrived then
			memory.searchPoint = nil
			memory.pauseUntil = now + (config.SearchPause or MonsterConstants.DefaultSearchPause)
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
			memory.phase = "sweep"
			memory.searchUntil = now + minSeconds + math.random() * math.max(maxSeconds - minSeconds, 0)
		end
		return
	end

	if memory.phase == "sweep" then
		if now >= memory.searchUntil then
			-- Sweep budget spent. Move on to a relevant nearby SearchPoint if
			-- the investigation hasn't already used its allowance; otherwise
			-- go straight to lingering. Neither branch stamps investigatedAt
			-- -- SearchPoint/scan/linger are all still part of the SAME
			-- investigation (memory.activeAt), only Score sees ACTIVE_UTILITY
			-- either way.
			local cfg = investigationConfig(instance)
			local enabled = cfg.SearchPointEnabled
			if enabled == nil then
				enabled = MonsterConstants.DefaultSearchPointEnabled
			end
			local perInvestigation = cfg.SearchPointsPerInvestigation
				or MonsterConstants.DefaultSearchPointsPerInvestigation
			if enabled and memory.searchPointsUsed < perInvestigation then
				memory.phase = "searchpoint"
			else
				beginLinger(instance, memory, now, position)
			end
			return
		end

		if memory.pauseUntil and now < memory.pauseUntil then
			return
		end

		if not memory.searchPoint then
			-- nil means the roll landed against geometry; leaving searchPoint
			-- nil re-rolls next tick rather than sending the monster into a
			-- wall.
			memory.searchPoint = navigation:PickRoamPoint(
				position,
				config.SearchRadius or MonsterConstants.DefaultSearchRadius
			)
			memory.pauseUntil = nil
			if not memory.searchPoint then
				return
			end
		end

		local arrived, stuck = navigation:MoveTo(memory.searchPoint, dt)
		if stuck then
			-- See the patrolwander phase: drop and re-roll rather than grind.
			memory.searchPoint = nil
		elseif arrived then
			memory.searchPoint = nil
			memory.pauseUntil = now + (config.SearchPause or MonsterConstants.DefaultSearchPause)
		end
		return
	end

	if memory.phase == "searchpoint" then
		-- Focus moves to the PatrolPoint once one was reached (blueprint
		-- R2.5), so discovery centres on where the monster actually is now,
		-- not on the original (possibly distant) InvestigationPosition.
		local focus = memory.patrolPointPosition or position

		if not memory.currentSearchPoint then
			local rootPart = instance.rootPart
			local origin = rootPart and rootPart.Position
			if not origin then
				beginLinger(instance, memory, now, focus)
				return
			end

			-- The directional cone is dropped once a PatrolPoint was used
			-- (blueprint R2.5): it's anchored at LastKnownPos, and after
			-- relocating, a perfectly good adjacent SearchPoint can easily
			-- fall outside a 120-degree wedge measured from a position the
			-- monster has since left. Relevance is enforced locally instead,
			-- by FocusRadius + reachability + occlusion tier.
			local directionInfo = nil
			if not memory.patrolPointPosition then
				local investigation = instance:GetComponent("Investigation")
				directionInfo = investigation and investigation:GetDirectionInfo()
			end

			local part, resolved = PointSelector.SelectSearchPoint(
				instance, navigation, origin, focus, directionInfo, memory)
			if not part then
				-- Nothing relevant survived the gates -- counts as an
				-- attempt (blueprint §7 "no SearchPoint available") so a
				-- SearchPointsPerInvestigation > 1 config doesn't loop
				-- forever re-querying an empty result.
				memory.searchPointsUsed += 1
				beginLinger(instance, memory, now, focus)
				return
			end

			memory.currentSearchPoint = part
			memory.currentSearchPointPosition = resolved
		end

		local arrived, stuck = navigation:MoveTo(memory.currentSearchPointPosition, dt)
		if stuck then
			-- Became invalid mid-travel (blueprint §7): cool it down, count
			-- the attempt, fall back to lingering from wherever this left off.
			memory.searchPointCooldowns[memory.currentSearchPoint] = now + cooldownDuration(instance)
			memory.searchPointsUsed += 1
			local center = memory.currentSearchPointPosition
			memory.currentSearchPoint = nil
			memory.currentSearchPointPosition = nil
			beginLinger(instance, memory, now, center)
			return
		end
		if arrived then
			memory.phase = "scan"
			memory.scan = VisualScan.new(instance, {})
		end
		return
	end

	if memory.phase == "scan" then
		-- Detection during the scan needs no extra code here: Perception,
		-- Targeting and Investigation all keep ticking as normal components.
		-- If a target gets acquired, Investigation clears its own keys, this
		-- state's Score drops, and the Brain switches to Chase (Band 1)
		-- before this state's Update runs again -- Check.Exit cancels the
		-- scan (restoring AutoRotate) on the way out.
		local scan = memory.scan
		if not scan then
			beginLinger(instance, memory, now, memory.currentSearchPointPosition or position)
			return
		end

		if scan:Tick(dt) then
			memory.scan = nil
			memory.searchPointsUsed += 1
			memory.searchPointCooldowns[memory.currentSearchPoint] = now + cooldownDuration(instance)
			local center = memory.currentSearchPointPosition
			memory.currentSearchPoint = nil
			memory.currentSearchPointPosition = nil
			beginLinger(instance, memory, now, center)
		end
		return
	end

	if memory.phase == "linger" then
		if now >= memory.lingerUntil then
			-- Terminal: marks the investigation this run was actually ABOUT
			-- (activeAt), never whatever is current -- an interrupt would
			-- have restarted the phases above, so those can only differ if
			-- something went wrong. Patrol resumes once Score drops.
			memory.investigatedAt = memory.activeAt
			memory.phase = nil
			return
		end

		if memory.pauseUntil and now < memory.pauseUntil then
			return
		end

		if not memory.searchPoint then
			local cfg = investigationConfig(instance)
			local radius = cfg.PostSearchLingerRadius or MonsterConstants.DefaultPostSearchLingerRadius
			memory.searchPoint = navigation:PickRoamPoint(memory.lingerCenter or position, radius)
			memory.pauseUntil = nil
			if not memory.searchPoint then
				return
			end
		end

		local arrived, stuck = navigation:MoveTo(memory.searchPoint, dt)
		if stuck then
			-- See the patrolwander phase: drop and re-roll rather than grind.
			memory.searchPoint = nil
		elseif arrived then
			memory.searchPoint = nil
			memory.pauseUntil = now + (config.SearchPause or MonsterConstants.DefaultSearchPause)
		end
		return
	end
end

function Check.Exit(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end

	local memory = memoryFor(instance)

	-- An interrupted scan must restore AutoRotate -- nothing else will.
	if memory.scan then
		memory.scan:Cancel()
		memory.scan = nil
	end

	-- Cools down a SearchPoint that was being travelled to or scanned when
	-- interrupted (blueprint §7's "SearchPoint becomes invalid while
	-- moving"), so re-entering Check right after doesn't immediately re-pick
	-- the same point. A point already stamped by the searchpoint/scan phases
	-- themselves has already cleared this field, so this only fires on a
	-- genuine interruption.
	if memory.currentSearchPoint then
		memory.searchPointCooldowns[memory.currentSearchPoint] = os.clock() + cooldownDuration(instance)
		memory.currentSearchPoint = nil
		memory.currentSearchPointPosition = nil
	end

	-- Same idea for an interrupted PatrolPoint relocation (blueprint R2.8 #8
	-- "player visible while travelling to the PatrolPoint"): a point already
	-- resolved by the patrolpoint phase itself (arrived, or patrolPointFailed)
	-- has already cleared this field, so this only fires on a genuine
	-- interruption mid-travel.
	if memory.patrolPointTarget then
		memory.patrolPointCooldowns[memory.patrolPointTarget] = os.clock() + patrolPointCooldownDuration(instance)
		memory.patrolPointTarget = nil
		memory.patrolPointPosition = nil
	end

	-- investigatedAt is NOT set here: an interruption (Chase taking over) means
	-- this investigation was never actually finished, so it stays eligible
	-- rather than being marked handled early. phase is left set so Score keeps
	-- it eligible; Enter restarts the phases from travel on the way back in.
	memory.searchPoint = nil
	memory.pauseUntil = nil
end

return Check
