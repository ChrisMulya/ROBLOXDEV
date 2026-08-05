# Graph Report - ROBLOX-DEV  (2026-08-05)

## Corpus Check
- 301 files · ~140,721 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1502 nodes · 2694 edges · 103 communities (93 shown, 10 thin omitted)
- Extraction: 78% EXTRACTED · 22% INFERRED · 0% AMBIGUOUS · INFERRED: 581 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2d7cff81`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau
- CameraSession
- Monster System Blueprint
- Lobby/ServerScriptService/GameService/PlayerState/PlayerStateService.luau
- Map0_Test/ReplicatedStorage/Modules/Loadout/LoadoutService.luau
- Lobby/ServerScriptService/GameService/Reward/RewardService.luau
- Reward System
- Lobby/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau
- Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/Signal.luau
- Lobby/StarterPlayerScripts/MobileSprintButton.local.luau
- Lobby/ReplicatedStorage/Modules/UI/MatchReceipt.luau
- Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau
- Map0_Test/ReplicatedStorage/Modules/UI/MatchReceipt.luau
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
- Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau
- Chase.Update
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraState.luau
- Chase.Update
- Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau
- Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Planned.md
- Map0_Test/ServerScriptService/Vendor/ProfileStore.luau
- Lobby/ServerScriptService/Vendor/ProfileStore.luau
- Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau
- Lobby/ReplicatedStorage/Modules/Shared/Signal.luau
- ServerRole.AssertLobbyServer
- Map0_Test/ServerScriptService/GameService/Reward/CaptureGuard.luau
- Lobby/ServerScriptService/GameService/Match/MatchClock.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraToolController.luau
- Map0_Test/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau
- Map0_Test/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau
- Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchStats.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraStats.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchCleanup.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraToolController.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau
- Lobby/ServerScriptService/GameService/Reward/CaptureGuard.luau
- Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraStats.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau
- Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau
- ServerRole.AssertLobbyServer
- RemoveAllSlot.ClearPlayerTools
- Lobby/ServerScriptService/GameService/Match/MatchStats.luau
- Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau
- MonsterService.Spawn
- Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau
- Phase 12.5 — Close the Phase 12 deviations
- Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ServerScriptService/GameService/Lobby/QueueService.luau
- Map0_Test/StarterPlayerScripts/MobileSprintButton.local.luau
- Map0_Test/StarterPlayerScripts/ShotFeedbackHandler.local.luau
- Lobby/StarterPlayerScripts/ShotFeedbackHandler.local.luau
- CheckXpMigration.luau

## God Nodes (most connected - your core abstractions)
1. `ServerRole.AssertGameServer()` - 19 edges
2. `ServerRole.AssertGameServer()` - 19 edges
3. `CameraSession.Enter()` - 18 edges
4. `CameraSession.Enter()` - 18 edges
5. `ensureBuilt()` - 16 edges
6. `ensureBuilt()` - 16 edges
7. `Remotes.Get()` - 14 edges
8. `Remotes.Get()` - 14 edges
9. `Reward System` - 12 edges
10. `SpectateService.SetTarget()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `Graphify Knowledge Graph Workflow` --conceptually_related_to--> `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md → MAINHANDOFF.md
- `renderStats()` --calls--> `CaptureTargets.OrderedNames()`  [INFERRED]
  Lobby/ReplicatedStorage/Modules/UI/MatchReceipt.luau → Lobby/ReplicatedStorage/Modules/Reward/CaptureTargets.luau
- `SpectateService.SetTarget()` --calls--> `MatchStates.IsSpectateAllowed()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- `isScoringActive()` --calls--> `MatchStates.IsScoringActive()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Reward/RewardService.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (103 total, 10 thin omitted)

### Community 0 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 1 - "CameraSession"
Cohesion: 0.20
Nodes (12): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, CameraEffects, CameraSession, CameraToolController, CameraToolWatcher (LocalScript), Currency UI, CurrencyUI Connection Leak (Deferred) (+4 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.15
Nodes (16): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), PhotoCapture (server), Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk), Monster System Blueprint (+8 more)

### Community 3 - "Lobby/ServerScriptService/GameService/PlayerState/PlayerStateService.luau"
Cohesion: 0.16
Nodes (16): PlayerStates.CanTransition(), PlayerStates.IsValid(), DeathPolicy.Get(), bindCharacter(), DeathService.Start(), onCharacterAdded(), onHumanoidDied(), bindCharacter() (+8 more)

### Community 4 - "Map0_Test/ReplicatedStorage/Modules/Loadout/LoadoutService.luau"
Cohesion: 0.15
Nodes (16): attempt(), keyFor(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), CameraSessionTracker.IsInCamera(), CameraSessionTracker.Start(), CameraInventory.ClearSlot() (+8 more)

### Community 5 - "Lobby/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.11
Nodes (19): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.IsType(), CaptureTargets.OrderedNames(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+11 more)

### Community 6 - "Reward System"
Cohesion: 0.06
Nodes (30): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+22 more)

### Community 7 - "Lobby/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 8 - "Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (26): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+18 more)

### Community 9 - "Map0_Test/ReplicatedStorage/Modules/Shared/Signal.luau"
Cohesion: 0.07
Nodes (37): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get(), bindCharacter(), DeathService.Start() (+29 more)

### Community 10 - "Lobby/StarterPlayerScripts/MobileSprintButton.local.luau"
Cohesion: 0.06
Nodes (29): CameraState.GetWalkSpeedMultiplier(), buildCircleButton(), CameraTouchHud.Init(), CameraTouchHud.SetInCamera(), CameraTouchHud.Show(), ensureBuilt(), ensureReady(), isTouchDevice() (+21 more)

### Community 11 - "Lobby/ReplicatedStorage/Modules/UI/MatchReceipt.luau"
Cohesion: 0.07
Nodes (43): ensureBuilt(), QueueHud.Hide(), QueueHud.SetMessage(), CaptureTargets.Get(), MatchResultCodes.GetMessage(), ensureBuilt(), setBackpackVisible(), SpectateHud.Hide() (+35 more)

### Community 12 - "Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.11
Nodes (20): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.IsType(), CaptureTargets.OrderedNames(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+12 more)

### Community 13 - "Map0_Test/ReplicatedStorage/Modules/UI/MatchReceipt.luau"
Cohesion: 0.07
Nodes (43): ensureBuilt(), QueueHud.Hide(), QueueHud.SetMessage(), CaptureTargets.Get(), MatchResultCodes.GetMessage(), ensureBuilt(), setBackpackVisible(), SpectateHud.Hide() (+35 more)

### Community 14 - "Lobby/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.06
Nodes (45): attempt(), keyFor(), LoadoutService.ClearSession(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), RewardTypes.Get(), RewardTypes.Persistent() (+37 more)

### Community 15 - "PlayerStats ModuleScript"
Cohesion: 0.25
Nodes (8): CameraInventory (server), CameraSessionTracker (server), CameraShelfSwap (server), CurrentCamera Player Attribute, LinearVelocity-based Movement, PlayerStats ModuleScript, Reactive HUD (BindableEvent), Sprint/Stamina System

### Community 16 - "Inventory & Shop System"
Cohesion: 0.29
Nodes (7): BuyHandler, Inventory & Shop System, IsEmpty Attribute, KitGiven Attribute, Proximity Shop GUI, ShopFillSlot, StartGame / EndGame Lifecycle Modules

### Community 17 - "Camera Framework"
Cohesion: 0.29
Nodes (7): Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraId Attribute, CameraState, CanCapture Attribute, CanCapture Attribute (Monster Model), Grey Cube MVP Vertical Slice

### Community 18 - "Map0_Test/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.11
Nodes (28): LoadoutService.ClearSession(), RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), RemoveAllSlot.ClearPlayerTools(), onPlayerAdded(), onPlayerRemoving(), checkProgression() (+20 more)

### Community 19 - "Lobby/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau"
Cohesion: 0.36
Nodes (6): bootstrap(), considerInstance(), findLabel(), refresh(), QueuePadLabels.Counting(), QueuePadLabels.Format()

### Community 24 - "CameraStats"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 25 - "Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.15
Nodes (16): MatchStates.AcceptsJoins(), MatchStates.CanTransition(), MatchStates.IsGameplayActive(), MatchStates.IsScoringActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), MatchManager.Abort() (+8 more)

### Community 26 - "States/Chase"
Cohesion: 0.33
Nodes (6): CameraShelfHandler (server), Cooldown (Shared Utility), MonsterDamage, MonsterMovement, States/Chase, States/Checking

### Community 27 - "Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.09
Nodes (8): ArrivalService.Start(), handleArrival(), attemptReturn(), buildTeleportData(), handleInitFailed(), handleReturnRequest(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 28 - "Chase.Update"
Cohesion: 0.25
Nodes (3): MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 29 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraState.luau"
Cohesion: 0.17
Nodes (14): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.SetInCamera(), CameraState.SetMovementSettings() (+6 more)

### Community 30 - "Chase.Update"
Cohesion: 0.25
Nodes (3): MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 31 - "Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau"
Cohesion: 0.28
Nodes (4): CameraState.SetInCamera(), CameraState.SetStable(), fireListeners(), fireStableListeners()

### Community 32 - "Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau"
Cohesion: 0.19
Nodes (17): MatchStates.CanTransition(), MatchStates.IsTerminal(), PlayerStates.CountsAsActive(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying() (+9 more)

### Community 33 - "Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 34 - "Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 35 - "Planned.md"
Cohesion: 0.12
Nodes (15): Blocking / must clear before 8V, Current Architecture, Current Phase, Current Verification Status, Deferred by decision, Development Summary, Next Session Plan, Not Yet Verified (+7 more)

### Community 36 - "Map0_Test/ServerScriptService/Vendor/ProfileStore.luau"
Cohesion: 0.10
Nodes (4): AcquireRunnerThreadAndCallEventHandler(), ProfileStore:VersionQuery(), ProfileVersionQuery.New(), RunEventHandlerInFreeThread()

### Community 37 - "Lobby/ServerScriptService/Vendor/ProfileStore.luau"
Cohesion: 0.10
Nodes (4): AcquireRunnerThreadAndCallEventHandler(), ProfileStore:VersionQuery(), ProfileVersionQuery.New(), RunEventHandlerInFreeThread()

### Community 38 - "Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.10
Nodes (37): MatchConfig.Get(), LaunchGate.Check(), LaunchGate.OnLaunched(), onPlayerRemoving(), PartyService.GetLeader(), PartyService.GetParty(), PartyService.IsLeader(), PartyService.Join() (+29 more)

### Community 39 - "Lobby/ReplicatedStorage/Modules/Shared/Signal.luau"
Cohesion: 0.22
Nodes (3): MatchCleanup.Start(), runCleanup(), runWithTimeout()

### Community 40 - "ServerRole.AssertLobbyServer"
Cohesion: 0.15
Nodes (14): PlayerStates.Validate(), ServerRole.AssertLobbyServer(), LobbyBoot.Start(), LaunchGate.OnLaunchAborted(), LaunchGate.RegisterOnLaunchAborted(), LaunchGate.RegisterOnLaunched(), LaunchGate.RegisterPrecondition(), LaunchGate.Start() (+6 more)

### Community 41 - "Map0_Test/ServerScriptService/GameService/Reward/CaptureGuard.luau"
Cohesion: 0.18
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 42 - "Lobby/ServerScriptService/GameService/Match/MatchClock.luau"
Cohesion: 0.17
Nodes (16): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying() (+8 more)

### Community 43 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 44 - "Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.21
Nodes (20): PlayerStates.CanControlCharacter(), Remotes.Get(), PlayerStateService.Get(), assignBest(), fireSync(), onMatchStateChanged(), onPlayerRemoving(), onPlayerStateChanged() (+12 more)

### Community 45 - "Lobby/ReplicatedStorage/Modules/Camera/CameraToolController.luau"
Cohesion: 0.16
Nodes (15): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.SetMovementSettings(), CameraToolController.GetEquipped() (+7 more)

### Community 46 - "Map0_Test/ReplicatedStorage/Modules/Queue/QueuePadDisplay.luau"
Cohesion: 0.36
Nodes (6): bootstrap(), considerInstance(), findLabel(), refresh(), QueuePadLabels.Counting(), QueuePadLabels.Format()

### Community 47 - "Map0_Test/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 48 - "Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau"
Cohesion: 0.21
Nodes (7): MatchStates.Validate(), PlayerStates.CanSpectate(), PlayerStates.CountsAsActive(), PlayerStates.Validate(), GameBoot.Start(), guardNonReservedServer(), LobbyBoot.Start()

### Community 49 - "Map0_Test/ServerScriptService/GameService/Match/MatchStats.luau"
Cohesion: 0.33
Nodes (6): MatchGrade.Evaluate(), ensureCaptureRow(), MatchStats.Start(), onAwarded(), reset(), survivedSeconds()

### Community 50 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraStats.luau"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 51 - "Map0_Test/ServerScriptService/GameService/Match/MatchCleanup.luau"
Cohesion: 0.24
Nodes (10): MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints() (+2 more)

### Community 52 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraToolController.luau"
Cohesion: 0.39
Nodes (5): CameraToolController.Init(), fireEquippedChanged(), onCharacterAdded(), tryInit(), watchContainer()

### Community 53 - "Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.19
Nodes (10): MatchStates.IsKitGranted(), MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.CountActive(), MatchParticipants.GetPresent(), MatchParticipants.IsParticipant(), MatchParticipants.Seed() (+2 more)

### Community 54 - "Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.16
Nodes (13): MatchStates.AcceptsJoins(), MatchStates.IsGameplayActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsValid(), MatchStates.MonstersSpawn(), MatchStates.Validate(), GameBoot.Start(), guardNonReservedServer() (+5 more)

### Community 55 - "Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 56 - "Lobby/ServerScriptService/GameService/Reward/CaptureGuard.luau"
Cohesion: 0.22
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 57 - "Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.14
Nodes (14): resolve(), ServerRole.AssertGameServer(), ServerRole.Get(), ServerRole.Is(), MatchManager.GetElapsed(), buildPerPlayer(), MatchResultBuilder.Build(), MatchResultBuilder.RegisterContributor() (+6 more)

### Community 58 - "Lobby/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 59 - "Lobby/ReplicatedStorage/Modules/Camera/CameraStats.luau"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 60 - "Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.12
Nodes (16): resolve(), ServerRole.AssertGameServer(), ServerRole.Get(), ServerRole.Is(), MatchCleanup.RegisterSaveStep(), MatchManager.GetElapsed(), MatchManager.Start(), MatchResultBuilder.Build() (+8 more)

### Community 61 - "Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau"
Cohesion: 0.20
Nodes (12): MatchStates.MonstersSpawn(), MatchCleanup.RegisterTeardownStep(), cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter(), getCooldownTable() (+4 more)

### Community 62 - "ServerRole.AssertLobbyServer"
Cohesion: 0.16
Nodes (14): ServerRole.AssertLobbyServer(), LaunchGate.Check(), LaunchGate.OnLaunchAborted(), LaunchGate.OnLaunched(), LaunchGate.RegisterOnLaunchAborted(), LaunchGate.RegisterOnLaunched(), LaunchGate.RegisterPrecondition(), LaunchGate.Start() (+6 more)

### Community 63 - "RemoveAllSlot.ClearPlayerTools"
Cohesion: 0.38
Nodes (5): MatchStates.IsKitGranted(), MatchParticipants.IsParticipant(), RemoveAllSlot.ClearPlayerTools(), KitLifecycleHook.Start(), onCharacterAdded()

### Community 64 - "Lobby/ServerScriptService/GameService/Match/MatchStats.luau"
Cohesion: 0.33
Nodes (6): MatchGrade.Evaluate(), ensureCaptureRow(), MatchStats.Start(), onAwarded(), reset(), survivedSeconds()

### Community 65 - "Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.50
Nodes (8): applySubject(), ensureFreeCameraAnchor(), ensureSubjectGuard(), getCamera(), resolveSubject(), SpectateCameraController.SetTarget(), SpectateCameraController.Stop(), tryExitCameraSession()

### Community 66 - "Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.50
Nodes (8): applySubject(), ensureFreeCameraAnchor(), ensureSubjectGuard(), getCamera(), resolveSubject(), SpectateCameraController.SetTarget(), SpectateCameraController.Stop(), tryExitCameraSession()

### Community 75 - "MonsterService.Spawn"
Cohesion: 0.27
Nodes (8): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill(), MonsterService.Spawn()

### Community 80 - "Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau"
Cohesion: 0.53
Nodes (4): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick()

### Community 94 - "Phase 12.5 — Close the Phase 12 deviations"
Cohesion: 0.11
Nodes (17): 1. The v1 migration gate is one-shot — live data-loss path, 2. `OnLaunched` fires on request-accepted, not arrival — roadmap R-3, resurfaced, 3. The two save-timeout constants are coupled but nothing enforces it, 4. Progression precondition fails the whole batch over one departed player, 5. `CameraSessionTracker` module-scope side effects — the real "found, not fixed", 6. ProfileStore's diagnostic surface has zero readers; Mock is unused, Context, Fix (+9 more)

### Community 95 - "Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (26): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+18 more)

### Community 100 - "Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.09
Nodes (8): ArrivalService.Start(), handleArrival(), attemptReturn(), buildTeleportData(), handleInitFailed(), handleReturnRequest(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 101 - "Lobby/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.10
Nodes (35): MatchConfig.Get(), onPlayerRemoving(), PartyService.GetLeader(), PartyService.GetParty(), PartyService.IsLeader(), PartyService.Join(), PartyService.Leave(), removeFromCurrentParty() (+27 more)

### Community 102 - "Map0_Test/StarterPlayerScripts/MobileSprintButton.local.luau"
Cohesion: 0.06
Nodes (29): CameraState.GetWalkSpeedMultiplier(), buildCircleButton(), CameraTouchHud.Init(), CameraTouchHud.SetInCamera(), CameraTouchHud.Show(), ensureBuilt(), ensureReady(), isTouchDevice() (+21 more)

### Community 109 - "CheckXpMigration.luau"
Cohesion: 0.39
Nodes (7): classify(), describeTotals(), keyFor(), listAllV1UserIds(), read(), reportVerbose(), waitForBudget()

## Ambiguous Edges - Review These
- `Graphify Knowledge Graph Workflow` → `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **72 isolated node(s):** `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point`, `Contract 3 — Reward routing`, `⚠ Security — this must land before the payout` (+67 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `MonsterService.Spawn()` connect `Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau` to `Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau`, `Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `ServerRole.AssertGameServer()` connect `Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau` to `Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau`, `Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau`, `Map0_Test/ReplicatedStorage/Modules/Shared/Signal.luau`, `Map0_Test/ServerScriptService/GameService/Match/MatchStats.luau`, `Map0_Test/ServerScriptService/GameService/Match/MatchCleanup.luau`, `Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau`, `Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `ServerRole.AssertGameServer()` connect `Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau` to `Lobby/ServerScriptService/GameService/Match/MatchStats.luau`, `Lobby/ReplicatedStorage/Modules/Shared/Signal.luau`, `Lobby/ServerScriptService/GameService/Match/MatchClock.luau`, `Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau`, `Lobby/ServerScriptService/GameService/Reward/RewardStore.luau`, `Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau`, `Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau`, `Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau`, `Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau`, `RemoveAllSlot.ClearPlayerTools`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Are the 17 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 17 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._