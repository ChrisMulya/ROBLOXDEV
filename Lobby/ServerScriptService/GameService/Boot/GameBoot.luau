-- Ordered service list for the Game place. Same ordering convention as
-- LobbyBoot. Empty today -- MatchManager/PlayerStateService/DeathService/
-- SpectateService/etc. land in later phases and get added here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local ServerRole = require(ReplicatedStorage.Modules.Shared.ServerRole)
local PlaceIds = require(ReplicatedStorage.Modules.Shared.PlaceIds)
local MatchStates = require(ReplicatedStorage.Modules.Shared.MatchStates)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.PlayerStates)
local MatchDifficulty = require(ReplicatedStorage.Modules.Shared.MatchDifficulty)
local SpawnCategories = require(ReplicatedStorage.Modules.Shared.SpawnCategories)
local MatchSchedule = require(ReplicatedStorage.Modules.MatchTime.MatchSchedule)
local MatchPhases = require(ReplicatedStorage.Modules.MatchTime.MatchPhases)
local ExitConfig = require(ReplicatedStorage.Modules.Exit.ExitConfig)

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

	-- TEMP:DEV-BYPASS -- delete this whole block before shipping.
	-- Studio Play-test never has a PrivateServerId, so the guard below fires
	-- every time and GameBoot returns before starting a single service --
	-- which also makes the monster framework untestable locally.
	--
	-- Gated on IsStudio so it CANNOT affect a live server even if it ships by
	-- accident: a real non-reserved Game Server still gets guarded. Everything
	-- downstream already tolerates Studio -- MatchArrival seeds
	-- MatchParticipants from the local player when there's no teleport data,
	-- and MatchClock then takes RosterComplete -> Countdown -> Playing.
	--
	-- Find every piece of this with: grep -rn "TEMP:DEV-BYPASS"
	if RunService:IsStudio() then
		warn("[GameBoot] TEMP:DEV-BYPASS active -- booting a non-reserved server because this is Studio.")
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
	MatchDifficulty.Validate()
	SpawnCategories.Validate()
	-- Same reasoning: a malformed schedule (a gap between segments, a last
	-- segment that doesn't land on EndHour) becomes a loud boot failure
	-- rather than a clock that silently runs to the wrong time.
	MatchSchedule.Validate()
	MatchPhases.Validate()
	ExitConfig.Validate(MatchSchedule.Get("Default"))

	local services = {
		require(ServerScriptService.GameService.PlayerState.PlayerStateService),
		require(ServerScriptService.GameService.PlayerState.PlayerStateReplicator),
		-- Phase 12.5 item 5: runs on both places, no dependents in this
		-- list -- placed early so IsInCamera is truthful as soon as the
		-- server is up, same reasoning as PlayerStateService above.
		require(ServerScriptService.GameService.Camera.CameraSessionTracker),
		-- Per-player temporary stat deltas (Energy Drink, Pills, Adrenaline
		-- Shot, Brighter Flashlight). No dependencies, but must be listening
		-- before CharacterMovementService's onCharacterAdded calls
		-- GetStat -- publisher before consumer, same convention as every
		-- other pairing in this list.
		require(ServerScriptService.GameService.Player.PlayerEffects),
		-- Server-owned Humanoid movement budget (WalkSpeed/JumpHeight). No
		-- dependencies, but must be listening before MatchSpawner loads any
		-- character -- placed with the other early always-on services.
		require(ServerScriptService.GameService.Player.CharacterMovementService),
		-- Flashlight toggle. No dependencies (reads Player.Character directly
		-- off the request), placed with the other early always-on per-player
		-- services.
		require(ServerScriptService.GameService.Player.FlashlightService),
		-- Blueprint D5. After CharacterMovementService: reads
		-- IsSprinting(player) every Heartbeat, so the accessor must exist
		-- before this can query it (no ordering issue in practice --
		-- IsSprinting just reads a table -- but publisher-before-consumer
		-- is the convention this whole list follows). Before MonsterFramework,
		-- whose HearingSensor is D3's only current subscriber.
		require(ServerScriptService.GameService.Stimulus.FootstepEmitter),
		-- Blueprint D6. The sole subscriber FlashEvents has ever had. No
		-- ordering dependency on CameraShotHandler.legacy -- that file
		-- self-wires as a Script and requiring FlashEvents from either side
		-- resolves to the same cached Signal instance either way.
		require(ServerScriptService.GameService.Stimulus.FlashStimulusAdapter),
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
		-- Shared mission progress (Monster Photo score, Soft Objective count).
		-- After MatchManager, whose StateChanged it subscribes to for the
		-- WaitingForPlayers reset; MissionReplicator after MissionProgress,
		-- publisher before subscriber. Order-tolerant otherwise -- the
		-- RewardService.Awarded / ObjectiveService.StateChanged signals it
		-- also subscribes to are already wired by the time GameBoot runs
		-- (see Bootstrap.legacy.luau's pre-boot requires).
		require(ServerScriptService.GameService.Match.MissionProgress),
		require(ServerScriptService.GameService.Match.MissionReplicator),
		require(ServerScriptService.GameService.Match.MatchCleanup),
		-- Match Time System. After MatchCleanup because MatchTimeLighting
		-- registers a teardown step into it (registry before registrant),
		-- and after MatchManager because MatchTimeService subscribes to
		-- StateChanged (publisher before subscriber). Within the block:
		-- registry, then the publisher, then its three subscribers.
		require(ServerScriptService.GameService.MatchTime.MatchTimeEvents),
		-- The event announcer broadcast channel. Before any module that can
		-- call Announce (ExitAnnounceHook below), and order-tolerant otherwise
		-- -- its Start() only resolves a remote.
		require(ServerScriptService.GameService.MatchTime.MatchEventService),
		-- Exit System discovery + the hour-27 Alternate-unlock registration.
		-- Registry (ExitRegistry) before registrant (ExitState), and both
		-- before MatchTimeService.Start() begins sampling: ExitState.Start()
		-- registers into MatchTimeEvents, and that registration must land
		-- before the clock can dispatch past hour 27 (Debug schedules run
		-- fast enough for this to matter). ExitState also reads
		-- MissionProgress (required above) and MatchManager.StateChanged.
		require(ServerScriptService.GameService.Exit.ExitRegistry),
		require(ServerScriptService.GameService.Exit.ExitState),
		require(ServerScriptService.GameService.MatchTime.MatchTimeService),
		require(ServerScriptService.GameService.MatchTime.MatchTimeReplicator),
		require(ServerScriptService.GameService.MatchTime.MatchTimeLighting),
		-- Ends the match at 6 AM, replacing MatchClock's deleted runPlaying.
		-- MatchEndCondition above races it harmlessly -- RequestEnd is
		-- idempotent, so whoever fires first wins and the other no-ops.
		require(ServerScriptService.GameService.MatchTime.SunriseEndHook),
		-- Exit interaction + replication + result/cleanup hooks. After
		-- ExitState (the availability authority it reads), PlayerStateService
		-- (Alive/Escaped transitions), and MatchParticipants/MatchManager,
		-- all required above. Registry-before-registrant for the two hooks,
		-- same rule as RewardCleanupHook/PickupCleanupHook below.
		require(ServerScriptService.GameService.Exit.ExitService),
		require(ServerScriptService.GameService.Exit.ExitReplicator),
		-- Presentation for the authored world-space exit signs. After
		-- ExitState/ExitRegistry (both read) and MissionProgress (progress
		-- numbers); its Start() paints the pre-match text immediately.
		require(ServerScriptService.GameService.Exit.ExitLabel),
		-- Tints the marked Part green while its exit is usable. Same
		-- placement rule as ExitLabel: after ExitState/ExitRegistry, and its
		-- Start() captures the authored colours immediately.
		require(ServerScriptService.GameService.Exit.ExitVisuals),
		-- Announces the Alternate opening. After ExitState (the signal it
		-- subscribes to) and MatchEventService (the channel it fires into).
		require(ServerScriptService.GameService.Exit.ExitAnnounceHook),
		require(ServerScriptService.GameService.Exit.ExitResultHook),
		require(ServerScriptService.GameService.Exit.ExitCleanupHook),
		-- After MatchCleanup: registers a save step into its registry.
		-- Order-tolerant at boot (RegisterSaveStep just appends to a
		-- table), but this position keeps the list's dependency direction
		-- consistent with every other publisher-before-subscriber entry.
		require(ServerScriptService.GameService.Reward.RewardCleanupHook),
		-- Pickup System: needs PlayerStateService (Alive check),
		-- MatchManager + MatchParticipants (Cash handler's match-active/
		-- roster gates), and MatchCleanup (PickupCleanupHook registers a
		-- teardown step into it) -- all already required above. Registry
		-- before service before hook, same registry-before-registrant
		-- rule as RewardCleanupHook just above.
		require(ServerScriptService.GameService.Pickup.PickupRegistry),
		require(ServerScriptService.GameService.Pickup.PickupService),
		require(ServerScriptService.GameService.Pickup.PickupCleanupHook),
		-- Match-start spawn selection: thins hand-placed Cash/Objective/
		-- Document instances by difficulty x player count. After PickupRegistry
		-- and MatchCleanup (registers a teardown step into it, registry before
		-- registrant), and after MatchManager (subscribes to StateChanged) --
		-- all required above. Before MatchArrival, which is last and fires the
		-- WaitingForPlayers transition this reacts to.
		require(ServerScriptService.GameService.Match.SpawnSelection),
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
		-- Monster Framework. One entry: it starts MonsterRegistry ->
		-- MonsterScheduler -> EncounterDirector itself, in dependency order,
		-- so the boot list doesn't have to track its internals. Same rule
		-- again for its position here -- EncounterDirector registers
		-- "MonsterTeardown" into MatchCleanup and subscribes to MatchManager
		-- and MatchTimeService, all required above.
		require(ServerScriptService.GameService.Monster.MonsterFramework),
		require(ServerScriptService.GameService.Match.ReturnToLobbyService),
		require(ServerScriptService.GameService.Match.MatchClock),
		-- Loads characters for the roster once WaitingForPlayers begins.
		require(ServerScriptService.GameService.Match.MatchSpawner),
		require(ServerScriptService.GameService.Death.DeathService),
		-- Support-item gameplay (Motion Sensor, Compact Speaker, Portable
		-- CCTV, and the shared 3-second hold lifecycle). After DeathService
		-- (all four subscribe DeathService.Died), MonsterFramework (Motion
		-- Sensor/Compact Speaker both read MonsterRegistry.ForEach), and
		-- MatchCleanup (DeployableRegistry registers a teardown step into
		-- it, registry before registrant, same rule as RewardCleanupHook
		-- above) -- all required earlier in this list. Registry
		-- (DeployableRegistry) before the services that Track() into it.
		require(ServerScriptService.GameService.Item.ItemWorld.DeployableRegistry),
		require(ServerScriptService.GameService.Item.ItemWorld.MotionSensorService),
		require(ServerScriptService.GameService.Item.ItemWorld.SpeakerService),
		require(ServerScriptService.GameService.Item.ItemWorld.CCTVService),
		require(ServerScriptService.GameService.Item.ItemUseService),
		require(ServerScriptService.GameService.Spectate.SpectateService),
		-- Third MatchResultBuilder contributor ("Stats" -> survival time +
		-- capture counts). After DeathService: subscribes to
		-- PlayerStateService.StateChanged for the Dead transition, and
		-- DeathService is the only thing that ever fires it into Dead.
		require(ServerScriptService.GameService.Match.MatchStats),
		-- MatchLoadingGate before MatchArrival: it owns the first real
		-- transition (Loading -> WaitingForPlayers) now, gated on
		-- MatchArrival.Seeded plus every present participant's
		-- MatchClientReady report (or MatchClock's LoadingTimeout backstop,
		-- which this also starts). Must be listening on Seeded before
		-- MatchArrival can fire it -- registry before registrant, same rule
		-- as everything else in this list.
		require(ServerScriptService.GameService.Match.MatchLoadingGate),
		-- MatchArrival LAST: it seeds the roster and fires Seeded, so every
		-- subscriber above (MatchLoadingGate, MatchSpawner, etc.) must
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
