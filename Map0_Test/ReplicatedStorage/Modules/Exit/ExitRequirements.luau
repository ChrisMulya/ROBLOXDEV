-- Pure requirement logic, shared verbatim by server and client -- same
-- pattern as MatchTimeMath. No state, no requires into anything stateful.
--
-- A requirement is a flat value object: { kind = "PhotoScore" | "Objectives"
-- | "Documents", value: number? }. `value` is only meaningful for PhotoScore.
--
-- Duck-types its snapshot parameter against MissionProgress.Get() /
-- MissionClient.Get()'s shape ({ photoScore, objectivesCompleted,
-- objectivesTotal, documentsCollected, documentsTotal }) rather than
-- requiring either module, so this stays usable from both the server
-- (MissionProgress) and the client (MissionClient) without a cross-realm
-- require.

local ExitConfig = require(script.Parent.ExitConfig)

local ExitRequirements = {}

export type ExitRequirement = {
	kind: string, -- "PhotoScore" | "Objectives" | "Documents"
	value: number?,
}

export type MissionSnapshot = {
	photoScore: number,
	objectivesCompleted: number,
	objectivesTotal: number,
	documentsCollected: number,
	documentsTotal: number,
}

-- Registration order is not selection order -- SelectRandom below picks
-- uniformly across whatever pool remains after the optional vacuous filter.
ExitRequirements.Candidates = {
	{ kind = "PhotoScore", value = ExitConfig.PhotoScoreThreshold },
	{ kind = "Objectives" },
	{ kind = "Documents" },
} :: { ExitRequirement }

-- A category with total == 0 hasn't been authored into this map at all, so
-- treating it as incomplete would permanently lock an exit on nothing the
-- player can act on. Used for both MainExit and the Alternate completion
-- kinds.
local function isCategoryComplete(done: number, total: number): boolean
	return total == 0 or done >= total
end

-- MainExit's rule: both required categories complete, and at least one of
-- them actually exists in this map (ExitConfig.RequireAtLeastOneCategory --
-- without this guard, a map with zero objectives and zero documents would
-- read as vacuously complete and open MainExit at match start).
function ExitRequirements.IsMainSatisfied(snapshot: MissionSnapshot): boolean
	if ExitConfig.RequireAtLeastOneCategory then
		if (snapshot.objectivesTotal + snapshot.documentsTotal) <= 0 then
			return false
		end
	end

	return isCategoryComplete(snapshot.objectivesCompleted, snapshot.objectivesTotal)
		and isCategoryComplete(snapshot.documentsCollected, snapshot.documentsTotal)
end

function ExitRequirements.IsSatisfied(requirement: ExitRequirement?, snapshot: MissionSnapshot): boolean
	if not requirement then
		return false
	end

	if requirement.kind == "PhotoScore" then
		return snapshot.photoScore >= (requirement.value or 0)
	elseif requirement.kind == "Objectives" then
		return isCategoryComplete(snapshot.objectivesCompleted, snapshot.objectivesTotal)
	elseif requirement.kind == "Documents" then
		return isCategoryComplete(snapshot.documentsCollected, snapshot.documentsTotal)
	end

	warn(("ExitRequirements.IsSatisfied: unknown requirement kind %q"):format(tostring(requirement.kind)))
	return false
end

-- (done, total) for a progress bar. For PhotoScore, total is the threshold.
function ExitRequirements.Progress(requirement: ExitRequirement?, snapshot: MissionSnapshot): (number, number)
	if not requirement then
		return 0, 0
	end

	if requirement.kind == "PhotoScore" then
		return snapshot.photoScore, requirement.value or 0
	elseif requirement.kind == "Objectives" then
		return snapshot.objectivesCompleted, snapshot.objectivesTotal
	elseif requirement.kind == "Documents" then
		return snapshot.documentsCollected, snapshot.documentsTotal
	end

	return 0, 0
end

function ExitRequirements.Describe(requirement: ExitRequirement?): string
	if not requirement then
		return "Unknown"
	end

	if requirement.kind == "PhotoScore" then
		return ("Monster Photo %d"):format(requirement.value or 0)
	elseif requirement.kind == "Objectives" then
		return "Soft Objectives Complete"
	elseif requirement.kind == "Documents" then
		return "Documents Complete"
	end

	return "Unknown"
end

function ExitRequirements.DescribeMain(): string
	return "Complete Objectives + Documents"
end

-- Requirement text with the player's live standing folded in, for the
-- world-space exit sign. Shares Progress() above so the numbers on the sign
-- and any future Mission UI row can never disagree.
function ExitRequirements.DescribeProgress(
	requirement: ExitRequirement?,
	snapshot: MissionSnapshot
): string
	if not requirement then
		return ""
	end

	local done, total = ExitRequirements.Progress(requirement, snapshot)

	if requirement.kind == "PhotoScore" then
		return ("Monster Photo : %d/%d"):format(done, total)
	elseif requirement.kind == "Objectives" then
		return ("Objectives : %d/%d"):format(done, total)
	elseif requirement.kind == "Documents" then
		return ("Documents : %d/%d"):format(done, total)
	end

	return ExitRequirements.Describe(requirement)
end

-- MainExit's standing across both of its required categories, one per line --
-- MainExit is the only exit gated on two categories at once, so it's the one
-- sign that can't say what it needs on a single line.
function ExitRequirements.DescribeMainProgress(snapshot: MissionSnapshot): string
	return ("Objectives : %d/%d\nDocuments : %d/%d"):format(
		snapshot.objectivesCompleted,
		snapshot.objectivesTotal,
		snapshot.documentsCollected,
		snapshot.documentsTotal
	)
end

local function isVacuous(candidate: ExitRequirement, snapshot: MissionSnapshot): boolean
	if candidate.kind == "Objectives" then
		return snapshot.objectivesTotal == 0
	elseif candidate.kind == "Documents" then
		return snapshot.documentsTotal == 0
	end
	return false
end

-- Selects one requirement uniformly at random. Called exactly once per match
-- by ExitState -- this function has no memory of its own, so "once per
-- match" is entirely the caller's discipline to keep, not something this
-- function enforces.
function ExitRequirements.SelectRandom(rng: Random, snapshot: MissionSnapshot?): ExitRequirement
	local pool = ExitRequirements.Candidates

	if ExitConfig.ExcludeVacuousRequirements and snapshot then
		local filtered = {}
		for _, candidate in ipairs(ExitRequirements.Candidates) do
			if not isVacuous(candidate, snapshot) then
				table.insert(filtered, candidate)
			end
		end
		if #filtered > 0 then
			pool = filtered
		end
		-- If every candidate is vacuous, fall through to the unfiltered pool
		-- (equivalent to picking Candidates[1] = PhotoScore, which can never
		-- be vacuous) rather than erroring on an empty pool.
	end

	local index = rng:NextInteger(1, #pool)
	return pool[index]
end

return ExitRequirements
