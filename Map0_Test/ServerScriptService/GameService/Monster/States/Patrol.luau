-- The unalerted default: walk a hand-placed PatrolPoint network, choosing a
-- real direction at junctions, never immediately reversing, occasionally
-- detouring into a nearby SearchPoint before resuming. Blueprint §20.
--
-- One state, three internal phases (memory.phase), same shape Check already
-- uses for travel/hold/search:
--
--   route   -- walking node to node along the PatrolPoint network
--   divert  -- walking to a SearchPoint chosen mid-route
--   search  -- sweeping around that SearchPoint on a randomised budget
--
-- A separate Search state was considered and rejected: Brain.candidates is
-- built once in Brain.new and never rebuilt, so two Band-0 states that are
-- really one behaviour would need arbitration logic that buys nothing over
-- an internal phase, which Check already proves works.
--
-- Config.Navigation.PatrolRoute (the old ordered-array route) still WINS if a
-- monster's config declares one -- nothing authors it today, but nothing
-- deletes a working feature out from under a config that might. See
-- routeFor/updateAuthoredRoute below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local PatrolGraph = require(script.Parent.Parent.PatrolGraph)

local Patrol = {}

Patrol.Name = "Patrol"
Patrol.Band = 0
Patrol.Interruptible = true
Patrol.TickRate = 0.5
-- Same reasoning as Wander: an unalerted monster on its route should not move
-- at pursuit speed. Per-monster override: States.Patrol.SpeedScale.
Patrol.SpeedScale = 0.5

-- Comfortably above Wander's 0.3 -- a monster with both capabilities patrols
-- and only wanders when the graph has nothing to offer it. Constant across
-- every phase (route/divert/search): unlike Check, there is no stimulus age
-- to decay against, and Brain Hysteresis (1.1) already prevents flapping
-- against Wander at a near-tied score.
local PATROL_UTILITY = 0.35

-- Selection retries bounded per tick: a freshly chosen candidate can turn out
-- unreachable only once resolved, so this bounds how many bad candidates one
-- Update call will burn through before giving up until next tick. Candidate
-- counts are small (a handful of nearby points), so this is cheap.
local MAX_SELECT_ATTEMPTS = 6

local function memoryFor(instance)
	local memory = instance.patrolMemory
	if not memory then
		memory = {
			phase = "route",
			history = {},
			-- Temporarily blocked PatrolPoints -- [BasePart] = expiryClock.
			-- Written on LegTimeout/stuck instead of history, so a leg the
			-- monster never completed doesn't evict a genuine visit.
			deferred = {},
			resolved = {},
			rolledThisLeg = {},
			searchCooldowns = {},
		}
		instance.patrolMemory = memory
	end
	return memory
end

local function patrolCfg(instance)
	return (instance.config.Navigation and instance.config.Navigation.Patrol) or {}
end

-- The pause CHANCE reads from Stats, unlike every other patrol knob, which
-- lives under Navigation.Patrol. That asymmetry is deliberate: Stats is the
-- only table evolution can mutate, and an evolved monster is meant to stop
-- loitering. A tier declaring `PatrolPauseChance = 0` multiplies this to zero
-- through the existing Stats pipeline, so "never idles after 3 AM" needs no
-- new evolution machinery -- which matters, because the non-Stats half of the
-- tier schema is unimplemented (see plans/EvolutionPlan.md).
--
-- The durations stay under Navigation.Patrol: nothing wants to evolve them,
-- and putting a value in Stats that no tier ever touches would imply otherwise.
local function pauseChanceFor(instance, cfg): number
	local stat = instance.config.Stats.PatrolPauseChance
	if type(stat) == "number" then
		return stat
	end
	return cfg.PointPauseChance or MonsterConstants.DefaultPatrolPointPauseChance
end

----------------------------------------------------------------------------
-- Legacy authored-route path (config.Navigation.PatrolRoute). Unchanged from
-- pre-Phase-F Patrol -- kept verbatim so an existing config that declares a
-- route is unaffected. See the file header note.
----------------------------------------------------------------------------

local function authoredRoute(instance): { any }?
	local navigation = instance.config.Navigation
	local route = navigation and navigation.PatrolRoute
	if route and #route > 0 then
		return route
	end
	return nil
end

local function positionOf(waypoint): Vector3
	if typeof(waypoint) == "Vector3" then
		return waypoint
	end
	return waypoint.Position
end

local function resolveAuthoredPoint(instance, navigation, route, index): Vector3?
	local memory = memoryFor(instance)
	memory.authoredResolved = memory.authoredResolved or {}
	local cached = memory.authoredResolved[index]
	if cached ~= nil then
		return cached or nil
	end

	local raw = positionOf(route[index])
	local resolved = navigation:ResolveReachable(raw)
	if not resolved then
		warn(("Patrol: '%s' authored route waypoint %d at %s has no reachable ground -- skipping it")
			:format(instance.monsterId, index, tostring(raw)))
	end

	memory.authoredResolved[index] = resolved or false
	return resolved
end

local function updateAuthoredRoute(instance, navigation, route, dt: number)
	local memory = memoryFor(instance)
	memory.authoredIndex = memory.authoredIndex or 1

	local target
	for _ = 1, #route do
		if memory.authoredIndex > #route then
			memory.authoredIndex = 1
		end
		target = resolveAuthoredPoint(instance, navigation, route, memory.authoredIndex)
		if target then
			break
		end
		memory.authoredIndex += 1
	end

	if not target then
		return
	end

	local arrived, stuck = navigation:MoveTo(target, dt)
	if stuck then
		-- Same treatment as the graph route below: skip past it rather than
		-- grinding, and let it be retried on the next lap once whatever
		-- blocked it (a closed door, a player body-block) has cleared.
		memory.authoredIndex += 1
		return
	end

	if arrived then
		memory.authoredIndex += 1
		if memory.authoredIndex > #route then
			memory.authoredIndex = 1
		end
	end
end

----------------------------------------------------------------------------
-- Graph-driven path (Phase F).
----------------------------------------------------------------------------

-- Points hard-excluded for THIS instance: unreachable within their retry
-- window, temporarily deferred (stuck/timeout) within their TTL, plus the
-- point it is currently standing on. Rebuilt per selection call rather than
-- maintained incrementally: selection runs once per leg (on arrival), not
-- per tick, so the cost is bounded by legs walked, not ticks elapsed.
--
-- TTLs are swept HERE rather than lazily on read, so an expired entry stops
-- being excluded the moment selection next runs instead of lingering until
-- something else happens to touch it.
local function badPointSet(cfg, memory)
	local now = os.clock()
	local bad = {}

	local retryAfter = cfg.UnreachableRetryAfter or MonsterConstants.DefaultPatrolUnreachableRetryAfter
	for part, cached in pairs(memory.resolved) do
		if typeof(cached) == "table" then
			if now - cached.failedAt < retryAfter then
				bad[part] = true
			else
				memory.resolved[part] = nil
			end
		end
	end

	for part, expiry in pairs(memory.deferred) do
		if now < expiry then
			bad[part] = true
		else
			memory.deferred[part] = nil
		end
	end

	if memory.anchorPoint then
		bad[memory.anchorPoint] = true
	end
	return bad
end

-- Heading is the direction of TRAVEL, not the model's facing -- LookVector
-- rotates continuously as the Humanoid steers around corners and would make
-- junction classification jitter mid-leg, and 360-degree PatrolPoint
-- awareness means selection must never depend on facing at all, not even as
-- a fallback. Returns a nil heading when there is no previous point to
-- derive travel direction from (the very first selection after spawn);
-- callers pick uniformly at random in that case rather than inventing a
-- direction. This does remove the old "spawn marker rotation seeds the
-- first patrol direction" authoring lever -- see blueprint Deviations.
local function currentOriginAndHeading(instance, memory): (Vector3, Vector3?)
	local originPart = memory.anchorPoint
	local originPos = originPart and originPart.Position or instance.rootPart.Position

	if originPart and memory.previousAnchor then
		local delta = originPart.Position - memory.previousAnchor.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude > 1e-3 then
			return originPos, flat.Unit
		end
	end

	return originPos, nil
end

local function closestOf(points: { BasePart }, originPos: Vector3): BasePart?
	local best, bestDist = nil, math.huge
	for _, part in ipairs(points) do
		local dist = (part.Position - originPos).Magnitude
		if dist < bestDist then
			best, bestDist = part, dist
		end
	end
	return best
end

-- Signed bearing in degrees, (-180, 180], of `part` from `originPos` relative
-- to `heading`: 0 is straight ahead, positive is right (matches `right =
-- heading:Cross(Vector3.yAxis)` below), negative is left. nil if the
-- candidate is (numerically) on top of originPos and has no meaningful
-- direction at all.
local function bearingOf(originPos: Vector3, heading: Vector3, part: BasePart): number?
	local delta = part.Position - originPos
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude <= 1e-3 then
		return nil
	end
	local toCandidate = flat.Unit
	local angle = math.deg(math.acos(math.clamp(heading:Dot(toCandidate), -1, 1)))
	local right = heading:Cross(Vector3.yAxis)
	if right:Dot(toCandidate) < 0 then
		angle = -angle
	end
	return angle
end

-- Sorts candidates by signed bearing and cuts into direction clusters
-- wherever the gap to the next candidate (circularly, wrapping past +-180)
-- exceeds DirectionSplitDegrees. Clusters wider than DirectionMaxSpanDegrees
-- are then split at their own largest internal gap, so a fan of points
-- spanning a wide arc doesn't read as one direction. Replaces the old fixed
-- forward/left/right sectors: a T-junction still yields two clusters (50/50),
-- a corridor still yields one, but two genuinely separate branches landing on
-- the same side of `heading` no longer collapse into a single choice.
local function clusterByBearing(cfg, entries: { { part: BasePart, bearing: number } })
	table.sort(entries, function(a, b)
		return a.bearing < b.bearing
	end)
	local n = #entries
	if n <= 1 then
		return { entries }
	end

	local splitDeg = cfg.DirectionSplitDegrees or MonsterConstants.DefaultPatrolDirectionSplitDegrees
	local maxSpanDeg = cfg.DirectionMaxSpanDegrees or MonsterConstants.DefaultPatrolDirectionMaxSpanDegrees

	local function gapAfter(i: number): number
		local nextBearing = (i < n) and entries[i + 1].bearing or (entries[1].bearing + 360)
		return nextBearing - entries[i].bearing
	end

	-- Rotate the traversal start to just after a real cut, so no cluster is
	-- artificially split by where the sorted array happens to begin/end. If
	-- no gap anywhere exceeds the threshold, every point is mutually close
	-- around the whole circle and startIndex stays 1 -- one cluster.
	local startIndex = 1
	for i = 1, n do
		if gapAfter(i) > splitDeg then
			startIndex = (i % n) + 1
			break
		end
	end

	local clusters = { {} }
	for offset = 0, n - 1 do
		local idx = ((startIndex - 1 + offset) % n) + 1
		table.insert(clusters[#clusters], entries[idx])
		if offset < n - 1 and gapAfter(idx) > splitDeg then
			table.insert(clusters, {})
		end
	end

	-- Split over-wide clusters at their largest internal gap. Gaps are
	-- recomputed per cluster (unwrapped, so a cluster straddling +-180 still
	-- gets a correct span) rather than reusing gapAfter, which indexes the
	-- original sorted array.
	local i = 1
	while i <= #clusters do
		local cluster = clusters[i]
		if #cluster <= 1 then
			i += 1
		else
			local span, splitAt, largestGap = 0, nil, -1
			for j = 2, #cluster do
				local gap = cluster[j].bearing - cluster[j - 1].bearing
				if gap < 0 then
					gap += 360
				end
				span += gap
				if gap > largestGap then
					largestGap, splitAt = gap, j
				end
			end

			if span > maxSpanDeg and splitAt then
				local tail = {}
				for j = #cluster, splitAt, -1 do
					table.insert(tail, 1, table.remove(cluster, j))
				end
				table.insert(clusters, i + 1, tail)
				-- Don't advance -- re-check this now-shorter cluster.
			else
				i += 1
			end
		end
	end

	return clusters
end

-- Uniform among surviving DIRECTION clusters, then closest within the chosen
-- cluster (ties within DistanceTieStuds of the closest broken at random) --
-- not uniform among candidates. A junction with one point left and three
-- points bunched right is still a 50/50 left-or-right decision; choosing
-- uniformly among points would let point density silently bias the outcome,
-- which is not what "picks a direction" means.
--
-- Returns (chosenPart, chosenBearing, clusterCount) -- the last two are for
-- DebugPatrol logging only.
local function chooseByCluster(cfg, candidates: { BasePart }, originPos: Vector3, heading: Vector3): (BasePart?, number?, number?)
	local entries = {}
	for _, part in ipairs(candidates) do
		local bearing = bearingOf(originPos, heading, part)
		if bearing then
			table.insert(entries, { part = part, bearing = bearing })
		end
	end
	if #entries == 0 then
		return closestOf(candidates, originPos), nil, 0
	end

	local clusters = clusterByBearing(cfg, entries)

	-- Representative bearing = the closest member's bearing -- the point the
	-- monster would actually walk to defines the direction, not the centroid.
	local function closestEntry(cluster)
		local best, bestDist = cluster[1], math.huge
		for _, entry in ipairs(cluster) do
			local dist = (entry.part.Position - originPos).Magnitude
			if dist < bestDist then
				best, bestDist = entry, dist
			end
		end
		return best
	end

	local reverseCutoff = cfg.ReverseCutoff or MonsterConstants.DefaultPatrolReverseCutoff
	local forward = {}
	for _, cluster in ipairs(clusters) do
		local rep = closestEntry(cluster)
		if math.cos(math.rad(rep.bearing)) >= reverseCutoff then
			table.insert(forward, cluster)
		end
	end
	-- Every cluster classified as "behind" -- the safest fallback is keeping
	-- them all rather than stalling; this is what makes a dead end resolve
	-- to reversing instead of doing nothing.
	local pool = (#forward > 0) and forward or clusters

	local chosen = pool[math.random(1, #pool)]

	local tieStuds = cfg.DistanceTieStuds or MonsterConstants.DefaultPatrolDistanceTieStuds
	local bestDist = math.huge
	for _, entry in ipairs(chosen) do
		local dist = (entry.part.Position - originPos).Magnitude
		if dist < bestDist then
			bestDist = dist
		end
	end
	local tied = {}
	for _, entry in ipairs(chosen) do
		local dist = (entry.part.Position - originPos).Magnitude
		if dist - bestDist <= tieStuds then
			table.insert(tied, entry)
		end
	end
	local pick = tied[math.random(1, #tied)]

	return pick.part, pick.bearing, #pool
end

-- History depth is the ladder's OUTER loop; everything else is an INNER
-- concession made to avoid spending a depth. Reversing into a recently
-- visited point is the single most visible failure this state has, so it is
-- ranked LAST -- every cheaper concession is tried at every depth first:
--
--   1. near + line of sight     -- the ideal: a visible neighbour
--   2. near + occluded          -- pathfinding routes around the wall, which
--                                  reads as "checking the next room"
--   3. wide + line of sight     -- points spaced beyond LinkRadius
--   4. wide + occluded          -- both concessions at once
--
-- Both orderings here were previously wrong and both caused the same
-- back-and-forth symptom. LOS used to be the outer loop, so a merely-occluded
-- forward point lost to a VISIBLE point the monster had just come from. And
-- the radius was never a rung at all: a network spaced wider than LinkRadius
-- (60) made the only forward continuation invisible to selection, leaving the
-- monster to bounce between the two neighbours inside the bubble forever. A
-- concession the ladder cannot make is a concession silently ranked above
-- reversing.
--
-- Depth 0 (no history exclusion at all) is what makes a genuine dead end
-- resolve to reversing -- with nothing else excluded, the point behind is
-- the only candidate left, and returning it directly, below, is correct, not
-- a bug. Falls through to an unbounded nearest-point search only if the map
-- has nothing within MaxLinkRadius at all.
local function selectNextPatrolPoint(instance, navigation, memory)
	local cfg = patrolCfg(instance)
	local linkRadius = cfg.LinkRadius or MonsterConstants.DefaultPatrolLinkRadius
	local maxLinkRadius = math.max(cfg.MaxLinkRadius or MonsterConstants.DefaultPatrolMaxLinkRadius, linkRadius)
	local originPos, heading = currentOriginAndHeading(instance, memory)
	local exclude = badPointSet(cfg, memory)
	-- LOS is cast from where the monster ACTUALLY is, not from the anchor
	-- point it is nominally standing on -- on the first selection after spawn
	-- there is no anchor at all, and mid-leg recoveries can select from
	-- somewhere well off the node.
	local eyePos = instance.rootPart.Position

	-- ONE PatrolGraph scan, at the widest radius; the near tier is a distance
	-- filter over that same result rather than a second query, and each point
	-- gets at most one LOS raycast regardless of how many rungs run.
	local wide = PatrolGraph.PointsWithin(originPos, maxLinkRadius, instance.monsterId, exclude)
	local near, nearLOS, wideLOS = {}, {}, {}
	for _, part in ipairs(wide) do
		local isNear = (part.Position - originPos).Magnitude <= linkRadius
		if isNear then
			table.insert(near, part)
		end
		if navigation:HasLineOfSight(eyePos, part.Position, part) then
			table.insert(wideLOS, part)
			if isNear then
				table.insert(nearLOS, part)
			end
		end
	end

	local tiers = {
		{ set = nearLOS, occluded = false, widened = false },
		{ set = near, occluded = true, widened = false },
		{ set = wideLOS, occluded = false, widened = true },
		{ set = wide, occluded = true, widened = true },
	}

	local historyLength = cfg.HistoryLength or MonsterConstants.DefaultPatrolHistoryLength
	local candidates, chosenTier = {}, nil

	for depth = historyLength, 0, -1 do
		local excludedRecent
		if depth > 0 and #memory.history > 0 then
			excludedRecent = {}
			local from = math.max(1, #memory.history - depth + 1)
			for i = from, #memory.history do
				excludedRecent[memory.history[i]] = true
			end
		end

		for _, tier in ipairs(tiers) do
			local out = tier.set
			if excludedRecent then
				out = {}
				for _, part in ipairs(tier.set) do
					if not excludedRecent[part] then
						table.insert(out, part)
					end
				end
			end
			if #out > 0 then
				candidates, chosenTier = out, tier
				break
			end
		end

		if chosenTier then
			break
		end
	end

	if chosenTier and chosenTier.occluded and not memory.warnedNoLOS then
		-- LOS is a strong preference, but never-stall outranks it -- a monster
		-- in a spot where every neighbour at this depth is occluded (a doorway
		-- it just stepped through, a pillared room) must still pick and move.
		memory.warnedNoLOS = true
		warn(("Patrol: '%s' had no PatrolPoint in line of sight -- falling back to an occluded one. Points may be spaced across walls rather than along walkable routes.")
			:format(instance.monsterId))
	end

	if chosenTier and chosenTier.widened and not memory.warnedWideRadius then
		-- Authoring signal, not a runtime problem: the monster only had a
		-- forward option because selection reached past LinkRadius for it.
		memory.warnedWideRadius = true
		warn(("Patrol: '%s' found no PatrolPoint within LinkRadius (%d studs) that wasn't recently visited -- reaching out to %d studs to avoid turning back. Consider spacing points closer than %d studs.")
			:format(instance.monsterId, linkRadius, maxLinkRadius, linkRadius))
	end

	if #candidates == 0 then
		local nearest = PatrolGraph.Nearest(originPos, instance.monsterId, exclude)
		if nearest and not memory.warnedNoLink then
			memory.warnedNoLink = true
			warn(("Patrol: '%s' has no linked PatrolPoint within %d studs -- falling back to the nearest one; consider adding a connecting point")
				:format(instance.monsterId, maxLinkRadius))
		end
		return nearest
	end

	if #candidates == 1 then
		return candidates[1]
	end

	local chosen, bearing, clusterCount
	if heading then
		chosen, bearing, clusterCount = chooseByCluster(cfg, candidates, originPos, heading)
	else
		-- No travel heading yet (first selection after spawn): there is no
		-- meaningful direction to choose, so pick uniformly among candidates
		-- rather than deriving one from facing. See currentOriginAndHeading.
		chosen = candidates[math.random(1, #candidates)]
	end

	if MonsterConstants.DebugPatrol then
		print(("Patrol[%s]: tier=%s%s, %d candidate(s), %s cluster(s), chose %s%s")
			:format(
				instance.monsterId,
				chosenTier and (chosenTier.widened and "wide" or "near") or "?",
				chosenTier and (chosenTier.occluded and "+occluded" or "+los") or "",
				#candidates,
				clusterCount and tostring(clusterCount) or "n/a",
				chosen and chosen:GetFullName() or "nil",
				bearing and (" @ " .. math.floor(bearing) .. "deg") or ""
			))
	end

	return chosen
end

-- Negative results are cached as { failedAt = os.clock() } rather than a
-- bare `false`, so badPointSet can expire them after UnreachableRetryAfter
-- instead of blacklisting the point for the monster's entire lifetime -- a
-- door shut when first probed must not stay excluded forever.
local function resolvePatrolPoint(instance, cfg, navigation, memory, part: BasePart): Vector3?
	local cached = memory.resolved[part]
	if cached then
		if typeof(cached) ~= "table" then
			return cached
		end
		local retryAfter = cfg.UnreachableRetryAfter or MonsterConstants.DefaultPatrolUnreachableRetryAfter
		if os.clock() - cached.failedAt < retryAfter then
			return nil
		end
		-- Expired: fall through and re-probe.
	end

	local resolved = navigation:ResolveReachable(part.Position)
	if not resolved then
		warn(("Patrol: '%s' PatrolPoint at %s has no reachable ground -- excluding it")
			:format(instance.monsterId, tostring(part.Position)))
		memory.resolved[part] = { failedAt = os.clock() }
		return nil
	end

	memory.resolved[part] = resolved
	return resolved
end

-- Dedupes before inserting (move-to-front): a point re-visited via the
-- fallback ladder must not consume two of the HistoryLength slots, which
-- would silently shrink the effective anti-reversal window.
local function pushHistory(cfg, memory, part: BasePart)
	for i = #memory.history, 1, -1 do
		if memory.history[i] == part then
			table.remove(memory.history, i)
		end
	end
	table.insert(memory.history, part)
	local historyLength = cfg.HistoryLength or MonsterConstants.DefaultPatrolHistoryLength
	while #memory.history > historyLength do
		table.remove(memory.history, 1)
	end
end

-- Selects (if needed) and resolves a route target, retrying past unreachable
-- candidates within one tick up to MAX_SELECT_ATTEMPTS. Returns the
-- resolved world position to walk to, or nil if nothing panned out this tick.
local function ensureRouteTarget(instance, navigation, memory): Vector3?
	local cfg = patrolCfg(instance)
	for _ = 1, MAX_SELECT_ATTEMPTS do
		if not memory.target then
			local target = selectNextPatrolPoint(instance, navigation, memory)
			if not target then
				return nil
			end
			memory.target = target
			memory.legStartAt = os.clock()
			table.clear(memory.rolledThisLeg)
		end

		local pos = resolvePatrolPoint(instance, cfg, navigation, memory, memory.target)
		if pos then
			return pos
		end

		-- Unreachable: resolvePatrolPoint already cached the failure, which
		-- keeps selectNextPatrolPoint from offering it again. Drop and retry.
		memory.target = nil
	end
	return nil
end

-- Rolled at most ONCE per SearchPoint per leg, cleared on every arrival at a
-- PatrolPoint (ensureRouteTarget's table.clear above). This is load-bearing:
-- Patrol ticks at 0.5s, so a chance evaluated per TICK rather than per LEG
-- reaches ~97% within six seconds, and the monster would detour to nearly
-- every SearchPoint it ever passed instead of the intended occasional one.
local function maybeDivert(instance, navigation, memory, cfg, now: number)
	local searchChance = cfg.SearchChance or MonsterConstants.DefaultPatrolSearchChance
	if searchChance <= 0 then
		return
	end

	local scanInterval = cfg.SearchScanInterval or MonsterConstants.DefaultPatrolSearchScanInterval
	if memory.nextScanAt and now < memory.nextScanAt then
		return
	end
	memory.nextScanAt = now + scanInterval

	-- Bounded by SearchPoints actually in range, not by match length.
	for part, expiry in pairs(memory.searchCooldowns) do
		if now >= expiry then
			memory.searchCooldowns[part] = nil
		end
	end

	local radius = cfg.SearchPointRadius or MonsterConstants.DefaultPatrolSearchPointRadius
	local nearby = PatrolGraph.SearchPointsWithin(instance.rootPart.Position, radius, instance.monsterId)

	for _, part in ipairs(nearby) do
		if not memory.rolledThisLeg[part] and not memory.searchCooldowns[part] then
			-- LOS gate BEFORE the roll, so an occluded point does not burn its
			-- one roll for this leg. A SearchPoint through a wall is not
			-- something the monster has any reason to be curious about yet --
			-- but the same point may come into view later in the same leg, and
			-- it should get its fair roll then.
			if navigation:HasLineOfSight(instance.rootPart.Position, part.Position, part) then
				memory.rolledThisLeg[part] = true

				if math.random() < searchChance then
					local resolved = navigation:ResolveReachable(part.Position)
					if resolved then
						memory.phase = "divert"
						memory.divertTarget = part
						memory.divertPosition = resolved
						return
					end
					-- Unreachable SearchPoint: not put on cooldown -- it was
					-- never actually visited, so nothing to cool down from.
				end
			end
		end
	end
end

-- Bounds how many PatrolPoint-to-PatrolPoint hops one Update call will chain
-- through. Chaining (rather than returning on arrival) is what makes the
-- route look like continuous walking instead of stop/wait/go: MoveTo's
-- arrival branch zeroes MoveDirection immediately (required -- see
-- HumanoidPathLocomotion, that zero is what stops the monster gliding
-- through a point forever), and nothing else re-commands it until the NEXT
-- Update call, up to Patrol.TickRate (0.5s) later. Selecting and issuing the
-- next MoveTo within the SAME call overwrites that zero before physics ever
-- resolves it, so the stop never becomes visible. In normal layouts this
-- only ever chains once per real arrival (the next point is far enough away
-- that MoveTo returns "still travelling" immediately); the bound exists only
-- to cap a pathological map with points stacked on top of each other.
local MAX_ADVANCES_PER_TICK = 4

-- Temporary exclusion for a point that was reachable when chosen but turned
-- out blocked in practice (leg timeout, stuck). NOT history -- the point was
-- never actually visited, so recording it as visited would misrepresent
-- progression and burn one of the HistoryLength anti-reversal slots on a leg
-- the monster never completed.
local function deferPoint(cfg, memory, part: BasePart)
	local deferDuration = cfg.DeferDuration or MonsterConstants.DefaultPatrolDeferDuration
	memory.deferred[part] = os.clock() + deferDuration
end

local function updateRoute(instance, navigation, memory, dt: number)
	local cfg = patrolCfg(instance)

	-- Standing at a point, looking around. No MoveTo call is needed to hold
	-- position: MoveTo's arrival branch already zeroed MoveDirection on the
	-- tick we got here, and Move has no timeout that would resume on its own.
	if memory.pointPauseUntil then
		if os.clock() < memory.pointPauseUntil then
			return
		end
		memory.pointPauseUntil = nil
	end

	for _ = 1, MAX_ADVANCES_PER_TICK do
		local pos = ensureRouteTarget(instance, navigation, memory)
		if not pos then
			return
		end

		local legTimeout = cfg.LegTimeout or MonsterConstants.DefaultPatrolLegTimeout
		if os.clock() - memory.legStartAt > legTimeout then
			-- Reachable when chosen, but genuinely blocked now (a closed
			-- door, a body-blocking player) -- a TEMPORARY exclusion via
			-- `deferred`, not history and not the permanent unreachable
			-- cache: the block may clear. Does not chain further this tick --
			-- a blocked leg abandoned mid-stall should not immediately retry
			-- into another possibly-also-blocked leg.
			deferPoint(cfg, memory, memory.target)
			memory.target = nil
			return
		end

		maybeDivert(instance, navigation, memory, cfg, os.clock())
		if memory.phase ~= "route" then
			return
		end

		local arrived, stuck = navigation:MoveTo(pos, dt)
		if stuck then
			-- Same abandon path as LegTimeout above, just faster to trigger:
			-- pressed against something rather than merely slow. `deferred`,
			-- not history and not the permanent unreachable-cache --
			-- whatever blocked it may clear.
			deferPoint(cfg, memory, memory.target)
			memory.target = nil
			return
		end
		if not arrived then
			-- Still travelling: this tick's movement command is issued, done.
			return
		end

		pushHistory(cfg, memory, memory.target)
		memory.previousAnchor = memory.anchorPoint
		memory.anchorPoint = memory.target
		memory.target = nil

		-- Rolled per ARRIVAL, which is the one place a stop is legible as a
		-- decision rather than a stutter. Breaking the chain here is the
		-- entire point of the feature -- everywhere else in this state the
		-- chain exists specifically to stop the monster going idle.
		local pauseChance = pauseChanceFor(instance, cfg)
		if pauseChance > 0 and math.random() < pauseChance then
			local minSeconds = cfg.PointPauseMin or MonsterConstants.DefaultPatrolPointPauseMin
			local maxSeconds = cfg.PointPauseMax or MonsterConstants.DefaultPatrolPointPauseMax
			memory.pointPauseUntil = os.clock() + minSeconds + math.random() * math.max(maxSeconds - minSeconds, 0)
			return
		end
		-- Arrived and not pausing: loop immediately picks the next point and
		-- commands it rather than returning, so the humanoid never goes idle.
	end
end

-- Returns to the route phase, keeping the still-pending PatrolPoint.
--
-- legStartAt is REARMED here, and that is not cosmetic: it is wall-clock,
-- started when the leg's target was chosen, and a divert parks 10-20s of
-- searching in the middle of a leg. Against a 30s LegTimeout that would trip
-- the "this leg is blocked" recovery on a leg that was never blocked, dropping
-- the point and looking like the monster forgot where it was going.
local function resumeRoute(instance, navigation, memory, dt: number)
	memory.phase = "route"
	memory.divertTarget = nil
	memory.divertPosition = nil
	memory.searchPoint = nil
	memory.searchPauseUntil = nil
	memory.legStartAt = os.clock()
	updateRoute(instance, navigation, memory, dt)
end

local function updateSearch(instance, navigation, memory, dt: number)
	local now = os.clock()
	local cfg = patrolCfg(instance)

	if not memory.divertTarget or not memory.divertTarget.Parent then
		-- Deleted mid-search: nothing to cool down, just resume the route.
		resumeRoute(instance, navigation, memory, dt)
		return
	end

	if now >= memory.searchUntil then
		local cooldown = cfg.SearchPointCooldown or MonsterConstants.DefaultPatrolSearchPointCooldown
		memory.searchCooldowns[memory.divertTarget] = now + cooldown
		-- Chain straight back into the still-pending PatrolPoint rather than
		-- leaving the monster standing at the SearchPoint for up to 0.5s.
		resumeRoute(instance, navigation, memory, dt)
		return
	end

	-- Deliberately NOT chained: the pause between individual sweep points
	-- (MonsterConstants.DefaultSearchPause) is the "stop and look around"
	-- beat that makes a search read as a search, same as Check. Only the
	-- transitions INTO and OUT OF the search (below, and in updateDivert)
	-- are the stutter this fix targets.
	if memory.searchPauseUntil and now < memory.searchPauseUntil then
		return
	end

	if not memory.searchPoint then
		local sweepRadius = cfg.SearchSweepRadius or MonsterConstants.DefaultPatrolSearchSweepRadius
		-- nil means the roll landed against geometry; leaving searchPoint nil
		-- re-rolls next tick rather than sending the monster into a wall.
		memory.searchPoint = navigation:PickRoamPoint(memory.divertTarget.Position, sweepRadius)
		memory.searchPauseUntil = nil
		if not memory.searchPoint then
			return
		end
	end

	local arrived, stuck = navigation:MoveTo(memory.searchPoint, dt)
	if stuck then
		-- Same nil-and-re-roll as an unreachable pick above -- this sweep
		-- point turned out to be unwalkable in practice even though it passed
		-- PickRoamPoint's isolated reachability check.
		memory.searchPoint = nil
		return
	end
	if arrived then
		memory.searchPoint = nil
		memory.searchPauseUntil = now + MonsterConstants.DefaultSearchPause
	end
end

local function updateDivert(instance, navigation, memory, dt: number)
	if not memory.divertTarget or not memory.divertTarget.Parent then
		-- Deleted mid-divert: resume the route toward the PatrolPoint that
		-- was still pending -- it was kept, not discarded, on divert entry.
		resumeRoute(instance, navigation, memory, dt)
		return
	end

	local diverted, divertStuck = navigation:MoveTo(memory.divertPosition, dt)
	if divertStuck then
		-- Can't actually reach this SearchPoint -- resume the route rather
		-- than grinding on it. No cooldown: it was never visited, so there
		-- is nothing to cool down from, same as an unreachable roll.
		resumeRoute(instance, navigation, memory, dt)
		return
	end
	if diverted then
		local cfg = patrolCfg(instance)
		local minSeconds = cfg.SearchDurationMin or MonsterConstants.DefaultPatrolSearchDurationMin
		local maxSeconds = cfg.SearchDurationMax or MonsterConstants.DefaultPatrolSearchDurationMax
		memory.phase = "search"
		memory.searchUntil = os.clock() + minSeconds + math.random() * math.max(maxSeconds - minSeconds, 0)
		memory.searchPoint = nil
		memory.searchPauseUntil = nil
		-- Chain into the first sweep point immediately -- arriving at the
		-- SearchPoint should flow straight into investigating it, not pause
		-- for up to 0.5s first.
		updateSearch(instance, navigation, memory, dt)
	end
end

----------------------------------------------------------------------------

function Patrol.Score(instance, blackboard): number?
	if blackboard.Target or blackboard.LastKnownPos then
		return nil
	end
	if authoredRoute(instance) then
		return PATROL_UTILITY
	end
	if not PatrolGraph.HasPatrolPoints() then
		return nil
	end
	return PATROL_UTILITY
end

function Patrol.Enter(instance)
	local memory = memoryFor(instance)
	if not memory.phase then
		memory.phase = "route"
	end
	-- Deliberately does NOT reset phase/target/history on entry, unlike
	-- Check. A monster interrupted mid-divert or mid-search by Chase (Band 1)
	-- should resume that same detour when Chase releases it, not restart its
	-- route from scratch -- restarting would make an interrupted search less
	-- sticky than an uninterrupted one, which is backwards.
	--
	-- legStartAt IS rearmed when a leg is pending, though -- same reasoning as
	-- resumeRoute above: it's wall-clock, started when the target was chosen,
	-- and a Chase/Check interruption can eat most of a 30s LegTimeout while
	-- Patrol isn't ticking at all. Without this, returning from a long chase
	-- trips the "this leg is blocked" recovery on a leg that was never
	-- blocked, which would look like the monster forgot where it was going --
	-- exactly the "restarting the route" failure this state exists to avoid.
	if memory.target then
		memory.legStartAt = os.clock()
	end
end

function Patrol.Update(instance, dt: number)
	local navigation = instance:GetComponent("Navigation")
	if not navigation then
		return
	end

	local route = authoredRoute(instance)
	if route then
		updateAuthoredRoute(instance, navigation, route, dt)
		return
	end

	local memory = memoryFor(instance)
	if memory.phase == "search" then
		updateSearch(instance, navigation, memory, dt)
	elseif memory.phase == "divert" then
		updateDivert(instance, navigation, memory, dt)
	else
		updateRoute(instance, navigation, memory, dt)
	end
end

function Patrol.Exit(instance)
	local navigation = instance:GetComponent("Navigation")
	if navigation then
		navigation:Stop()
	end
end

return Patrol
