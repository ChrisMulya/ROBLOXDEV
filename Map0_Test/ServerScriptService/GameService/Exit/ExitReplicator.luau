-- Publishes ExitState's shared values onto ReplicatedStorage.MatchInfo --
-- shared, identical-for-everyone state, so it rides attributes rather than a
-- remote. Directly mirrors Match/MissionReplicator.luau.
--
-- Published only while the match is Playing; cleared to nil otherwise.
-- Absent ExitAlternateRequirementKind is the canonical "not rolled yet"
-- signal -- there is no separate boolean for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local ExitState = require(script.Parent.ExitState)
local MatchManager = require(script.Parent.Parent.Match.MatchManager)

local ExitReplicator = {}

-- Same folder MatchReplicator/MatchTimeReplicator/MissionReplicator publish
-- into. All use FindFirstChild-or-create, so none depends on the others'
-- boot order.
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
	"ExitMainAvailable",
	"ExitAlternateAvailable",
	"ExitAlternateRequirementKind",
	"ExitAlternateRequirementValue",
}

local function publish(matchInfo: Folder)
	local snapshot = ExitState.GetSnapshot()
	matchInfo:SetAttribute("ExitMainAvailable", snapshot.mainAvailable)
	matchInfo:SetAttribute("ExitAlternateAvailable", snapshot.alternateAvailable)

	local requirement = snapshot.alternateRequirement
	if requirement then
		matchInfo:SetAttribute("ExitAlternateRequirementKind", requirement.kind)
		matchInfo:SetAttribute("ExitAlternateRequirementValue", requirement.value)
	else
		matchInfo:SetAttribute("ExitAlternateRequirementKind", nil)
		matchInfo:SetAttribute("ExitAlternateRequirementValue", nil)
	end
end

local function clear(matchInfo: Folder)
	for _, name in ipairs(ATTRIBUTE_NAMES) do
		matchInfo:SetAttribute(name, nil)
	end
end

local started = false

function ExitReplicator.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	local matchInfo = ensureMatchInfoFolder()
	clear(matchInfo)

	ExitState.Changed:Connect(function()
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

return ExitReplicator
