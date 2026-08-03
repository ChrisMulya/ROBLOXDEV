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
		-- Phase 12.5 item 5: runs on both places, no dependents in this
		-- list -- placed early so IsInCamera is truthful as soon as the
		-- server is up, same reasoning as PlayerStateService above.
		require(ServerScriptService.GameService.Camera.CameraSessionTracker),
		-- Phase 12.5 item 6: subscribes to ProfileStore's global diagnostic
		-- signals. No dependencies, no dependents -- placed early so it's
		-- listening before any Reward operation could fire them.
		require(ServerScriptService.GameService.Reward.RewardStoreDiagnostics),
		require(ServerScriptService.GameService.Lobby.LobbyDeathPolicy),
		-- LaunchGate before its registrants (RewardLaunchHook, QueueService's
		-- own "Roster" precondition): registry before registrant.
		require(ServerScriptService.GameService.Lobby.LaunchGate),
		require(ServerScriptService.GameService.Reward.RewardLaunchHook),
		require(ServerScriptService.GameService.Lobby.MatchLauncher),
		require(ServerScriptService.GameService.Lobby.ArrivalService),
		require(ServerScriptService.GameService.Lobby.PartyService),
		-- QueueService before its own caller: it's the caller of MatchLauncher
		-- and the registrant of LaunchGate's "Roster" precondition -- callee
		-- before caller, registry before registrant.
		require(ServerScriptService.GameService.Lobby.QueueService),
		-- QueuePadService last: it's the sensor that drives QueueService, and
		-- it registers pads into it -- same callee-before-caller rule.
		require(ServerScriptService.GameService.Lobby.QueuePadService),
	}

	for _, service in ipairs(services) do
		service.Start()
	end
end

return LobbyBoot
