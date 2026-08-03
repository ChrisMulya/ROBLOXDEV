-- Policy only. Correlates MatchParticipants (the roster) with
-- PlayerStateService (per-player state) to decide when a live match has
-- nobody left to end for. Must not perform cleanup or teleport (that's
-- MatchCleanup/ReturnToLobbyService) and must not require any feature
-- system -- this is the one module allowed to correlate the Match and
-- PlayerState layers.
--
-- Reads PlayerStateService.GetAll() rather than Players:GetPlayerByUserId,
-- so a participant who disconnected mid-match (state "Disconnected", still
-- tracked) is correctly read as not-active without needing their Player
-- instance to still exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)

local MatchManager = require(script.Parent.MatchManager)
local MatchParticipants = require(script.Parent.MatchParticipants)
local PlayerStateService = require(script.Parent.Parent.PlayerState.PlayerStateService)

local MatchEndCondition = {}

-- Zero participants counts as "nobody active" too -- a Playing state reached
-- with no roster (every participant disconnected in a race) should end
-- immediately rather than hang forever.
local function evaluate()
	if not MatchManager.Is("Playing") then
		return
	end

	local allStates = PlayerStateService.GetAll()
	for _, userId in ipairs(MatchParticipants.All()) do
		local state = allStates[userId]
		if state and PlayerStates.CountsAsActive(state) then
			return
		end
	end

	MatchManager.RequestEnd("AllPlayersDown")
end

local started = false

function MatchEndCondition.Start()
	if started then
		return
	end
	started = true

	ServerRole.AssertGameServer()

	PlayerStateService.StateChanged:Connect(evaluate)
	MatchManager.StateChanged:Connect(function(newState: string)
		if newState == "Playing" then
			evaluate()
		end
	end)
end

return MatchEndCondition
