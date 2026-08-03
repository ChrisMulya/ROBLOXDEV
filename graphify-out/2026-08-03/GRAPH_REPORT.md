# Graph Report - ROBLOX-DEV  (2026-08-03)

## Corpus Check
- 273 files · ~94,190 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1225 nodes · 2155 edges · 92 communities (82 shown, 10 thin omitted)
- Extraction: 77% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 501 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2ecea965`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau
- CameraSession
- Monster System Blueprint
- Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau
- Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau
- Lobby/ServerScriptService/GameService/Reward/RewardService.luau
- Reward System
- Lobby/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau
- Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Lobby/ServerScriptService/GameService/Player/StartGame.luau
- Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau
- Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau
- Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau
- Lobby/ServerScriptService/GameService/Reward/RewardStore.luau
- PlayerStats ModuleScript
- Inventory & Shop System
- Camera Framework
- Map0_Test/ServerScriptService/GameService/Reward/RewardStore.luau
- Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau
- CameraFlashEffect
- FloatingShotText
- Remotes (Shared Utility)
- MonsterSensing
- CameraStats
- Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- States/Chase
- Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau
- Chase.Update
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau
- Chase.Update
- Map0_Test/ServerScriptService/GameService/Match/MatchClock.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau
- Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Planned.md
- Lobby/ServerScriptService/GameService/Lobby/QueueService.luau
- Lobby/ServerScriptService/GameService/Match/ReturnToLobbyService.luau
- Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau
- Map0_Test/ServerScriptService/GameService/Player/StartGame.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau
- evaluate
- onCharacterAdded
- Lobby/ServerScriptService/GameService/Reward/CaptureGuard.luau
- Lobby/ServerScriptService/GameService/Match/MatchManager.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchCleanup.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraStats.luau
- Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau
- Map0_Test/ServerScriptService/GameService/Monster/EncounterDirector.luau
- ServerRole.AssertGameServer
- Lobby/ReplicatedStorage/Modules/Camera/CameraToolController.luau
- onCharacterAdded
- Lobby/StarterPlayerScripts/ShotFeedbackHandler.local.luau
- ServerRole.AssertGameServer
- Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau
- Map0_Test/ServerScriptService/GameService/Monster/MonsterAgent.luau
- evaluate
- Lobby/ServerScriptService/GameService/Match/MatchArrival.luau
- Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau
- Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau

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
- `MatchManager.RequestTransition()` --calls--> `MatchStates.IsValid()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Match/MatchManager.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
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

## Communities (92 total, 10 thin omitted)

### Community 0 - "Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau"
Cohesion: 0.17
Nodes (14): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.SetInCamera(), CameraState.SetMovementSettings() (+6 more)

### Community 1 - "CameraSession"
Cohesion: 0.20
Nodes (12): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, CameraEffects, CameraSession, CameraToolController, CameraToolWatcher (LocalScript), Currency UI, CurrencyUI Connection Leak (Deferred) (+4 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.15
Nodes (16): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), PhotoCapture (server), Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk), Monster System Blueprint (+8 more)

### Community 3 - "Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (37): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get(), bindCharacter(), DeathService.Start() (+29 more)

### Community 4 - "Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (38): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get(), bindCharacter(), DeathService.Start() (+30 more)

### Community 5 - "Lobby/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.12
Nodes (19): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+11 more)

### Community 6 - "Reward System"
Cohesion: 0.06
Nodes (30): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+22 more)

### Community 7 - "Lobby/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 8 - "Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (27): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+19 more)

### Community 9 - "Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (26): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+18 more)

### Community 10 - "Lobby/ServerScriptService/GameService/Player/StartGame.luau"
Cohesion: 0.09
Nodes (18): CameraState.GetWalkSpeedMultiplier(), LoadoutService.GetCameraId(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set(), PlayerStats.Get(), CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot() (+10 more)

### Community 11 - "Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.10
Nodes (20): ensureBuilt(), MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show() (+12 more)

### Community 12 - "Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.08
Nodes (29): CameraStability.IsMoving(), CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers() (+21 more)

### Community 13 - "Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.10
Nodes (20): ensureBuilt(), MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show() (+12 more)

### Community 14 - "Lobby/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.13
Nodes (26): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), checkProgression(), rollbackProgression(), getOrCreateLeaderstats() (+18 more)

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
Cohesion: 0.12
Nodes (26): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), RemoveAllSlot.ClearPlayerTools(), onPlayerAdded(), onPlayerRemoving(), checkProgression(), rollbackProgression() (+18 more)

### Community 19 - "Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.18
Nodes (11): MatchStates.Validate(), PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), GameBoot.Start(), guardNonReservedServer() (+3 more)

### Community 24 - "CameraStats"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 25 - "Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.19
Nodes (11): MatchStates.AcceptsJoins(), MatchStates.IsGameplayActive(), MatchStates.IsScoringActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsValid(), MatchStates.MonstersSpawn(), MatchManager.Get(), loadIfNeeded() (+3 more)

### Community 26 - "States/Chase"
Cohesion: 0.33
Nodes (6): CameraShelfHandler (server), Cooldown (Shared Utility), MonsterDamage, MonsterMovement, States/Chase, States/Checking

### Community 27 - "Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.15
Nodes (13): MatchStates.Validate(), PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), GameBoot.Start(), guardNonReservedServer() (+5 more)

### Community 28 - "Chase.Update"
Cohesion: 0.25
Nodes (3): MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 29 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.05
Nodes (55): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+47 more)

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

### Community 36 - "Lobby/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.08
Nodes (26): MatchConfig.Get(), LaunchGate.Check(), LaunchGate.RegisterPrecondition(), LaunchGate.RegisterRollback(), LaunchGate.Rollback(), LaunchGate.Start(), onPlayerRemoving(), PartyService.GetLeader() (+18 more)

### Community 37 - "Lobby/ServerScriptService/GameService/Match/ReturnToLobbyService.luau"
Cohesion: 0.60
Nodes (5): attemptReturn(), buildTeleportData(), handleInitFailed(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 38 - "Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.10
Nodes (26): MatchConfig.Get(), LaunchGate.Check(), LaunchGate.RegisterPrecondition(), LaunchGate.RegisterRollback(), LaunchGate.Rollback(), LaunchGate.Start(), onPlayerRemoving(), PartyService.GetLeader() (+18 more)

### Community 39 - "Map0_Test/ServerScriptService/GameService/Player/StartGame.luau"
Cohesion: 0.09
Nodes (18): CameraState.GetWalkSpeedMultiplier(), LoadoutService.GetCameraId(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set(), PlayerStats.Get(), CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot() (+10 more)

### Community 40 - "Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 41 - "evaluate"
Cohesion: 0.20
Nodes (8): PlayerStates.CountsAsActive(), MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), evaluate(), MatchEndCondition.Start(), MatchParticipants.All(), MatchParticipants.Seed()

### Community 42 - "onCharacterAdded"
Cohesion: 0.33
Nodes (6): MatchStates.IsKitGranted(), MatchCleanup.RegisterTeardownStep(), MatchParticipants.IsParticipant(), KitLifecycleHook.Start(), onCharacterAdded(), StartGameService.ResetKit()

### Community 43 - "Lobby/ServerScriptService/GameService/Reward/CaptureGuard.luau"
Cohesion: 0.18
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 44 - "Lobby/ServerScriptService/GameService/Match/MatchManager.luau"
Cohesion: 0.24
Nodes (15): MatchStates.CanTransition(), MatchStates.IsTerminal(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying(), runWaitingForPlayers() (+7 more)

### Community 45 - "Map0_Test/ServerScriptService/GameService/Match/MatchCleanup.luau"
Cohesion: 0.32
Nodes (6): MatchCleanup.RegisterSaveStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), RewardCleanupHook.Start(), RewardStore.SaveAll()

### Community 46 - "Lobby/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 47 - "Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.06
Nodes (16): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+8 more)

### Community 49 - "Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.24
Nodes (7): MatchParticipants.All(), MatchParticipants.Seed(), ensureMatchInfoFolder(), MatchReplicator.Start(), buildPerPlayer(), MatchResultBuilder.Build(), MatchResultBuilder.Start()

### Community 50 - "Lobby/ReplicatedStorage/Modules/Camera/CameraStats.luau"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 51 - "Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau"
Cohesion: 0.24
Nodes (10): cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill() (+2 more)

### Community 52 - "Map0_Test/ServerScriptService/GameService/Monster/EncounterDirector.luau"
Cohesion: 0.24
Nodes (10): cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill() (+2 more)

### Community 53 - "ServerRole.AssertGameServer"
Cohesion: 0.28
Nodes (7): ServerRole.AssertGameServer(), MatchManager.GetElapsed(), MatchManager.Start(), buildPerPlayer(), MatchResultBuilder.RegisterContributor(), MatchResultBuilder.Start(), RewardResultHook.Start()

### Community 54 - "Lobby/ReplicatedStorage/Modules/Camera/CameraToolController.luau"
Cohesion: 0.39
Nodes (5): CameraToolController.Init(), fireEquippedChanged(), onCharacterAdded(), tryInit(), watchContainer()

### Community 55 - "onCharacterAdded"
Cohesion: 0.33
Nodes (6): MatchStates.IsKitGranted(), MatchCleanup.RegisterTeardownStep(), MatchParticipants.IsParticipant(), KitLifecycleHook.Start(), onCharacterAdded(), StartGameService.ResetKit()

### Community 57 - "ServerRole.AssertGameServer"
Cohesion: 0.24
Nodes (8): ServerRole.AssertGameServer(), MatchCleanup.RegisterSaveStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), MatchResultBuilder.RegisterContributor(), RewardCleanupHook.Start(), RewardResultHook.Start()

### Community 58 - "Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau"
Cohesion: 0.53
Nodes (4): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick()

### Community 59 - "Lobby/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 60 - "Map0_Test/ServerScriptService/GameService/Monster/MonsterAgent.luau"
Cohesion: 0.53
Nodes (4): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick()

### Community 61 - "evaluate"
Cohesion: 0.50
Nodes (4): PlayerStates.CountsAsActive(), evaluate(), MatchEndCondition.Start(), PlayerStateService.GetAll()

### Community 62 - "Lobby/ServerScriptService/GameService/Match/MatchArrival.luau"
Cohesion: 0.67
Nodes (3): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom()

### Community 64 - "Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau"
Cohesion: 0.31
Nodes (8): ensureMatchInfoFolder(), MatchReplicator.Start(), MatchResultBuilder.Build(), attemptReturn(), buildTeleportData(), handleInitFailed(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 65 - "Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

### Community 66 - "Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

## Ambiguous Edges - Review These
- `Graphify Knowledge Graph Workflow` → `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **62 isolated node(s):** `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point`, `Contract 3 — Reward routing`, `⚠ Security — this must land before the payout` (+57 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `MonsterService.Spawn()` connect `Map0_Test/ServerScriptService/GameService/Monster/EncounterDirector.luau` to `Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau`, `Map0_Test/ServerScriptService/GameService/Monster/MonsterAgent.luau`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Why does `MonsterService.Spawn()` connect `Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau` to `Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau`, `Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `ServerRole.AssertGameServer()` connect `ServerRole.AssertGameServer` to `Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau`, `Lobby/ServerScriptService/GameService/Match/ReturnToLobbyService.luau`, `onCharacterAdded`, `Lobby/ServerScriptService/GameService/Match/MatchManager.luau`, `Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau`, `Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau`, `Lobby/ServerScriptService/GameService/Monster/EncounterDirector.luau`, `Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau`, `evaluate`, `Lobby/ServerScriptService/GameService/Match/MatchArrival.luau`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 14 INFERRED edges - model-reasoned connections that need verification._