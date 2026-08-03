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
		require(ServerScriptService.GameService.Match.MatchEndCondition),
		-- MatchResultBuilder before MatchReplicator: Replicator's own Ending
		-- listener calls Builder.Build() and needs Builder's Ending listener
		-- (which captures resultCode/duration) to have already run.
		require(ServerScriptService.GameService.Match.MatchResultBuilder),
		require(ServerScriptService.GameService.Match.MatchReplicator),
		require(ServerScriptService.GameService.Match.MatchCleanup),
		-- After MatchCleanup: registers a save step into its registry.
		-- Order-tolerant at boot (RegisterSaveStep just appends to a
		-- table), but this position keeps the list's dependency direction
		-- consistent with every other publisher-before-subscriber entry.
		require(ServerScriptService.GameService.Reward.RewardCleanupHook),
		-- First MatchResultBuilder contributor -- registry before registrant,
		-- same rule as RewardCleanupHook above.
		require(ServerScriptService.GameService.Reward.RewardResultHook),
		-- Registers a teardown step into MatchCleanup's registry (same rule
		-- as RewardCleanupHook/RewardResultHook above).
		require(ServerScriptService.GameService.Player.KitLifecycleHook),
		require(ServerScriptService.GameService.Match.ReturnToLobbyService),
		require(ServerScriptService.GameService.Match.MatchClock),
		-- Loads characters for the roster once WaitingForPlayers begins.
		require(ServerScriptService.GameService.Match.MatchSpawner),
		require(ServerScriptService.GameService.Death.DeathService),
		require(ServerScriptService.GameService.Spectate.SpectateService),
		-- MatchArrival LAST: it fires the first real transition
		-- (Loading -> WaitingForPlayers), so every StateChanged subscriber
		-- above (MatchClock, MatchSpawner, MatchResultBuilder, etc.) must
		-- already be connected before that can happen -- this was previously
		-- correct only by accident (Signal fires deferred), which required
		-- re-deriving that fact every time a new subscriber was added.
		require(ServerScriptService.GameService.Match.MatchArrival),
	}

	for _, service in ipairs(services) do
		service.Start()
	end
end

return GameBoot
