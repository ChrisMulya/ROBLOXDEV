-- Publishes the match clock's anchors onto ReplicatedStorage.MatchInfo --
-- shared, identical-for-everyone state, so it rides attributes rather than a
-- remote (the ObjectiveReplicator/MatchReplicator rule).
--
-- Five timestamps written once at Playing, cleared on stop. Zero per-second
-- traffic: the client subtracts locally, exactly as QueuePadEndsAt and
-- MatchResultSync.returnsAt already do, so its tick cannot drift.
--
-- Subscribes to MatchTimeService.Started/Stopped rather than MatchManager
-- .StateChanged -- see that module's signal comment for why.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local MatchTimeService = require(script.Parent.MatchTimeService)

local MatchTimeReplicator = {}

-- Same folder MatchReplicator publishes MatchState into. Both use
-- FindFirstChild-or-create, so neither depends on the other's boot order.
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
	"MatchScheduleId",
	"MatchTimeStartedAt",
	"MatchTimeEndsAt",
	"MatchTimeAnchorAt",
	"MatchTimeAnchorHour",
}

local function publish(matchInfo: Folder)
	local anchors = MatchTimeService.GetAnchors()
	if not anchors then
		return
	end

	matchInfo:SetAttribute("MatchScheduleId", anchors.scheduleId)
	matchInfo:SetAttribute("MatchTimeStartedAt", anchors.startedAt)
	matchInfo:SetAttribute("MatchTimeEndsAt", anchors.endsAt)
	matchInfo:SetAttribute("MatchTimeAnchorAt", anchors.anchorAt)
	matchInfo:SetAttribute("MatchTimeAnchorHour", anchors.anchorHour)
end

-- Clearing to nil is what makes "no match time outside a match" true on the
-- wire, not just in the server's own memory. A client that joins mid-Ending
-- must find no clock rather than a stale one.
local function clear(matchInfo: Folder)
	for _, name in ipairs(ATTRIBUTE_NAMES) do
		matchInfo:SetAttribute(name, nil)
	end
end

local started = false

function MatchTimeReplicator.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	local matchInfo = ensureMatchInfoFolder()
	clear(matchInfo)

	MatchTimeService.Started:Connect(function()
		publish(matchInfo)
	end)

	MatchTimeService.Stopped:Connect(function()
		clear(matchInfo)
	end)
end

return MatchTimeReplicator
