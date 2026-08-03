# Graph Report - ROBLOX-DEV  (2026-08-03)

## Corpus Check
- 273 files · ~95,610 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1237 nodes · 2183 edges · 91 communities (83 shown, 8 thin omitted)
- Extraction: 77% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 505 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2e5ee63c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau
- Roblox Game Project Handoff
- Monster System Blueprint
- Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau
- Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau
- Lobby/ServerScriptService/GameService/Reward/RewardService.luau
- Reward System
- Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ReplicatedStorage/Modules/Loadout/LoadoutService.luau
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
- Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau
- Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Planned.md
- Lobby/ReplicatedStorage/Modules/Shared/Signal.luau
- Lobby/ServerScriptService/GameService/Match/ReturnToLobbyService.luau
- Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau
- Map0_Test/ReplicatedStorage/Modules/Loadout/LoadoutService.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau
- ServerRole.AssertGameServer
- Lobby/ServerScriptService/GameService/Reward/CaptureGuard.luau
- Lobby/ServerScriptService/GameService/Match/MatchManager.luau
- ServerRole.AssertGameServer
- Lobby/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- Map0_Test/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau
- Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraStats.luau
- MatchManager.Get
- MatchManager.Get
- MatchReplicator.Start
- Lobby/ReplicatedStorage/Modules/Camera/CameraToolController.luau
- Map0_Test/ServerScriptService/GameService/Objective/ObjectiveRegistry.luau
- PhotoCapture (server)
- Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau
- Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau
- Map0_Test/ServerScriptService/GameService/Monster/MonsterAgent.luau
- evaluate
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
- `setupCharacter()` --calls--> `CameraState.GetWalkSpeedMultiplier()`  [INFERRED]
  Lobby/StarterPlayerScripts/Playermovementcontroller.local.luau → Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau
- `MatchManager.RequestTransition()` --calls--> `MatchStates.IsValid()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Match/MatchManager.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- `SpectateService.SetTarget()` --calls--> `MatchStates.IsSpectateAllowed()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (91 total, 8 thin omitted)

### Community 0 - "Lobby/ReplicatedStorage/Modules/Camera/CameraState.luau"
Cohesion: 0.16
Nodes (15): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.GetWalkSpeedMultiplier(), CameraState.SetInCamera() (+7 more)

### Community 1 - "Roblox Game Project Handoff"
Cohesion: 0.29
Nodes (8): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, Currency UI, CurrencyUI Connection Leak (Deferred), Hard-Won Debugging Lessons, Local Filesystem <-> Studio Live Sync, Roblox Game Project Handoff, Trove (Shared Utility)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.19
Nodes (13): Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk), Monster System Blueprint, MonsterAgent, MonsterAggression, MonsterEvolution (+5 more)

### Community 3 - "Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (43): MatchStates.IsGameplayActive(), PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.CountsAsActive(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get() (+35 more)

### Community 4 - "Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (37): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get(), bindCharacter(), DeathService.Start() (+29 more)

### Community 5 - "Lobby/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.11
Nodes (20): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+12 more)

### Community 6 - "Reward System"
Cohesion: 0.06
Nodes (30): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+22 more)

### Community 7 - "Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.06
Nodes (16): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+8 more)

### Community 8 - "Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (27): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+19 more)

### Community 9 - "Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.05
Nodes (24): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+16 more)

### Community 10 - "Lobby/ReplicatedStorage/Modules/Loadout/LoadoutService.luau"
Cohesion: 0.09
Nodes (21): attempt(), keyFor(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set() (+13 more)

### Community 11 - "Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.10
Nodes (20): ensureBuilt(), MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show() (+12 more)

### Community 12 - "Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.08
Nodes (29): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf() (+21 more)

### Community 13 - "Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.10
Nodes (20): ensureBuilt(), MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show() (+12 more)

### Community 14 - "Lobby/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.13
Nodes (26): LoadoutService.ClearSession(), RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), checkProgression(), rollbackProgression() (+18 more)

### Community 15 - "PlayerStats ModuleScript"
Cohesion: 0.25
Nodes (8): CameraInventory (server), CameraSessionTracker (server), CameraShelfSwap (server), CurrentCamera Player Attribute, LinearVelocity-based Movement, PlayerStats ModuleScript, Reactive HUD (BindableEvent), Sprint/Stamina System

### Community 16 - "Inventory & Shop System"
Cohesion: 0.29
Nodes (7): BuyHandler, Inventory & Shop System, IsEmpty Attribute, KitGiven Attribute, Proximity Shop GUI, ShopFillSlot, StartGame / EndGame Lifecycle Modules

### Community 17 - "Camera Framework"
Cohesion: 0.25
Nodes (8): Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraEffects, CameraId Attribute, CameraSession, CameraState, CameraToolController, CameraToolWatcher (LocalScript)

### Community 18 - "Map0_Test/ServerScriptService/GameService/Reward/RewardStore.luau"
Cohesion: 0.12
Nodes (27): LoadoutService.ClearSession(), RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), checkProgression(), rollbackProgression() (+19 more)

### Community 19 - "Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.15
Nodes (13): MatchStates.Validate(), PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), GameBoot.Start(), guardNonReservedServer() (+5 more)

### Community 24 - "CameraStats"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 25 - "Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.23
Nodes (9): MatchStates.AcceptsJoins(), MatchStates.IsKitGranted(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), loadIfNeeded(), MatchSpawner.Start(), KitLifecycleHook.Start() (+1 more)

### Community 26 - "States/Chase"
Cohesion: 0.33
Nodes (6): CameraShelfHandler (server), Cooldown (Shared Utility), MonsterDamage, MonsterMovement, States/Chase, States/Checking

### Community 27 - "Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.18
Nodes (10): PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), LobbyBoot.Start(), ArrivalService.Start(), handleArrival() (+2 more)

### Community 28 - "Chase.Update"
Cohesion: 0.25
Nodes (3): MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 29 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.06
Nodes (51): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+43 more)

### Community 30 - "Chase.Update"
Cohesion: 0.25
Nodes (3): MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 31 - "Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau"
Cohesion: 0.24
Nodes (15): MatchStates.CanTransition(), MatchStates.IsTerminal(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying(), runWaitingForPlayers() (+7 more)

### Community 32 - "Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.23
Nodes (9): MatchStates.AcceptsJoins(), MatchStates.IsScoringActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsValid(), MatchStates.Validate(), GameBoot.Start(), guardNonReservedServer(), loadIfNeeded() (+1 more)

### Community 33 - "Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 34 - "Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 35 - "Planned.md"
Cohesion: 0.12
Nodes (15): Blocking / must clear before 8V, Current Architecture, Current Phase, Current Verification Status, Deferred by decision, Development Summary, Next Session Plan, Not Yet Verified (+7 more)

### Community 36 - "Lobby/ReplicatedStorage/Modules/Shared/Signal.luau"
Cohesion: 0.08
Nodes (26): MatchConfig.Get(), LaunchGate.Check(), LaunchGate.RegisterPrecondition(), LaunchGate.RegisterRollback(), LaunchGate.Rollback(), LaunchGate.Start(), onPlayerRemoving(), PartyService.GetLeader() (+18 more)

### Community 37 - "Lobby/ServerScriptService/GameService/Match/ReturnToLobbyService.luau"
Cohesion: 0.31
Nodes (8): ensureMatchInfoFolder(), MatchReplicator.Start(), MatchResultBuilder.Build(), attemptReturn(), buildTeleportData(), handleInitFailed(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 38 - "Map0_Test/ServerScriptService/GameService/Lobby/QueueService.luau"
Cohesion: 0.10
Nodes (26): MatchConfig.Get(), LaunchGate.Check(), LaunchGate.RegisterPrecondition(), LaunchGate.RegisterRollback(), LaunchGate.Rollback(), LaunchGate.Start(), onPlayerRemoving(), PartyService.GetLeader() (+18 more)

### Community 39 - "Map0_Test/ReplicatedStorage/Modules/Loadout/LoadoutService.luau"
Cohesion: 0.09
Nodes (22): CameraState.GetWalkSpeedMultiplier(), attempt(), keyFor(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get() (+14 more)

### Community 40 - "Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 41 - "Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.29
Nodes (5): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.IsParticipant(), MatchParticipants.Seed()

### Community 42 - "ServerRole.AssertGameServer"
Cohesion: 0.28
Nodes (7): ServerRole.AssertGameServer(), MatchManager.GetElapsed(), MatchManager.Start(), buildPerPlayer(), MatchResultBuilder.RegisterContributor(), MatchResultBuilder.Start(), RewardResultHook.Start()

### Community 43 - "Lobby/ServerScriptService/GameService/Reward/CaptureGuard.luau"
Cohesion: 0.18
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 44 - "Lobby/ServerScriptService/GameService/Match/MatchManager.luau"
Cohesion: 0.32
Nodes (12): MatchStates.CanTransition(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying(), runWaitingForPlayers(), MatchManager.Abort() (+4 more)

### Community 45 - "ServerRole.AssertGameServer"
Cohesion: 0.20
Nodes (11): MatchStates.IsKitGranted(), ServerRole.AssertGameServer(), MatchCleanup.RegisterSaveStep(), MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), KitLifecycleHook.Start() (+3 more)

### Community 46 - "Lobby/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 47 - "Map0_Test/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 48 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 49 - "Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.25
Nodes (6): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.All(), MatchParticipants.IsParticipant(), MatchParticipants.Seed()

### Community 50 - "Lobby/ReplicatedStorage/Modules/Camera/CameraStats.luau"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 51 - "MatchManager.Get"
Cohesion: 0.17
Nodes (14): MatchStates.MonstersSpawn(), MatchManager.Get(), cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter(), getCooldownTable() (+6 more)

### Community 52 - "MatchManager.Get"
Cohesion: 0.16
Nodes (15): MatchStates.IsGameplayActive(), MatchStates.MonstersSpawn(), MatchManager.Get(), cframeOf(), despawnEncounter(), EncounterDirector.Start(), findSpawnPoints(), spawnEncounter() (+7 more)

### Community 53 - "MatchReplicator.Start"
Cohesion: 0.24
Nodes (8): MatchParticipants.All(), ensureMatchInfoFolder(), MatchReplicator.Start(), buildPerPlayer(), MatchResultBuilder.Build(), MatchResultBuilder.RegisterContributor(), MatchResultBuilder.Start(), RewardResultHook.Start()

### Community 54 - "Lobby/ReplicatedStorage/Modules/Camera/CameraToolController.luau"
Cohesion: 0.39
Nodes (5): CameraToolController.Init(), fireEquippedChanged(), onCharacterAdded(), tryInit(), watchContainer()

### Community 55 - "Map0_Test/ServerScriptService/GameService/Objective/ObjectiveRegistry.luau"
Cohesion: 0.57
Nodes (5): bootstrap(), considerInstance(), register(), unregister(), watchAttribute()

### Community 56 - "PhotoCapture (server)"
Cohesion: 0.33
Nodes (6): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), CanCapture Attribute, PhotoCapture (server), CanCapture Attribute (Monster Model), Grey Cube MVP Vertical Slice

### Community 57 - "Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau"
Cohesion: 0.28
Nodes (7): MatchCleanup.RegisterSaveStep(), MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), RewardCleanupHook.Start(), RewardStore.SaveAll()

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

### Community 64 - "Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau"
Cohesion: 0.60
Nodes (5): attemptReturn(), buildTeleportData(), handleInitFailed(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

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
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `MonsterService.Spawn()` connect `MatchManager.Get` to `Lobby/ServerScriptService/GameService/Monster/MonsterAgent.luau`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 11 inferred relationships involving `Remotes.Get()` (e.g. with `handleArrival()` and `fireResult()`) actually correct?**
  _`Remotes.Get()` has 11 INFERRED edges - model-reasoned connections that need verification._