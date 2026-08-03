-- Ordered service list for the Lobby place. This list IS the boot order --
-- it is not inferred from require() order (Roblox doesn't guarantee that;
-- see Bootstrap.legacy.luau). Convention: shared/data -> state managers ->
-- policy -> feature systems -> replicators. Publishers start before
-- subscribers.
--
-- Existing self-wiring legacy Scripts (PlayerCurrency, BuyHandler, etc.) are
-- untouched by this and keep running exactly as before.

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
		-- LaunchGate before its registrants (RewardLaunchHook, QueueService's
		-- own "Roster" precondition): registry before registrant.
		require(ServerScriptService.GameService.Lobby.LaunchGate),
		require(ServerScriptService.GameService.Reward.RewardLaunchHook),
		require(ServerScriptService.GameService.Lobby.MatchLauncher),
		require(ServerScriptService.GameService.Lobby.ArrivalService),
		require(ServerScriptService.GameService.Lobby.PartyService),
		-- QueueService last: it's the caller of MatchLauncher and the
		-- registrant of LaunchGate's "Roster" precondition -- callee before
		-- caller, registry before registrant.
		require(ServerScriptService.GameService.Lobby.QueueService),
	}

	for _, service in ipairs(services) do
		service.Start()
	end
end

return LobbyBoot
