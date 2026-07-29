-- Mirrors MatchManager's authoritative state onto an attribute on
-- ReplicatedStorage.MatchInfo -- shared, identical-for-everyone state, so it
-- rides an attribute rather than a remote (the ObjectiveReplicator rule).
-- No per-player payload exists yet (that's Phase 7's MatchResultSync) --
-- this is the only match module allowed to touch remotes, once one is
-- needed.
--
-- Started after MatchManager in the boot list (publisher before subscriber)
-- so no StateChanged fire is missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchManager = require(script.Parent.MatchManager)

local MatchReplicator = {}

local function ensureMatchInfoFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("MatchInfo")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MatchInfo"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local started = false

function MatchReplicator.Start()
	if started then
		return
	end
	started = true

	local matchInfo = ensureMatchInfoFolder()
	matchInfo:SetAttribute("MatchState", MatchManager.Get())

	MatchManager.StateChanged:Connect(function(newState: string)
		matchInfo:SetAttribute("MatchState", newState)
	end)
end

return MatchReplicator
