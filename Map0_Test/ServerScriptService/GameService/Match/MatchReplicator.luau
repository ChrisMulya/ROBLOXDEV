-- Mirrors MatchManager's authoritative state onto an attribute on
-- ReplicatedStorage.MatchInfo -- shared, identical-for-everyone state, so it
-- rides an attribute rather than a remote (the ObjectiveReplicator rule).
-- The only match module allowed to touch remotes: on entering Ending, it
-- also builds and sends the per-player MatchResultSync payload (private to
-- each player, so it's a remote rather than an attribute).
--
-- Started after MatchManager in the boot list (publisher before subscriber)
-- so no StateChanged fire is missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Modules.Shared.Remotes)
local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)
local MatchResultBuilder = require(script.Parent.MatchResultBuilder)

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

		if newState == "Ending" then
			local result = MatchResultBuilder.Build()
			local resultSync = Remotes.Get("MatchResultSync")
			for _, userId in ipairs(MatchParticipants.All()) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					resultSync:FireClient(player, {
						resultCode = result.resultCode,
						durationSeconds = result.durationSeconds,
						perPlayer = result.perPlayer[userId] or {},
					})
				end
			end
		end
	end)
end

return MatchReplicator
