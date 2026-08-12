-- Publishes MissionProgress's shared values onto ReplicatedStorage.MatchInfo
-- -- shared, identical-for-everyone state, so it rides attributes rather than
-- a remote (the MatchTimeReplicator/MatchReplicator rule).
--
-- Published only while the match is Playing, the same ShowsMatchTime-only
-- convention the match clock uses: the Mission List is a Playing-scoped HUD
-- element, so clearing to nil outside Playing is how "no mission list" is
-- expressed on the wire, exactly like the clock's anchors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MissionProgress = require(script.Parent.MissionProgress)
local MatchManager = require(script.Parent.MatchManager)

local MissionReplicator = {}

-- Same folder MatchReplicator/MatchTimeReplicator publish into. All three use
-- FindFirstChild-or-create, so none depends on the others' boot order.
local function ensureMatchInfoFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("MatchInfo")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MatchInfo"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local ATTRIBUTE_NAMES = {
	"MissionPhotoScore",
	"MissionObjectivesCompleted",
	"MissionObjectivesTotal",
	"MissionDocumentsCollected",
	"MissionDocumentsTotal",
}

local function publish(matchInfo: Folder)
	local snapshot = MissionProgress.Get()
	matchInfo:SetAttribute("MissionPhotoScore", snapshot.photoScore)
	matchInfo:SetAttribute("MissionObjectivesCompleted", snapshot.objectivesCompleted)
	matchInfo:SetAttribute("MissionObjectivesTotal", snapshot.objectivesTotal)
	matchInfo:SetAttribute("MissionDocumentsCollected", snapshot.documentsCollected)
	matchInfo:SetAttribute("MissionDocumentsTotal", snapshot.documentsTotal)
end

local function clear(matchInfo: Folder)
	for _, name in ipairs(ATTRIBUTE_NAMES) do
		matchInfo:SetAttribute(name, nil)
	end
end

local started = false

function MissionReplicator.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	local matchInfo = ensureMatchInfoFolder()
	clear(matchInfo)

	MissionProgress.Changed:Connect(function()
		if MatchManager.Is("Playing") then
			publish(matchInfo)
		end
	end)

	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Playing" then
			publish(matchInfo)
		else
			clear(matchInfo)
		end
	end)
end

return MissionReplicator
