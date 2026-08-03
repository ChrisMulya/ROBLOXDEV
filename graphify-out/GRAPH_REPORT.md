# Graph Report - ROBLOX-DEV  (2026-08-03)

## Corpus Check
- 263 files · ~91,507 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1146 nodes · 1974 edges · 94 communities (84 shown, 10 thin omitted)
- Extraction: 77% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 445 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a3af1747`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau
- Roblox Game Project Handoff
- Monster System Blueprint
- Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau
- Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau
- Lobby/ServerScriptService/GameService/Reward/RewardService.luau
- Reward System
- Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau
- Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau
- Lobby/ServerScriptService/GameService/Player/StartGame.luau
- Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau
- Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau
- Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau
- Lobby/ServerScriptService/GameService/Reward/RewardLedger.luau
- PlayerStats ModuleScript
- Inventory & Shop System
- Camera Framework
- Map0_Test/ServerScriptService/GameService/Reward/RewardLedger.luau
- Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau
- CameraFlashEffect
- FloatingShotText
- Remotes (Shared Utility)
- MonsterSensing
- CameraStats
- Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- States/Chase
- Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau
- MonsterService.Spawn
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraToolController.luau
- MonsterService.Spawn
- Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau
- Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau
- Planned.md
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau
- ServerRole.AssertGameServer
- Map0_Test/ServerScriptService/GameService/Reward/CaptureGuard.luau
- Map0_Test/ReplicatedStorage/Modules/PlayerRuntimeStats.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- evaluate
- Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraStats.luau
- Lobby/ServerScriptService/GameService/Match/MatchClock.luau
- ServerRole.AssertGameServer
- Map0_Test/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau
- Map0_Test/ReplicatedStorage/Modules/Shared/Remotes.luau
- evaluate
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraState.luau
- Map0_Test/StarterPlayerScripts/CameraShelfClient.local.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau
- Map0_Test/ServerScriptService/GameService/CameraShelf/CameraInventory.luau
- Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau
- Lobby/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau
- Map0_Test/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau
- Map0_Test/StarterPlayerScripts/ShotFeedbackHandler.local.luau
- PhotoCapture (server)
- Map0_Test/ServerScriptService/GameService/Player/StartGame.luau
- Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau
- Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau
- Map0_Test/ServerScriptService/GameService/Match/MatchArrival.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Lobby/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/ScreenFlashRenderer.luau
- Map0_Test/ReplicatedStorage/Modules/Flash/FlashRenderers/WorldLightRenderer.luau

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 18 edges
2. `CameraSession.Enter()` - 18 edges
3. `ServerRole.AssertGameServer()` - 15 edges
4. `ServerRole.AssertGameServer()` - 15 edges
5. `Reward System` - 12 edges
6. `SpectateService.SetTarget()` - 11 edges
7. `SpectateService.SetTarget()` - 11 edges
8. `CameraStats.GetStats()` - 10 edges
9. `MatchManager.RequestTransition()` - 10 edges
10. `RewardService.AwardFromCapture()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `Graphify Knowledge Graph Workflow` --conceptually_related_to--> `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md → MAINHANDOFF.md
- `SpectateService.SetTarget()` --calls--> `MatchStates.IsSpectateAllowed()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau → Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau
- `config()` --calls--> `MatchArrival.GetModeId()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Match/MatchClock.luau → Lobby/ServerScriptService/GameService/Match/MatchArrival.luau
- `KitLifecycleHook.Start()` --calls--> `MatchCleanup.RegisterTeardownStep()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Player/KitLifecycleHook.luau → Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (94 total, 10 thin omitted)

### Community 0 - "Lobby/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.06
Nodes (52): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+44 more)

### Community 1 - "Roblox Game Project Handoff"
Cohesion: 0.29
Nodes (8): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, Currency UI, CurrencyUI Connection Leak (Deferred), Hard-Won Debugging Lessons, Local Filesystem <-> Studio Live Sync, Roblox Game Project Handoff, Trove (Shared Utility)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.19
Nodes (13): Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk), Monster System Blueprint, MonsterAgent, MonsterAggression, MonsterEvolution (+5 more)

### Community 3 - "Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (39): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get(), bindCharacter(), DeathService.Start() (+31 more)

### Community 4 - "Map0_Test/ServerScriptService/GameService/Spectate/SpectateService.luau"
Cohesion: 0.07
Nodes (38): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), Remotes.Get(), DeathPolicy.Get(), bindCharacter(), DeathService.Start() (+30 more)

### Community 5 - "Lobby/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.08
Nodes (29): CameraStability.IsMoving(), CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers() (+21 more)

### Community 6 - "Reward System"
Cohesion: 0.06
Nodes (30): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+22 more)

### Community 7 - "Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau"
Cohesion: 0.06
Nodes (16): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+8 more)

### Community 8 - "Lobby/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (27): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+19 more)

### Community 9 - "Map0_Test/ServerScriptService/GameService/Objective/ObjectiveService.luau"
Cohesion: 0.09
Nodes (27): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+19 more)

### Community 10 - "Lobby/ServerScriptService/GameService/Player/StartGame.luau"
Cohesion: 0.09
Nodes (18): CameraState.GetWalkSpeedMultiplier(), LoadoutService.GetCameraId(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set(), PlayerStats.Get(), CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot() (+10 more)

### Community 11 - "Lobby/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.10
Nodes (19): MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show(), ensureBuilt() (+11 more)

### Community 12 - "Map0_Test/ServerScriptService/GameService/Reward/RewardService.luau"
Cohesion: 0.11
Nodes (20): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+12 more)

### Community 13 - "Map0_Test/ReplicatedStorage/Modules/UI/DeathScreen.luau"
Cohesion: 0.10
Nodes (19): MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show(), ensureBuilt() (+11 more)

### Community 14 - "Lobby/ServerScriptService/GameService/Reward/RewardLedger.luau"
Cohesion: 0.16
Nodes (22): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), getOrCreateLeaderstats(), getValue(), RewardLedger.Add() (+14 more)

### Community 15 - "PlayerStats ModuleScript"
Cohesion: 0.25
Nodes (8): CameraInventory (server), CameraSessionTracker (server), CameraShelfSwap (server), CurrentCamera Player Attribute, LinearVelocity-based Movement, PlayerStats ModuleScript, Reactive HUD (BindableEvent), Sprint/Stamina System

### Community 16 - "Inventory & Shop System"
Cohesion: 0.29
Nodes (7): BuyHandler, Inventory & Shop System, IsEmpty Attribute, KitGiven Attribute, Proximity Shop GUI, ShopFillSlot, StartGame / EndGame Lifecycle Modules

### Community 17 - "Camera Framework"
Cohesion: 0.25
Nodes (8): Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraEffects, CameraId Attribute, CameraSession, CameraState, CameraToolController, CameraToolWatcher (LocalScript)

### Community 18 - "Map0_Test/ServerScriptService/GameService/Reward/RewardLedger.luau"
Cohesion: 0.16
Nodes (22): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), getOrCreateLeaderstats(), getValue(), RewardLedger.Add() (+14 more)

### Community 19 - "Lobby/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.13
Nodes (16): MatchStates.Validate(), PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), GameBoot.Start(), guardNonReservedServer() (+8 more)

### Community 24 - "CameraStats"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 25 - "Lobby/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.16
Nodes (15): MatchStates.AcceptsJoins(), MatchStates.CanTransition(), MatchStates.IsGameplayActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), MatchStates.MonstersSpawn(), MatchManager.Abort() (+7 more)

### Community 26 - "States/Chase"
Cohesion: 0.33
Nodes (6): CameraShelfHandler (server), Cooldown (Shared Utility), MonsterDamage, MonsterMovement, States/Chase, States/Checking

### Community 27 - "Map0_Test/ReplicatedStorage/Modules/Shared/ServerRole.luau"
Cohesion: 0.16
Nodes (13): PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), LobbyBoot.Start(), ArrivalService.Start(), handleArrival() (+5 more)

### Community 28 - "MonsterService.Spawn"
Cohesion: 0.13
Nodes (11): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill(), MonsterMovement.MoveTo() (+3 more)

### Community 29 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraToolController.luau"
Cohesion: 0.16
Nodes (15): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.SetMovementSettings(), CameraToolController.GetEquipped() (+7 more)

### Community 30 - "MonsterService.Spawn"
Cohesion: 0.13
Nodes (11): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill(), MonsterMovement.MoveTo() (+3 more)

### Community 31 - "Map0_Test/ServerScriptService/GameService/Match/MatchManager.luau"
Cohesion: 0.22
Nodes (15): MatchConfig.Get(), MatchStates.CanTransition(), MatchStates.IsTerminal(), MatchStates.IsValid(), config(), MatchClock.Start(), runCountdown(), runEndingHold() (+7 more)

### Community 32 - "Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau"
Cohesion: 0.16
Nodes (12): MatchStates.AcceptsJoins(), MatchStates.IsGameplayActive(), MatchStates.IsSpectateAllowed(), MatchStates.MonstersSpawn(), MatchStates.Validate(), GameBoot.Start(), guardNonReservedServer(), MatchManager.Get() (+4 more)

### Community 33 - "Lobby/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 34 - "Map0_Test/ReplicatedStorage/Modules/Shop/PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 35 - "Planned.md"
Cohesion: 0.12
Nodes (15): Blocking / must clear before 8V, Current Architecture, Current Phase, Current Verification Status, Deferred by decision, Development Summary, Next Session Plan, Not Yet Verified (+7 more)

### Community 36 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraSession.luau"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 37 - "ServerRole.AssertGameServer"
Cohesion: 0.19
Nodes (12): ServerRole.AssertGameServer(), MatchManager.GetElapsed(), MatchManager.Start(), MatchResultBuilder.Build(), MatchResultBuilder.RegisterContributor(), MatchResultBuilder.Start(), attemptReturn(), buildTeleportData() (+4 more)

### Community 38 - "Map0_Test/ServerScriptService/GameService/Reward/CaptureGuard.luau"
Cohesion: 0.22
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 39 - "Map0_Test/ReplicatedStorage/Modules/PlayerRuntimeStats.luau"
Cohesion: 0.19
Nodes (7): CameraState.GetWalkSpeedMultiplier(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set(), PlayerStats.Get(), updateBar(), setupCharacter()

### Community 40 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraViewfinder.luau"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 41 - "evaluate"
Cohesion: 0.19
Nodes (11): PlayerStates.CountsAsActive(), evaluate(), MatchEndCondition.Start(), MatchManager.GetElapsed(), MatchParticipants.All(), ensureMatchInfoFolder(), MatchReplicator.Start(), buildPerPlayer() (+3 more)

### Community 42 - "Lobby/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.20
Nodes (8): MatchStates.IsKitGranted(), MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.IsParticipant(), MatchParticipants.Seed(), KitLifecycleHook.Start(), onCharacterAdded()

### Community 43 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraStats.luau"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 44 - "Lobby/ServerScriptService/GameService/Match/MatchClock.luau"
Cohesion: 0.36
Nodes (9): MatchConfig.Get(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying(), runWaitingForPlayers(), MatchManager.Is() (+1 more)

### Community 45 - "ServerRole.AssertGameServer"
Cohesion: 0.24
Nodes (8): ServerRole.AssertGameServer(), MatchCleanup.RegisterSaveStep(), MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), RewardCleanupHook.Start(), RewardResultHook.Start()

### Community 47 - "Map0_Test/ReplicatedStorage/Modules/CameraShelf/CameraShelfGui.luau"
Cohesion: 0.33
Nodes (8): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build()

### Community 49 - "evaluate"
Cohesion: 0.28
Nodes (7): PlayerStates.CountsAsActive(), evaluate(), MatchEndCondition.Start(), MatchParticipants.All(), ensureMatchInfoFolder(), MatchReplicator.Start(), buildPerPlayer()

### Community 53 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraState.luau"
Cohesion: 0.28
Nodes (4): CameraState.SetInCamera(), CameraState.SetStable(), fireListeners(), fireStableListeners()

### Community 54 - "Map0_Test/StarterPlayerScripts/CameraShelfClient.local.luau"
Cohesion: 0.31
Nodes (6): CameraShelfGui.Refresh(), bindDeathHandler(), closeShelf(), lockMovementAndMouse(), openShelf(), unlockMovementAndMouse()

### Community 55 - "Map0_Test/ServerScriptService/GameService/Match/MatchParticipants.luau"
Cohesion: 0.31
Nodes (6): MatchStates.IsKitGranted(), MatchParticipants.CountActive(), MatchParticipants.GetPresent(), MatchParticipants.IsParticipant(), KitLifecycleHook.Start(), onCharacterAdded()

### Community 56 - "Map0_Test/ServerScriptService/GameService/CameraShelf/CameraInventory.luau"
Cohesion: 0.36
Nodes (6): CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.Give(), templatesFolder(), CameraShelfSwap.ClearCameraSlot(), CameraShelfSwap.TakeCamera()

### Community 57 - "Lobby/ServerScriptService/GameService/Match/MatchCleanup.luau"
Cohesion: 0.32
Nodes (6): MatchCleanup.RegisterSaveStep(), MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), RewardCleanupHook.Start()

### Community 59 - "Lobby/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 60 - "Map0_Test/ReplicatedStorage/Modules/Camera/CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 62 - "PhotoCapture (server)"
Cohesion: 0.33
Nodes (6): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), CanCapture Attribute, PhotoCapture (server), CanCapture Attribute (Monster Model), Grey Cube MVP Vertical Slice

### Community 63 - "Map0_Test/ServerScriptService/GameService/Player/StartGame.luau"
Cohesion: 0.60
Nodes (4): LoadoutService.GetCameraId(), createEmptySlot(), giveStarterCamera(), StartGameService.GivePlayerStarterKit()

### Community 64 - "Map0_Test/ServerScriptService/GameService/Match/ReturnToLobbyService.luau"
Cohesion: 0.60
Nodes (5): attemptReturn(), buildTeleportData(), handleInitFailed(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 65 - "Lobby/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

### Community 66 - "Map0_Test/ReplicatedStorage/Modules/Spectate/SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

### Community 67 - "Map0_Test/ServerScriptService/GameService/Match/MatchArrival.luau"
Cohesion: 0.50
Nodes (4): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.Seed()

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
- **Why does `MonsterService.Spawn()` connect `MonsterService.Spawn` to `Map0_Test/ReplicatedStorage/Modules/Shared/MatchStates.luau`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 13 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **Are the 13 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **What connects `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point` to the rest of the system?**
  _62 weakly-connected nodes found - possible documentation gaps or missing edges._