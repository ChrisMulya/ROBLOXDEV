-- Wires MissionClient to MissionHud. Owns no state and no UI -- same
-- controller/HUD split as MatchTimeHudController.
--
-- No heartbeat: mission values are event-shaped attribute writes, not a
-- continuously advancing clock, so this binds directly to the five mission
-- attributes and repaints on change instead of polling.
--
-- Required for its side effects from ClientBootstrap's GameServer branch
-- only. The Lobby never requires this, so no mission list is ever built
-- there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionClient = require(script.Parent.MissionClient)
local MissionHud = require(script.Parent.MissionHud)

local ATTRIBUTE_NAMES = {
	"MissionPhotoScore",
	"MissionObjectivesCompleted",
	"MissionObjectivesTotal",
	"MissionDocumentsCollected",
	"MissionDocumentsTotal",
}

local function refresh()
	MissionHud.Update(MissionClient.Get())
end

local function watchMatchInfo(matchInfo: Instance)
	for _, name in ipairs(ATTRIBUTE_NAMES) do
		matchInfo:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

local matchInfo = ReplicatedStorage:FindFirstChild("MatchInfo")
if matchInfo then
	watchMatchInfo(matchInfo)
else
	-- MissionReplicator/MatchReplicator create MatchInfo at boot, well before
	-- any client finishes loading in practice, but this guards the ordering
	-- rather than assuming it.
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "MatchInfo" then
			watchMatchInfo(child)
		end
	end)
end

return {}
