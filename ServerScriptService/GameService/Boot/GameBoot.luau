-- Ordered service list for the Game place. Same ordering convention as
-- LobbyBoot. Empty today -- MatchManager/PlayerStateService/DeathService/
-- SpectateService/etc. land in later phases and get added here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlaceIds = require(ReplicatedStorage.Modules.Shared.PlaceIds)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)

local GameBoot = {}

-- A Game Server nobody reserved has no participant roster and no match --
-- unless the place is configured non-joinable (the primary guard, set in
-- Creator Dashboard), a player can land here directly. This is the code-side
-- backstop that travels with the build regardless of that dashboard setting.
-- Returns true if this server is non-reserved (caller should stop booting).
local function guardNonReservedServer(): boolean
	if game.PrivateServerId ~= "" then
		return false
	end

	warn("[GameBoot] Non-reserved Game Server -- refusing to start a match, returning arrivals to the Lobby.")
	Players.PlayerAdded:Connect(function(player)
		TeleportService:Teleport(PlaceIds.Lobby, player)
	end)
	return true
end

function GameBoot.Start()
	ServerRole.AssertGameServer()

	-- Must be false or the engine respawns a "dead" player under the
	-- spectate UI once DeathService lands (Phase 5). Arrival explicitly
	-- loads the character instead.
	Players.CharacterAutoLoads = false

	if guardNonReservedServer() then
		return
	end

	-- Loud boot failure on a malformed enum beats a silent capability grant
	-- later -- this is the closest thing to a test suite either table gets.
	MatchStates.Validate()
	PlayerStates.Validate()

	local services = {
		require(ServerScriptService.GameService.PlayerState.PlayerStateService),
		require(ServerScriptService.GameService.PlayerState.PlayerStateReplicator),
		require(ServerScriptService.GameService.Match.MatchParticipants),
		require(ServerScriptService.GameService.Match.MatchManager),
		require(ServerScriptService.GameService.Match.MatchReplicator),
		require(ServerScriptService.GameService.Death.DeathService),
		require(ServerScriptService.GameService.Spectate.SpectateService),
		-- Phase 7: MatchEndCondition, MatchResultBuilder, MatchCleanup
		-- Phase 8: ReturnToLobbyService
	}

	for _, service in ipairs(services) do
		service.Start()
	end
end

return GameBoot
