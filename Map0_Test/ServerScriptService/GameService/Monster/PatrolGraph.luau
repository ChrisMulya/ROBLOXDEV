-- The hand-placed navigation network: every IsPatrolPoint / IsSearchPoint
-- BasePart in the map, plus the two spatial queries States/Patrol needs.
--
-- Deliberately monster-agnostic and stateless beyond the point set itself: no
-- reachability, no per-monster memory, no selection logic. Reachability
-- depends on AgentRadius, which differs per monster, so it lives in Patrol's
-- own per-instance cache -- keeping this module ignorant of that is what lets
-- three monsters with different radii share one scan. See blueprint §20.3.
--
-- Connectivity is IMPLICIT, by distance -- there is no authored link data.
-- Two points are "connected" if PointsWithin finds them near each other. This
-- is what lets a route be authored by dragging parts into a corridor, with no
-- link-editing tool and no link table to keep in sync with geometry that moved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterConstants = require(ReplicatedStorage.Modules.Monster.MonsterConstants)

local PatrolGraph = {}

-- [BasePart] = true
local patrolPoints = {}
local searchPoints = {}
local patrolCount = 0
local searchCount = 0

local function matchesMonster(part: BasePart, monsterId: string?): boolean
	local restrict = part:GetAttribute(MonsterConstants.Attributes.MonsterId)
	return restrict == nil or restrict == monsterId
end

local function tryAdd(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if instance:GetAttribute(MonsterConstants.Attributes.IsPatrolPoint) then
		if not patrolPoints[instance] then
			patrolPoints[instance] = true
			patrolCount += 1
		end
	elseif instance:GetAttribute(MonsterConstants.Attributes.IsSearchPoint) then
		if not searchPoints[instance] then
			searchPoints[instance] = true
			searchCount += 1
		end
	end
end

local function tryRemove(instance: Instance)
	if patrolPoints[instance] then
		patrolPoints[instance] = nil
		patrolCount -= 1
	elseif searchPoints[instance] then
		searchPoints[instance] = nil
		searchCount -= 1
	end
end

-- excludeSet lets a caller skip points it already knows are bad (its own
-- unreachable-cache, the point it is currently standing on, recent history)
-- in one pass, rather than filtering the result afterward. Optional.
function PatrolGraph.PointsWithin(position: Vector3, radius: number, monsterId: string?, excludeSet: { [BasePart]: boolean }?): { BasePart }
	local out = {}
	for part in pairs(patrolPoints) do
		if not (excludeSet and excludeSet[part]) and matchesMonster(part, monsterId) then
			if (part.Position - position).Magnitude <= radius then
				table.insert(out, part)
			end
		end
	end
	return out
end

-- Unbounded fallback for when nothing is within any reasonable radius -- a
-- point with no reachable neighbour still needs a next destination, or the
-- monster stalls. Excluding known-bad points here (rather than only in
-- PointsWithin) is what stops a single unreachable nearest point from being
-- re-offered forever.
function PatrolGraph.Nearest(position: Vector3, monsterId: string?, excludeSet: { [BasePart]: boolean }?): BasePart?
	local best, bestDist = nil, math.huge
	for part in pairs(patrolPoints) do
		if not (excludeSet and excludeSet[part]) and matchesMonster(part, monsterId) then
			local dist = (part.Position - position).Magnitude
			if dist < bestDist then
				best, bestDist = part, dist
			end
		end
	end
	return best
end

function PatrolGraph.SearchPointsWithin(position: Vector3, radius: number, monsterId: string?): { BasePart }
	local out = {}
	for part in pairs(searchPoints) do
		if matchesMonster(part, monsterId) then
			if (part.Position - position).Magnitude <= radius then
				table.insert(out, part)
			end
		end
	end
	return out
end

-- Patrol.Score's map-has-nothing-authored check. Deliberately global, not
-- per-monsterId, so the boot warn fires once regardless of how many monster
-- types exist -- a per-type check belongs to PointsWithin's own exclusion at
-- query time, not to whether the state is eligible at all.
function PatrolGraph.HasPatrolPoints(): boolean
	return patrolCount > 0
end

local started = false

function PatrolGraph.Start()
	if started then
		return
	end
	started = true

	for _, descendant in ipairs(workspace:GetDescendants()) do
		tryAdd(descendant)
	end

	-- Never disconnected: this runs for the server's lifetime, same as
	-- MonsterRegistry's Spawned/Died signals.
	workspace.DescendantAdded:Connect(tryAdd)
	workspace.DescendantRemoving:Connect(tryRemove)

	if patrolCount == 0 then
		warn("PatrolGraph: no IsPatrolPoint parts in Workspace -- Patrol will never be eligible")
	end
end

return PatrolGraph
