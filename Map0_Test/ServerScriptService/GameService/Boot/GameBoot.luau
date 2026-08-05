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
		-- Phase 12.5 item 5: runs on both places, no dependents in this
		-- list -- placed early so IsInCamera is truthful as soon as the
		-- server is up, same reasoning as PlayerStateService above.
		require(ServerScriptService.GameService.Camera.CameraSessionTracker),
		-- Server-owned Humanoid movement budget (WalkSpeed/JumpHeight). No
		-- dependencies, but must be listening before MatchSpawner loads any
		-- character -- placed with the other early always-on services.
		require(ServerScriptService.GameService.Player.CharacterMovementService),
		-- Phase 12.5 item 6: subscribes to ProfileStore's global diagnostic
		-- signals. No dependencies, no dependents -- placed early so it's
		-- listening before any Reward operation could fire them.
		require(ServerScriptService.GameService.Reward.RewardStoreDiagnostics),
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
		-- Before RewardResultHook, which reads it: the per-match reward delta
		-- accumulator must be subscribed to RewardService.Granted before any
		-- reward can be granted.
		require(ServerScriptService.GameService.Reward.MatchEarnings),
		-- First MatchResultBuilder contributor -- registry before registrant,
		-- same rule as RewardCleanupHook above.
		require(ServerScriptService.GameService.Reward.RewardResultHook),
		-- Second contributor ("Player" -> display name for the end-of-match
		-- scoreboard). Same registry-before-registrant rule.
		require(ServerScriptService.GameService.Match.MatchRosterHook),
		-- Registers a teardown step into MatchCleanup's registry (same rule
		-- as RewardCleanupHook/RewardResultHook above).
		require(ServerScriptService.GameService.Player.KitLifecycleHook),
		-- Same rule again: registers "MonsterTeardown" into MatchCleanup.
		require(ServerScriptService.GameService.Monster.EncounterDirector),
		require(ServerScriptService.GameService.Match.ReturnToLobbyService),
		require(ServerScriptService.GameService.Match.MatchClock),
		-- Loads characters for the roster once WaitingForPlayers begins.
		require(ServerScriptService.GameService.Match.MatchSpawner),
		require(ServerScriptService.GameService.Death.DeathService),
		require(ServerScriptService.GameService.Spectate.SpectateService),
		-- Third MatchResultBuilder contributor ("Stats" -> survival time +
		-- capture counts). After DeathService: subscribes to
		-- PlayerStateService.StateChanged for the Dead transition, and
		-- DeathService is the only thing that ever fires it into Dead.
		require(ServerScriptService.GameService.Match.MatchStats),
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
