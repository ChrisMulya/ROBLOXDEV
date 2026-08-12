-- Decides WHERE an LOS-loss / footstep / stimulus investigation should go,
-- and WHY. Ticks after Targeting, in the same MonsterInstance:Tick call
-- (same TickRate, same accumulator behaviour), so it always sees this frame's
-- Targeting writes -- no event subscription needed, same pattern Aggression
-- uses to read Perception's VisibleTargets.
--
-- Sole writer of InvestigationPosition/InvestigationReason/InvestigationAt.
-- Check reads this channel instead of touching LastStimulus or LastKnownPos
-- directly -- see Check's header for why that separation matters.
--
-- Three candidates, evaluated fresh every tick, newest evidence wins:
--
--   Visual    -- LastKnownPos projected along LastSeenDirection, from the
--                moment LOS broke (LoSLostAt). Never derived from hearing.
--                Since Refinement 2, Check no longer travels to this
--                position -- it uses it only as a DISCOVERY FOCUS to centre
--                360-degree PatrolPoint selection, continuing the player's
--                escape route rather than working the LOS-loss corner.
--   Trail     -- TrailPos/TrailAt: a footstep from the player already being
--                pursued, heard after (or before) LOS broke.
--   Stimulus  -- LastStimulus: anything else Perception picked up.
--
-- Highest EvidenceAt (the TIMESTAMP OF THE EVIDENCE, not of this computation)
-- wins, so a stale visual projection can never override a fresher footstep.
-- Exact-timestamp ties break Trail > Stimulus > Visual.
--
-- LOAD-BEARING: for a Visual candidate, EvidenceAt is always exactly
-- LoSLostAt (see _visualCandidate below, and the "return { ... EvidenceAt =
-- loSLostAt ... }" line) -- never the time this computation ran. Check's
-- "losdelay" phase (Refinement 2 R2.2) derives its ~1s settle deadline as
-- InvestigationAt + delay specifically because that identity holds. If
-- _visualCandidate's EvidenceAt is ever changed to something else, Check's
-- delay silently starts measuring from the wrong instant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local Investigation = {}
Investigation.__index = Investigation

Investigation.Name = "Investigation"
Investigation.Writes = { "InvestigationPosition", "InvestigationReason", "InvestigationAt" }
-- Matches Targeting's TickRate exactly. Both use the same threshold against
-- the same per-tick dt starting from a zeroed accumulator, so they fire on
-- the same frames -- this is what lets Investigation trust it is reading
-- Targeting's writes from THIS tick, not a stale one.
Investigation.TickRate = 0.1

local REASON_PRIORITY = { Trail = 3, Stimulus = 2, Visual = 1 }

function Investigation.new(instance, _config)
	local self = setmetatable({
		instance = instance,
		-- Which LoSLostAt the cached projection distance was rolled for.
		-- Rerolling every tick would make the destination jitter and defeat
		-- Navigation's destination-keyed stuck detection.
		_projectionAnchor = nil,
		_projectionDistance = nil,
		-- See GetDirectionInfo -- cached component-side because Targeting's
		-- Forget() wipes the Blackboard originals on handoff.
		_committedDirection = nil,
		_committedOrigin = nil,
	}, Investigation)

	local blackboard = instance.blackboard
	blackboard.InvestigationPosition = nil
	blackboard.InvestigationReason = nil
	blackboard.InvestigationAt = nil

	return self
end

function Investigation:Start() end

local function investigationConfig(instance)
	return instance.config.Investigation or {}
end

-- LastKnownPos, projected along LastSeenDirection by a distance rolled once
-- per LOS-loss event. Falls back to LastKnownPos itself if the projection is
-- unreachable (wall, ledge, different floor); drops entirely if even that
-- is unreachable. This module has no opinion on what Check does with the
-- result -- as of Refinement 2 it is a discovery focus for PatrolPoint
-- selection, not a travel destination; that policy lives in Check.
function Investigation:_visualCandidate(instance, blackboard, navigation)
	local loSLostAt = blackboard.LoSLostAt
	local lastKnown = blackboard.LastKnownPos
	if not loSLostAt or not lastKnown then
		return nil
	end

	local cfg = investigationConfig(instance)
	local pursuitDuration = instance.config.Stats.PursuitDuration or 0
	local grace = cfg.VisualInvestigationGrace or MonsterConstants.DefaultVisualInvestigationGrace
	if os.clock() - loSLostAt > pursuitDuration + grace then
		return nil
	end

	if self._projectionAnchor ~= loSLostAt then
		self._projectionAnchor = loSLostAt
		local minDistance = cfg.LoSProjectionMin or MonsterConstants.DefaultLoSProjectionMin
		local maxDistance = cfg.LoSProjectionMax or MonsterConstants.DefaultLoSProjectionMax
		self._projectionDistance = minDistance + math.random() * math.max(maxDistance - minDistance, 0)
	end

	local position
	local direction = blackboard.LastSeenDirection
	if direction and navigation then
		position = navigation:ProjectAlong(lastKnown, direction, self._projectionDistance)
	end
	if not position and navigation then
		position = navigation:ResolveReachable(lastKnown)
	end
	if not position then
		return nil
	end

	return { Position = position, EvidenceAt = loSLostAt, Reason = "Visual" }
end

-- TrailPos/TrailAt: a footstep from the player already being pursued. Never
-- read as LastKnownPos -- Targeting keeps them separate for exactly this.
local function trailCandidate(instance, blackboard, navigation)
	local trailAt = blackboard.TrailAt
	local trailPos = blackboard.TrailPos
	if not trailAt or not trailPos then
		return nil
	end

	local pursuitDuration = instance.config.Stats.PursuitDuration or 0
	if os.clock() - trailAt > pursuitDuration then
		return nil
	end

	local position = navigation and navigation:ResolveReachable(trailPos) or trailPos
	if not position then
		return nil
	end

	return { Position = position, EvidenceAt = trailAt, Reason = "Trail" }
end

-- LastStimulus: anything Perception absorbed, footstep or flash, from anyone.
-- Same freshness window Check used to apply directly.
local function stimulusCandidate(instance, blackboard, navigation)
	local record = blackboard.LastStimulus
	if not record then
		return nil
	end

	local perceptionConfig = instance.config.Perception or {}
	local window = perceptionConfig.InvestigationWindow or MonsterConstants.DefaultInvestigationWindow
	if os.clock() - record.Timestamp > window then
		return nil
	end

	local position = navigation and navigation:ResolveReachable(record.Position) or record.Position
	if not position then
		return nil
	end

	return { Position = position, EvidenceAt = record.Timestamp, Reason = "Stimulus" }
end

local function pickBest(candidates)
	local best
	for _, candidate in ipairs(candidates) do
		if not best
			or candidate.EvidenceAt > best.EvidenceAt
			or (candidate.EvidenceAt == best.EvidenceAt
				and REASON_PRIORITY[candidate.Reason] > REASON_PRIORITY[best.Reason])
		then
			best = candidate
		end
	end
	return best
end

function Investigation:_clear(blackboard)
	self._committedDirection = nil
	self._committedOrigin = nil

	if blackboard.InvestigationPosition == nil and blackboard.InvestigationAt == nil then
		return
	end
	blackboard.InvestigationPosition = nil
	blackboard.InvestigationReason = nil
	blackboard.InvestigationAt = nil
end

function Investigation:Tick(_dt: number)
	local instance = self.instance
	local blackboard = instance.blackboard

	-- A visible player is Chase/Attack's business; a stale investigation must
	-- not survive to compete with (or resume under) a fresh chase.
	if blackboard.Target then
		self:_clear(blackboard)
		return
	end

	local navigation = instance:GetComponent("Navigation")

	local candidates = {}
	local visual = self:_visualCandidate(instance, blackboard, navigation)
	if visual then
		table.insert(candidates, visual)
	end
	local trail = trailCandidate(instance, blackboard, navigation)
	if trail then
		table.insert(candidates, trail)
	end
	local stimulus = stimulusCandidate(instance, blackboard, navigation)
	if stimulus then
		table.insert(candidates, stimulus)
	end

	local best = pickBest(candidates)
	if not best then
		-- No LIVE evidence this tick -- typically because Chase just called
		-- Targeting:Forget() to hand off, which wipes LastKnownPos/TrailPos/
		-- LastSeenDirection/LoSLostAt the instant it happens. Deliberately
		-- does NOT clear an already-committed investigation here: Check owns
		-- deciding when a search is actually done (its own investigatedAt),
		-- and clearing the moment the raw source expires would break the
		-- Chase -> Check handoff on the very next tick, before Check has even
		-- had a chance to start.
		return
	end

	-- Only ever UPGRADE to strictly newer evidence. Without this, a live but
	-- OLDER candidate (e.g. an 8-second-old Stimulus still inside its own
	-- window, surfacing on a tick where Visual/Trail have both expired) would
	-- silently downgrade or restart a fresher investigation already in
	-- progress -- exactly the "stale info overriding newer info" §5 forbids.
	if best.EvidenceAt <= (blackboard.InvestigationAt or -math.huge) then
		return
	end

	blackboard.InvestigationPosition = best.Position
	blackboard.InvestigationReason = best.Reason
	blackboard.InvestigationAt = best.EvidenceAt

	-- Cached on the COMPONENT, not the Blackboard: LastSeenDirection/
	-- LastKnownPos are Targeting's keys and Forget() wipes them the moment
	-- Chase hands off, but SearchPointSelector needs the escape direction and
	-- its vertex for the cone-relevance gate for the rest of THIS
	-- investigation's lifetime. Only meaningful for a Visual commit; any
	-- other reason clears it so a later SearchPoint scan doesn't reuse a
	-- stale heading from a previous, unrelated Visual investigation.
	if best.Reason == "Visual" then
		self._committedDirection = blackboard.LastSeenDirection
		self._committedOrigin = blackboard.LastKnownPos
	else
		self._committedDirection = nil
		self._committedOrigin = nil
	end

	if MonsterConstants.DebugInvestigation then
		print(("Investigation[%s]: %s at %s"):format(
			instance.model.Name, best.Reason, tostring(best.Position)))
	end

	-- Wakes the Brain so Check re-evaluates immediately instead of waiting out
	-- its poll interval -- same mechanism StimulusReceived/TrailUpdated use.
	instance.bus:Fire("InvestigationUpdated", { Reason = best.Reason })
end

-- The escape direction and its vertex (LastKnownPos at the moment it was
-- captured) behind the CURRENTLY COMMITTED Visual investigation, if any.
-- nil for a Trail/Stimulus investigation, or a Visual one with no direction
-- (target read as stationary). Consulted by SearchPointSelector's cone gate.
function Investigation:GetDirectionInfo(): { Direction: Vector3, Vertex: Vector3 }?
	if not self._committedDirection or not self._committedOrigin then
		return nil
	end
	return { Direction = self._committedDirection, Vertex = self._committedOrigin }
end

function Investigation:Destroy() end

return Investigation
