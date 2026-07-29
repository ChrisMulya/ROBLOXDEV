-- Ordered service list for the Lobby place. This list IS the boot order --
-- it is not inferred from require() order (Roblox doesn't guarantee that;
-- see Bootstrap.legacy.luau). Convention: shared/data -> state managers ->
-- policy -> feature systems -> replicators. Publishers start before
-- subscribers.
--
-- Empty today. QueueService/PartyService/MatchLauncher/LobbyDeathPolicy/
-- ArrivalService land in later phases and get added here -- they do not
-- self-wire at require time (see the Service.Start() convention in the
-- plan). Existing self-wiring legacy Scripts (PlayerCurrency, BuyHandler,
-- etc.) are untouched by this and keep running exactly as before.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)

local LobbyBoot = {}

function LobbyBoot.Start()
	ServerRole.AssertLobbyServer()

	-- MatchStates is Game-Server-only (the Match layer never runs on the
	-- Lobby), so only PlayerStates needs validating here. PlayerState is a
	-- layer that exists on both places.
	PlayerStates.Validate()

	local services = {
		require(ServerScriptService.GameService.PlayerState.PlayerStateService),
		require(ServerScriptService.GameService.PlayerState.PlayerStateReplicator),
		require(ServerScriptService.GameService.Lobby.LobbyDeathPolicy),
		-- Phase 9: PartyService, QueueService, MatchLauncher, ArrivalService
	}

	for _, service in ipairs(services) do
		service.Start()
	end
end

return LobbyBoot
