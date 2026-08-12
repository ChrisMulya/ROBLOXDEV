-- Read-only client mirror of shared exit state. Reads the MatchInfo
-- attributes ExitReplicator writes -- never sets them. Modelled directly on
-- Mission/MissionClient.luau: absent data must read as "not available/not
-- rolled yet", never as false/zero.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExitRequirements = require(script.Parent.ExitRequirements)

local ExitClient = {}

export type ExitSnapshot = {
	mainAvailable: boolean,
	alternateAvailable: boolean,
	alternateRequirement: ExitRequirements.ExitRequirement?,
}

local function getMatchInfo(): Folder?
	return ReplicatedStorage:FindFirstChild("MatchInfo")
end

-- mainAvailable/alternateAvailable are always present while Playing (booleans
-- can be false, which is a legitimate published value, unlike the mission
-- counters which are only ever absent-or-populated). alternateRequirement is
-- nil until the hour-27 unlock has happened this match.
function ExitClient.Get(): ExitSnapshot?
	local matchInfo = getMatchInfo()
	if not matchInfo then
		return nil
	end

	local mainAvailable = matchInfo:GetAttribute("ExitMainAvailable")
	local alternateAvailable = matchInfo:GetAttribute("ExitAlternateAvailable")
	if typeof(mainAvailable) ~= "boolean" or typeof(alternateAvailable) ~= "boolean" then
		return nil
	end

	local requirement: ExitRequirements.ExitRequirement? = nil
	local kind = matchInfo:GetAttribute("ExitAlternateRequirementKind")
	if typeof(kind) == "string" then
		local value = matchInfo:GetAttribute("ExitAlternateRequirementValue")
		requirement = { kind = kind, value = typeof(value) == "number" and value or nil }
	end

	return {
		mainAvailable = mainAvailable,
		alternateAvailable = alternateAvailable,
		alternateRequirement = requirement,
	}
end

return ExitClient
