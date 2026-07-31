# Graph Report - ROBLOX-DEV  (2026-07-30)

## Corpus Check
- 137 files · ~73,522 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 621 nodes · 1045 edges · 54 communities (48 shown, 6 thin omitted)
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 221 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ec0b7d85`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CameraSession.luau
- CameraSession
- Monster System Blueprint
- SpectateService.luau
- MonsterService.Spawn
- CameraViewfinder.luau
- Reward System
- MatchParticipants.luau
- onCharacterAdded
- ObjectiveService.luau
- RewardService.luau
- PurchaseNotification.luau
- ObjectiveRegistry.luau
- Signal.luau
- DeathScreen.luau
- PlayerStats ModuleScript
- Inventory & Shop System
- Camera Framework
- RewardLedger.luau
- CameraTouchHud.luau
- CameraFlashEffect
- FloatingShotText
- Remotes (Shared Utility)
- MonsterSensing
- CameraStats
- States/Chase
- Remotes.luau
- ScreenFlashRenderer.luau
- WorldLightRenderer.luau
- ServerRole.luau
- SpectateCameraController.luau
- InstallGameMirror.luau
- MatchManager.luau
- MatchStates.luau
- VerifyPhase75.luau
- ServerRole.AssertGameServer
- PlayerRuntimeStats.luau
- ReturnToLobbyService.luau
- PhotoCapture (server)

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 18 edges
2. `ServerRole.AssertGameServer()` - 15 edges
3. `Reward System` - 12 edges
4. `SpectateService.SetTarget()` - 11 edges
5. `CameraStats.GetStats()` - 10 edges
6. `MatchManager.RequestTransition()` - 10 edges
7. `RewardService.AwardFromCapture()` - 10 edges
8. `Photo Scoring Blueprint` - 10 edges
9. `CameraShelfGui.Build()` - 9 edges
10. `ensureBuilt()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `setupCharacter()` --calls--> `CameraState.GetWalkSpeedMultiplier()`  [INFERRED]
  StarterPlayerScripts/Playermovementcontroller.local.luau → ReplicatedStorage/Modules/Camera/CameraState.luau
- `MatchManager.RequestTransition()` --calls--> `MatchStates.IsValid()`  [INFERRED]
  ServerScriptService/GameService/Match/MatchManager.luau → ReplicatedStorage/Modules/Shared/MatchStates.luau
- `SpectateService.SetTarget()` --calls--> `MatchStates.IsSpectateAllowed()`  [INFERRED]
  ServerScriptService/GameService/Spectate/SpectateService.luau → ReplicatedStorage/Modules/Shared/MatchStates.luau
- `MatchManager.Start()` --calls--> `ServerRole.AssertGameServer()`  [INFERRED]
  ServerScriptService/GameService/Match/MatchManager.luau → ReplicatedStorage/Modules/Shared/ServerRole.luau
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (54 total, 6 thin omitted)

### Community 0 - "CameraSession.luau"
Cohesion: 0.07
Nodes (40): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+32 more)

### Community 1 - "CameraSession"
Cohesion: 0.20
Nodes (12): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, CameraEffects, CameraSession, CameraToolController, CameraToolWatcher (LocalScript), Currency UI, CurrencyUI Connection Leak (Deferred) (+4 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.29
Nodes (8): Monster System Blueprint, MonsterAgent, MonsterAggression, MonsterService, MonsterStats, States/Lurk, States/Wandering, TransitionChance Anti-Solve Valve

### Community 3 - "SpectateService.luau"
Cohesion: 0.17
Nodes (21): PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), Remotes.Get(), PlayerStateService.Get(), assignBest(), fireSync(), onMatchStateChanged(), onPlayerRemoving() (+13 more)

### Community 4 - "MonsterService.Spawn"
Cohesion: 0.13
Nodes (11): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill(), MonsterMovement.MoveTo() (+3 more)

### Community 5 - "CameraViewfinder.luau"
Cohesion: 0.24
Nodes (13): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Hide(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel() (+5 more)

### Community 6 - "Reward System"
Cohesion: 0.06
Nodes (30): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+22 more)

### Community 7 - "MatchParticipants.luau"
Cohesion: 0.28
Nodes (6): MatchArrival.GetModeId(), MatchArrival.Start(), seedFrom(), MatchParticipants.CountActive(), MatchParticipants.GetPresent(), MatchParticipants.Seed()

### Community 8 - "onCharacterAdded"
Cohesion: 0.14
Nodes (15): LoadoutService.GetCameraId(), MatchStates.IsKitGranted(), CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.Give(), templatesFolder(), CameraShelfSwap.ClearCameraSlot() (+7 more)

### Community 9 - "ObjectiveService.luau"
Cohesion: 0.11
Nodes (22): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+14 more)

### Community 10 - "RewardService.luau"
Cohesion: 0.08
Nodes (29): CameraStability.IsMoving(), CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers() (+21 more)

### Community 11 - "PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 12 - "ObjectiveRegistry.luau"
Cohesion: 0.57
Nodes (5): bootstrap(), considerInstance(), register(), unregister(), watchAttribute()

### Community 13 - "Signal.luau"
Cohesion: 0.12
Nodes (15): PlayerStates.CanTransition(), PlayerStates.IsValid(), DeathPolicy.Get(), bindCharacter(), DeathService.Start(), onCharacterAdded(), onHumanoidDied(), bindCharacter() (+7 more)

### Community 14 - "DeathScreen.luau"
Cohesion: 0.10
Nodes (19): MatchResultCodes.GetMessage(), ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show(), ensureBuilt() (+11 more)

### Community 15 - "PlayerStats ModuleScript"
Cohesion: 0.25
Nodes (8): CameraInventory (server), CameraSessionTracker (server), CameraShelfSwap (server), CurrentCamera Player Attribute, LinearVelocity-based Movement, PlayerStats ModuleScript, Reactive HUD (BindableEvent), Sprint/Stamina System

### Community 16 - "Inventory & Shop System"
Cohesion: 0.29
Nodes (7): BuyHandler, Inventory & Shop System, IsEmpty Attribute, KitGiven Attribute, Proximity Shop GUI, ShopFillSlot, StartGame / EndGame Lifecycle Modules

### Community 17 - "Camera Framework"
Cohesion: 0.22
Nodes (9): Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraId Attribute, CameraState, Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk) (+1 more)

### Community 18 - "RewardLedger.luau"
Cohesion: 0.16
Nodes (22): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), getOrCreateLeaderstats(), getValue(), RewardLedger.Add() (+14 more)

### Community 19 - "CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 24 - "CameraStats"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 26 - "States/Chase"
Cohesion: 0.33
Nodes (6): CameraShelfHandler (server), Cooldown (Shared Utility), MonsterDamage, MonsterMovement, States/Chase, States/Checking

### Community 27 - "Remotes.luau"
Cohesion: 0.06
Nodes (16): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+8 more)

### Community 36 - "ServerRole.luau"
Cohesion: 0.15
Nodes (12): MatchStates.Validate(), PlayerStates.Validate(), resolve(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), GameBoot.Start(), guardNonReservedServer() (+4 more)

### Community 37 - "SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

### Community 38 - "InstallGameMirror.luau"
Cohesion: 0.60
Nodes (3): hashSource(), legacyScript(), moduleScript()

### Community 39 - "MatchManager.luau"
Cohesion: 0.27
Nodes (12): MatchConfig.Get(), config(), MatchClock.Start(), runCountdown(), runEndingHold(), runPlaying(), runWaitingForPlayers(), MatchManager.GetElapsed() (+4 more)

### Community 45 - "MatchStates.luau"
Cohesion: 0.16
Nodes (13): MatchStates.AcceptsJoins(), MatchStates.CanTransition(), MatchStates.IsGameplayActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), MatchStates.MonstersSpawn(), MatchManager.Abort() (+5 more)

### Community 46 - "VerifyPhase75.luau"
Cohesion: 0.17
Nodes (11): PlayerStates.CountsAsActive(), evaluate(), MatchEndCondition.Start(), MatchParticipants.All(), ensureMatchInfoFolder(), MatchReplicator.Start(), buildPerPlayer(), MatchResultBuilder.Build() (+3 more)

### Community 47 - "ServerRole.AssertGameServer"
Cohesion: 0.21
Nodes (9): ServerRole.AssertGameServer(), MatchCleanup.RegisterSaveStep(), MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup(), runWithTimeout(), KitLifecycleHook.Start(), RewardCleanupHook.Start() (+1 more)

### Community 48 - "PlayerRuntimeStats.luau"
Cohesion: 0.21
Nodes (6): PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set(), PlayerStats.Get(), updateBar(), setupCharacter()

### Community 49 - "ReturnToLobbyService.luau"
Cohesion: 0.60
Nodes (5): attemptReturn(), buildTeleportData(), handleInitFailed(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 53 - "PhotoCapture (server)"
Cohesion: 0.33
Nodes (6): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), CanCapture Attribute, PhotoCapture (server), CanCapture Attribute (Monster Model), Grey Cube MVP Vertical Slice

## Ambiguous Edges - Review These
- `Graphify Knowledge Graph Workflow` → `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **49 isolated node(s):** `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point`, `Contract 3 — Reward routing`, `⚠ Security — this must land before the payout` (+44 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `MonsterService.Spawn()` connect `MonsterService.Spawn` to `MatchStates.luau`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 13 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `GameBoot.Start()` and `MatchArrival.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 13 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `SpectateService.SetTarget()` (e.g. with `MatchStates.IsSpectateAllowed()` and `PlayerStates.CanSpectate()`) actually correct?**
  _`SpectateService.SetTarget()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point` to the rest of the system?**
  _49 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CameraSession.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.07017543859649122 - nodes in this community are weakly interconnected._