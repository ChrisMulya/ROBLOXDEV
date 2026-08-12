-- Read-only client mirror of shared mission progress. Reads the MatchInfo
-- attributes MissionReplicator writes -- never sets them. Modelled directly
-- on MatchTimeClient: absent data must read as "no mission state", never as
-- zero.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionClient = {}

export type MissionSnapshot = {
	photoScore: number,
	objectivesCompleted: number,
	objectivesTotal: number,
	documentsCollected: number,
	documentsTotal: number,
}

local function getMatchInfo(): Folder?
	return ReplicatedStorage:FindFirstChild("MatchInfo")
end

function MissionClient.Get(): MissionSnapshot?
	local matchInfo = getMatchInfo()
	if not matchInfo then
		return nil
	end

	local photoScore = matchInfo:GetAttribute("MissionPhotoScore")
	local objectivesCompleted = matchInfo:GetAttribute("MissionObjectivesCompleted")
	local objectivesTotal = matchInfo:GetAttribute("MissionObjectivesTotal")
	local documentsCollected = matchInfo:GetAttribute("MissionDocumentsCollected")
	local documentsTotal = matchInfo:GetAttribute("MissionDocumentsTotal")

	if
		not photoScore
		or not objectivesCompleted
		or not objectivesTotal
		or not documentsCollected
		or not documentsTotal
	then
		return nil
	end

	return {
		photoScore = photoScore,
		objectivesCompleted = objectivesCompleted,
		objectivesTotal = objectivesTotal,
		documentsCollected = documentsCollected,
		documentsTotal = documentsTotal,
	}
end

return MissionClient
