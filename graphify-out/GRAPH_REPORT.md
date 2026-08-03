# Graph Report - ROBLOX-DEV  (2026-08-04)

## Corpus Check
- 283 files · ~116,606 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1362 nodes · 2392 edges · 94 communities (85 shown, 9 thin omitted)
- Extraction: 78% EXTRACTED · 22% INFERRED · 0% AMBIGUOUS · INFERRED: 535 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e408d28d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau
- CameraSession
- Monster System Blueprint
- Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau
- Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau
- Lobby/ServerScriptService/GameService/Reward/RewardService.luau
- Reward System
- Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Lobby/ReplicatedStorage/Modules/Shared/Signal.luau
- Lobby/ReplicatedStorage/Modules/Loadout/LoadoutService.luau
- Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau
- Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau
- Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau
- Lobby/ServerScriptService/GameService/Reward/RewardStore.luau
- PlayerStats ModuleScript
- Inventory & Shop System
- Camera Framework
- Map0_Test/ServerScriptService/GameService/Reward/RewardStore.luau
- Lobby/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau
- CameraFlashEffect
- FloatingShotText
- Remotes (Shared Utility)
- MonsterSensing
- CameraStats
- Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- States/Chase
- Lobby/ServerScriptService/Vendor/ProfileStore.luau
- Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraToolController.luau
- Chase.Update
- Map0_Test/ServerScriptService/GameService/Match/MatchClock.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau
- Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Planned.md
- PhotoCapture (server)
- Map0_Test/ServerScriptService/GameService/Monster/MonsterAgent.luau
- Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau
- Map0_Test/ReplicatedStorage/Modules/Loadout/LoadoutService.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau
- Map0_Test/ServerScriptService/GameService/Reward/CaptureGuard.luau
- Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- Lobby/ServerScriptService/GameService/Match/MatchManager.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau
- Map0_Test/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau
- Lobby/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraStats.luau
- Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau
- Map0_Test/ServerScriptService/GameService/Monster/EncounterDirector.luau
- MatchReplicator.Start
- Lobby/StarterPlayerScripts/ShotFeedbackHandler.local.luau
- Map0_Test/ServerScriptService/Vendor/ProfileStore.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraState.luau
- Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau
- Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau
- Map0_Test/StarterPlayerScripts/CameraToolWatcher.local.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau
- evaluate
- Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau
- Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau
- Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau
- Phase 12.5 — Close the Phase 12 deviations
- Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Lobby/ServerScriptService/GameService/Lobby/QueueService.luau
- CheckXpMigration.luau

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 18 edges
2. `CameraSession.Enter()` - 18 edges
3. `ServerRole.AssertGameServer()` - 16 edges
4. `ServerRole.AssertGameServer()` - 16 edges
5. `Remotes.Get()` - 12 edges
6. `Remotes.Get()` - 12 edges
7. `Reward System` - 12 edges
8. `SpectateService.SetTarget()` - 11 edges
9. `SpectateService.SetTarget()` - 11 edges
10. `CameraStats.GetStats()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `Graphify Knowledge Graph Workflow` --conceptually_related_to--> `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md → MAINHANDOFF.md
- `SpectateService.SetTarget()` --calls--> `MatchStates.IsSpectateAllowed()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- `isScoringActive()` --calls--> `MatchStates.IsScoringActive()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Reward/RewardService.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- `SpectateService.SetTarget()` --calls--> `PlayerStates.CanSpectate()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau → Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (94 total, 9 thin omitted)

### Community 0 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 1 - "CameraSession"
Cohesion: 0.20
Nodes (12): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, CameraEffects, CameraSession, CameraToolController, CameraToolWatcher (LocalScript), Currency UI, CurrencyUI Connection Leak (Deferred) (+4 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.29
Nodes (8): Monster System Blueprint, MonsterAgent, MonsterAggression, MonsterService, MonsterStats, States/Lurk, States/Wandering, TransitionChance Anti-Solve Valve

### Community 3 - "Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.20
Nodes (21): PlayerStates.CanControlCharacter(), Remotes.Get(), MatchParticipants.GetPresent(), PlayerStateService.Get(), assignBest(), fireSync(), onMatchStateChanged(), onPlayerRemoving() (+13 more)

### Community 4 - "Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (40): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), PlayerStates.Validate(), Remotes.Get(), LobbyBoot.Start(), DeathPolicy.Get() (+32 more)

### Community 5 - "Lobby/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.08
Nodes (28): CameraStability.IsMoving(), CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers() (+20 more)

### Community 6 - "Reward System"
Cohesion: 0.06
Nodes (30): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+22 more)

### Community 7 - "Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.08
Nodes (4): ArrivalService.Start(), handleArrival(), MatchLauncher.Launch(), MatchLauncher.Start()

### Community 8 - "Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (26): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+18 more)

### Community 9 - "Lobby/ReplicatedStorage/Modules/Shared/Signal.luau"
Cohesion: 0.11
Nodes (17): PlayerStates.CanTransition(), PlayerStates.IsValid(), DeathPolicy.Get(), bindCharacter(), DeathService.Start(), onCharacterAdded(), onHumanoidDied(), bindCharacter() (+9 more)

### Community 10 - "Lobby/ReplicatedStorage/Modules/Loadout/LoadoutService.luau"
Cohesion: 0.08
Nodes (23): CameraState.GetWalkSpeedMultiplier(), attempt(), keyFor(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get() (+15 more)

### Community 11 - "Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.09
Nodes (22): ensureBuilt(), QueueHud.Hide(), QueueHud.SetMessage(), MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel() (+14 more)

### Community 12 - "Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.11
Nodes (20): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+12 more)

### Community 13 - "Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.09
Nodes (22): ensureBuilt(), QueueHud.Hide(), QueueHud.SetMessage(), MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel() (+14 more)

### Community 14 - "Lobby/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.11
Nodes (28): LoadoutService.ClearSession(), RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), RemoveAllSlot.ClearPlayerTools(), onPlayerAdded(), onPlayerRemoving(), checkProgression() (+20 more)

### Community 15 - "PlayerStats ModuleScript"
Cohesion: 0.25
Nodes (8): CameraInventory (server), CameraSessionTracker (server), CameraShelfSwap (server), CurrentCamera Player Attribute, LinearVelocity-based Movement, PlayerStats ModuleScript, Reactive HUD (BindableEvent), Sprint/Stamina System

### Community 16 - "Inventory & Shop System"
Cohesion: 0.29
Nodes (7): BuyHandler, Inventory & Shop System, IsEmpty Attribute, KitGiven Attribute, Proximity Shop GUI, ShopFillSlot, StartGame / EndGame Lifecycle Modules

### Community 17 - "Camera Framework"
Cohesion: 0.22
Nodes (9): Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraId Attribute, CameraState, Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk) (+1 more)

### Community 18 - "Map0_Test/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.12
Nodes (27): LoadoutService.ClearSession(), RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), checkProgression(), onLaunchAborted() (+19 more)

### Community 19 - "Lobby/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau"
Cohesion: 0.36
Nodes (6): bootstrap(), considerInstance(), findLabel(), refresh(), QueuePadLabels.Counting(), QueuePadLabels.Format()

### Community 24 - "CameraStats"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 25 - "Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.17
Nodes (13): MatchStates.AcceptsJoins(), MatchStates.IsGameplayActive(), MatchStates.IsKitGranted(), MatchStates.IsScoringActive(), MatchStates.IsSpectateAllowed(), MatchStates.MonstersSpawn(), MatchManager.Get(), loadIfNeeded() (+5 more)

### Community 26 - "States/Chase"
Cohesion: 0.33
Nodes (6): CameraShelfHandler (server), Cooldown (Shared Utility), MonsterDamage, MonsterMovement, States/Chase, States/Checking

### Community 27 - "Lobby/ServerScriptService/Vendor/ProfileStore.luau"
Cohesion: 0.10
Nodes (4): AcquireRunnerThreadAndCallEventHandler(), ProfileStore:VersionQuery(), ProfileVersionQuery.New(), RunEventHandlerInFreeThread()

### Community 28 - "Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau"
Cohesion: 0.16
Nodes (7): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 29 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraToolController.luau"
Cohesion: 0.20
Nodes (12): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.SetMovementSettings(), CameraToolController.GetEquipped() (+4 more)

### Community 30 - "Chase.Update"
Cohesion: 0.25
Nodes (3): MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 31 - "Map0_Test/ServerScriptService/GameService/Match/MatchClock.luau"
Cohesion: 0.47
Nodes (8): config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying(), runWaitingForPlayers(), MatchManager.Is(), MatchParticipants.CountActive()

### Community 32 - "Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.17
Nodes (15): MatchStates.AcceptsJoins(), MatchStates.CanTransition(), MatchStates.IsGameplayActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), MatchStates.MonstersSpawn(), MatchManager.Abort() (+7 more)

### Community 33 - "Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 34 - "Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 35 - "Planned.md"
Cohesion: 0.12
Nodes (15): Blocking / must clear before 8V, Current Architecture, Current Phase, Current Verification Status, Deferred by decision, Development Summary, Next Session Plan, Not Yet Verified (+7 more)

### Community 36 - "PhotoCapture (server)"
Cohesion: 0.33
Nodes (6): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), CanCapture Attribute, PhotoCapture (server), CanCapture Attribute (Monster Model), Grey Cube MVP Vertical Slice

### Community 37 - "Map0_Test/ServerScriptService/GameService/Monster/MonsterAgent.luau"
Cohesion: 0.53
Nodes (4): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick()

### Community 38 - "Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.08
Nodes (45): MatchConfig.Get(), ServerRole.AssertLobbyServer(), LaunchGate.Check(), LaunchGate.OnLaunchAborted(), LaunchGate.OnLaunched(), LaunchGate.RegisterOnLaunchAborted(), LaunchGate.RegisterOnLaunched(), LaunchGate.RegisterPrecondition() (+37 more)

### Community 39 - "Map0_Test/ReplicatedStorage/Modules/Loadout/LoadoutService.luau"
Cohesion: 0.08
Nodes (23): CameraState.GetWalkSpeedMultiplier(), attempt(), keyFor(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get() (+15 more)

### Community 40 - "Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.05
Nodes (55): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+47 more)

### Community 41 - "Map0_Test/ServerScriptService/GameService/Reward/CaptureGuard.luau"
Cohesion: 0.22
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 42 - "Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau"
Cohesion: 0.18
Nodes (9): MatchStates.Validate(), PlayerStates.CanSpectate(), PlayerStates.CountsAsActive(), PlayerStates.Validate(), GameBoot.Start(), guardNonReservedServer(), LobbyBoot.Start(), evaluate() (+1 more)

### Community 43 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 44 - "Lobby/ServerScriptService/GameService/Match/MatchManager.luau"
Cohesion: 0.24
Nodes (15): MatchStates.CanTransition(), MatchStates.IsTerminal(), MatchStates.IsValid(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying() (+7 more)

### Community 45 - "Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.18
Nodes (9): MatchStates.IsKitGranted(), MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchCleanup.RegisterTeardownStep(), MatchParticipants.IsParticipant(), MatchParticipants.Seed(), KitLifecycleHook.Start() (+1 more)

### Community 46 - "Map0_Test/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau"
Cohesion: 0.36
Nodes (6): bootstrap(), considerInstance(), findLabel(), refresh(), QueuePadLabels.Counting(), QueuePadLabels.Format()

### Community 47 - "Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.05
Nodes (18): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+10 more)

### Community 48 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 49 - "Lobby/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 50 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraStats.luau"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 51 - "Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau"
Cohesion: 0.24
Nodes (10): cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill() (+2 more)

### Community 52 - "Map0_Test/ServerScriptService/GameService/Monster/EncounterDirector.luau"
Cohesion: 0.24
Nodes (10): cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill() (+2 more)

### Community 53 - "MatchReplicator.Start"
Cohesion: 0.31
Nodes (7): MatchManager.GetElapsed(), MatchParticipants.All(), ensureMatchInfoFolder(), MatchReplicator.Start(), buildPerPlayer(), MatchResultBuilder.Build(), MatchResultBuilder.Start()

### Community 55 - "Map0_Test/ServerScriptService/Vendor/ProfileStore.luau"
Cohesion: 0.10
Nodes (4): AcquireRunnerThreadAndCallEventHandler(), ProfileStore:VersionQuery(), ProfileVersionQuery.New(), RunEventHandlerInFreeThread()

### Community 56 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraState.luau"
Cohesion: 0.28
Nodes (4): CameraState.SetInCamera(), CameraState.SetStable(), fireListeners(), fireStableListeners()

### Community 57 - "Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.15
Nodes (16): resolve(), ServerRole.AssertGameServer(), ServerRole.Get(), ServerRole.Is(), MatchCleanup.RegisterSaveStep(), MatchManager.GetElapsed(), MatchResultBuilder.Build(), MatchResultBuilder.RegisterContributor() (+8 more)

### Community 58 - "Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau"
Cohesion: 0.60
Nodes (4): MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout()

### Community 59 - "Map0_Test/StarterPlayerScripts/CameraToolWatcher.local.luau"
Cohesion: 0.83
Nodes (3): onCharacterAdded(), tryInit(), watchContainer()

### Community 60 - "Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.18
Nodes (12): resolve(), ServerRole.AssertGameServer(), ServerRole.Get(), ServerRole.Is(), MatchCleanup.RegisterSaveStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout() (+4 more)

### Community 61 - "evaluate"
Cohesion: 0.50
Nodes (4): PlayerStates.CountsAsActive(), evaluate(), MatchEndCondition.Start(), PlayerStateService.GetAll()

### Community 62 - "Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.18
Nodes (9): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.All(), MatchParticipants.IsParticipant(), MatchParticipants.Seed(), ensureMatchInfoFolder(), MatchReplicator.Start() (+1 more)

### Community 64 - "Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau"
Cohesion: 0.20
Nodes (10): MatchStates.Validate(), GameBoot.Start(), guardNonReservedServer(), MatchLauncher.Launch(), MatchLauncher.Start(), attemptReturn(), buildTeleportData(), handleInitFailed() (+2 more)

### Community 65 - "Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

### Community 66 - "Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

### Community 94 - "Phase 12.5 — Close the Phase 12 deviations"
Cohesion: 0.11
Nodes (17): 1. The v1 migration gate is one-shot — live data-loss path, 2. `OnLaunched` fires on request-accepted, not arrival — roadmap R-3, resurfaced, 3. The two save-timeout constants are coupled but nothing enforces it, 4. Progression precondition fails the whole batch over one departed player, 5. `CameraSessionTracker` module-scope side effects — the real "found, not fixed", 6. ProfileStore's diagnostic surface has zero readers; Mock is unused, Context, Fix (+9 more)

### Community 100 - "Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (27): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+19 more)

### Community 101 - "Lobby/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.08
Nodes (45): MatchConfig.Get(), ServerRole.AssertLobbyServer(), LaunchGate.Check(), LaunchGate.OnLaunchAborted(), LaunchGate.OnLaunched(), LaunchGate.RegisterOnLaunchAborted(), LaunchGate.RegisterOnLaunched(), LaunchGate.RegisterPrecondition() (+37 more)

### Community 109 - "CheckXpMigration.luau"
Cohesion: 0.39
Nodes (7): classify(), describeTotals(), keyFor(), listAllV1UserIds(), read(), reportVerbose(), waitForBudget()

## Ambiguous Edges - Review These
- `Graphify Knowledge Graph Workflow` → `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **72 isolated node(s):** `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point`, `Contract 3 — Reward routing`, `⚠ Security — this must land before the payout` (+67 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `MonsterService.Spawn()` connect `Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau` to `Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau`, `Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `MonsterDamage.TryKill()` connect `Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau` to `Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 14 INFERRED edges - model-reasoned connections that need verification._