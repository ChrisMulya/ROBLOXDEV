-- Ranks and selects a nearby BasePart genuinely relevant to the CURRENT
-- investigation. One gate-and-rank engine shared by two callers -- SearchPoint
-- selection (hard directional cone, Phase 1) and PatrolPoint selection (360°
-- discovery, direction is a soft ranking bonus only, Refinement 2) -- rather
-- than two near-identical selectors accumulating independently.
--
-- Reuses Navigation's existing reachability/occlusion checks (ResolveReachable,
-- HasLineOfSight) and PatrolGraph's existing spatial scans (SearchPointsWithin,
-- PointsWithin) -- no new wall-check or spatial-index system. Patrol's own
-- point-selection logic (States/Patrol.maybeDivert / selectNextPatrolPoint) is
-- untouched: its policy (random among direction clusters, hard rear-arc
-- rejection) is route-walking behaviour, not investigation behaviour, and is
-- deliberately not reused here -- see blueprint Refinement 2, finding R1.
--
-- "Relevant" means more than "within a radius": a candidate must also sit
-- near the investigation's focus, actually reachable FROM the monster's
-- current position (not just reachable in isolation), and on the same floor.
--
-- Pure selection policy: owns no instance state itself. The caller (Check)
-- hands in its own per-instance memory table for the cooldown map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)
local PatrolGraph = require(script.Parent.Parent.PatrolGraph)

local PointSelector = {}

-- Ranking weight defaults among survivors. Internal tuning, not exposed as
-- config -- nothing has asked to retune "aligned with the escape heading"
-- against "close by" independently of the hard gates below.
local DEFAULT_BEARING_WEIGHT = 1
local DEFAULT_DISTANCE_WEIGHT = 0.5
-- Deviation (blueprint §D2): the framework has no room/volume metadata, so
-- "is this a dead end" can't be answered geometrically. An optional authored
-- Kind attribute contributes this flat bonus only -- untagged points (the
-- common case) are unaffected.
local KIND_BONUS = 0.15

local function investigationConfig(instance)
	return instance.config.Investigation or {}
end

-- directionInfo is Investigation:GetDirectionInfo() -- { Direction, Vertex }
-- or nil. coneDegrees == nil means "no hard directional gate" (360°
-- discovery, per blueprint Refinement 2 R2.4) -- distinct from directionInfo
-- being nil, which means "no known heading at all" (blueprint §7's "no valid
-- LastSeenDirection" case) and also passes everything through.
local function withinCone(part: BasePart, directionInfo, coneDegrees: number?): boolean
	if not coneDegrees or not directionInfo then
		return true
	end

	local offset = part.Position - directionInfo.Vertex
	offset = Vector3.new(offset.X, 0, offset.Z)
	if offset.Magnitude < 1e-3 then
		return true
	end

	local angle = math.deg(math.acos(math.clamp(offset.Unit:Dot(directionInfo.Direction), -1, 1)))
	return angle <= coneDegrees
end

local function bearingAlignment(resolved: Vector3, directionInfo): number
	if not directionInfo then
		return 0
	end

	local offset = resolved - directionInfo.Vertex
	offset = Vector3.new(offset.X, 0, offset.Z)
	if offset.Magnitude < 1e-3 then
		return 0
	end

	return offset.Unit:Dot(directionInfo.Direction)
end

-- opts:
--   Candidates        -- {BasePart}, discovery already done by the caller
--   Origin            -- Vector3, "reachable FROM the monster"; also the LOS eye
--   Focus             -- Vector3, "relevant to THIS investigation"
--   DirectionInfo     -- Investigation:GetDirectionInfo() result, or nil
--   ConeDegrees       -- number, or nil to skip the hard directional gate (360°)
--   FocusRadius       -- number?, max distance from Focus (nil skips the gate)
--   MinDistance       -- number?, min distance from Origin (nil skips the gate)
--   MaxElevationDelta -- number?, max |resolved.Y - Origin.Y| (nil skips the gate)
--   AllowOccluded     -- bool; false hard-rejects tier 2 (occluded from Origin)
--   Cooldowns         -- {[BasePart]=expiryClock}?, entries with expiry > now are skipped
--   NormalizeRadius   -- number?, radius the ranking distance term is normalized against
--   BearingWeight / DistanceWeight -- ranking weights, default 1 / 0.5
--   KindAttribute     -- string?, attribute name for the flat bonus, or nil to skip
--   DebugLabel        -- string?, printed with the choice under DebugInvestigation
--
-- Returns the chosen part and its resolved (reachable, ground-snapped)
-- position, or nil if nothing survives the gates.
function PointSelector.Select(instance, navigation, opts)
	local origin = opts.Origin
	local focus = opts.Focus
	local directionInfo = opts.DirectionInfo
	local cooldowns = opts.Cooldowns
	local now = os.clock()

	local bearingWeight = opts.BearingWeight or DEFAULT_BEARING_WEIGHT
	local distanceWeight = opts.DistanceWeight or DEFAULT_DISTANCE_WEIGHT
	local normalizeRadius = math.max(opts.NormalizeRadius or opts.FocusRadius or 1, 1)

	local best, bestPosition, bestScore, bestTier
	for _, part in ipairs(opts.Candidates) do
		if cooldowns and cooldowns[part] and cooldowns[part] > now then
			continue
		end

		local originDistance = (part.Position - origin).Magnitude
		if opts.MinDistance and originDistance < opts.MinDistance then
			continue
		end

		if not withinCone(part, directionInfo, opts.ConeDegrees) then
			continue
		end

		if opts.FocusRadius and (part.Position - focus).Magnitude > opts.FocusRadius then
			continue
		end

		-- Reachability: rejects points in geometry, over a ledge, or with no
		-- floor beneath them at all.
		local resolved = navigation:ResolveReachable(part.Position)
		if not resolved then
			continue
		end

		-- "Different floor": resolved.Y is the REAL ground height under the
		-- point, so this rejects a point that only LOOKS nearby on the XZ
		-- plane but actually sits a storey up or down.
		if opts.MaxElevationDelta and math.abs(resolved.Y - origin.Y) > opts.MaxElevationDelta then
			continue
		end

		-- Occlusion tier: LOS-clear points are preferred, but an occluded one
		-- (round a corner, in a side room) is kept as a fallback tier rather
		-- than hard-rejected -- that is exactly where a player hides.
		local hasLOS = navigation:HasLineOfSight(origin, resolved, part)
		local tier = hasLOS and 1 or 2
		if tier == 2 and opts.AllowOccluded == false then
			continue
		end

		local alignment = bearingAlignment(resolved, directionInfo)
		local normalizedDistance = math.clamp(originDistance / normalizeRadius, 0, 1)
		local score = alignment * bearingWeight - normalizedDistance * distanceWeight
		if opts.KindAttribute and part:GetAttribute(opts.KindAttribute) then
			score += KIND_BONUS
		end

		local better = false
		if not best then
			better = true
		elseif tier < bestTier then
			better = true
		elseif tier == bestTier then
			if score > bestScore then
				better = true
			elseif score == bestScore then
				local bestDistance = (bestPosition - origin).Magnitude
				if originDistance < bestDistance then
					better = true
				elseif originDistance == bestDistance and part.Name < best.Name then
					better = true
				end
			end
		end

		if better then
			best = part
			bestPosition = resolved
			bestScore = score
			bestTier = tier
		end
	end

	if not best then
		return nil
	end

	if MonsterConstants.DebugInvestigation then
		print(("PointSelector[%s]: %s chose %s (tier %d, score %.2f)"):format(
			instance.model.Name, opts.DebugLabel or "?", best:GetFullName(), bestTier, bestScore))
	end

	return best, bestPosition
end

-- SearchPoint wrapper -- hard directional cone by default (unchanged Phase 1
-- behaviour). Discovery is centred on Focus, not Origin, so a search staged
-- from a PatrolPoint far from where the investigation started still scans
-- the right neighbourhood (blueprint R2.5).
function PointSelector.SelectSearchPoint(instance, navigation, origin: Vector3, focus: Vector3, directionInfo, memory)
	local cfg = investigationConfig(instance)
	local radius = cfg.InvestigationSearchPointRadius
		or MonsterConstants.DefaultInvestigationSearchPointRadius

	local allowOccluded = cfg.AllowOccludedSearchPoints
	if allowOccluded == nil then
		allowOccluded = MonsterConstants.DefaultAllowOccludedSearchPoints
	end

	local candidates = PatrolGraph.SearchPointsWithin(focus, radius, instance.monsterId)

	return PointSelector.Select(instance, navigation, {
		Candidates = candidates,
		Origin = origin,
		Focus = focus,
		DirectionInfo = directionInfo,
		ConeDegrees = cfg.SearchPointConeDegrees or MonsterConstants.DefaultSearchPointConeDegrees,
		FocusRadius = cfg.InvestigationSearchPointFocusRadius
			or MonsterConstants.DefaultInvestigationSearchPointFocusRadius,
		MinDistance = cfg.InvestigationSearchPointMinDistance
			or MonsterConstants.DefaultInvestigationSearchPointMinDistance,
		MaxElevationDelta = cfg.SearchPointMaxElevationDelta
			or MonsterConstants.DefaultSearchPointMaxElevationDelta,
		AllowOccluded = allowOccluded,
		Cooldowns = memory.searchPointCooldowns,
		NormalizeRadius = radius,
		KindAttribute = "SearchPointKind",
		DebugLabel = "SearchPoint",
	})
end

-- PatrolPoint wrapper -- 360° discovery, no hard cone (blueprint R2.4):
-- points behind, beside and in front of the monster are all eligible.
-- Direction is a soft ranking bonus only, so a PatrolPoint continuing the
-- escape route is PREFERRED but a rear one is still selectable when it is
-- all that exists. Occlusion is never hard-rejected either -- a PatrolPoint
-- is a route node, not a hiding spot, and rejecting one for sitting round a
-- corner would fight the whole point of relocating toward the escape route.
function PointSelector.SelectPatrolPoint(instance, navigation, origin: Vector3, focus: Vector3, directionInfo, memory)
	local cfg = investigationConfig(instance)
	local radius = cfg.InvestigationPatrolPointRadius
		or MonsterConstants.DefaultInvestigationPatrolPointRadius

	local candidates = PatrolGraph.PointsWithin(focus, radius, instance.monsterId)

	return PointSelector.Select(instance, navigation, {
		Candidates = candidates,
		Origin = origin,
		Focus = focus,
		DirectionInfo = directionInfo,
		ConeDegrees = nil, -- 360°: no hard directional gate
		FocusRadius = radius,
		MinDistance = cfg.InvestigationPatrolPointMinDistance
			or MonsterConstants.DefaultInvestigationPatrolPointMinDistance,
		MaxElevationDelta = cfg.SearchPointMaxElevationDelta
			or MonsterConstants.DefaultSearchPointMaxElevationDelta,
		AllowOccluded = true,
		Cooldowns = memory.patrolPointCooldowns,
		NormalizeRadius = radius,
		KindAttribute = nil,
		DebugLabel = "PatrolPoint",
	})
end

return PointSelector
