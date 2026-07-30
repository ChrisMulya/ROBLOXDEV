# Graph Report - ROBLOX-DEV  (2026-07-30)

## Corpus Check
- 122 files · ~55,119 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 570 nodes · 918 edges · 45 communities (39 shown, 6 thin omitted)
- Extraction: 80% EXTRACTED · 20% INFERRED · 0% AMBIGUOUS · INFERRED: 180 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4d6edad7`
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
- CameraShelfGui.luau
- PlayerRuntimeStats.luau
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

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 18 edges
2. `Reward System` - 12 edges
3. `SpectateService.SetTarget()` - 11 edges
4. `CameraStats.GetStats()` - 10 edges
5. `RewardService.AwardFromCapture()` - 10 edges
6. `Photo Scoring Blueprint` - 10 edges
7. `CameraShelfGui.Build()` - 9 edges
8. `ensureBuilt()` - 9 edges
9. `ServerRole.AssertGameServer()` - 9 edges
10. `handleShot()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `SpectateService.SetTarget()` --calls--> `MatchStates.IsSpectateAllowed()`  [INFERRED]
  ServerScriptService/GameService/Spectate/SpectateService.luau → ReplicatedStorage/Modules/Shared/MatchStates.luau
- `isScoringActive()` --calls--> `MatchStates.IsScoringActive()`  [INFERRED]
  ServerScriptService/GameService/Reward/RewardService.luau → ReplicatedStorage/Modules/Shared/MatchStates.luau
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `onPhotoPressed()` --calls--> `CameraSession.Capture()`  [INFERRED]
  StarterPlayerScripts/CameraTouchHudClient.local.luau → ReplicatedStorage/Modules/Camera/CameraSession.luau
- `setupCharacter()` --calls--> `CameraState.GetWalkSpeedMultiplier()`  [INFERRED]
  StarterPlayerScripts/Playermovementcontroller.local.luau → ReplicatedStorage/Modules/Camera/CameraState.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (45 total, 6 thin omitted)

### Community 0 - "CameraSession.luau"
Cohesion: 0.07
Nodes (39): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+31 more)

### Community 1 - "CameraSession"
Cohesion: 0.20
Nodes (12): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, CameraEffects, CameraSession, CameraToolController, CameraToolWatcher (LocalScript), Currency UI, CurrencyUI Connection Leak (Deferred) (+4 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.15
Nodes (16): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShotHandler (server), PhotoCapture (server), Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, Evolution Doubles Per-Monster Cost (Risk), Monster System Blueprint (+8 more)

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

### Community 7 - "CameraShelfGui.luau"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 8 - "PlayerRuntimeStats.luau"
Cohesion: 0.19
Nodes (7): CameraState.GetWalkSpeedMultiplier(), PlayerRuntimeStats.Add(), PlayerRuntimeStats.Get(), PlayerRuntimeStats.Set(), PlayerStats.Get(), updateBar(), setupCharacter()

### Community 9 - "ObjectiveService.luau"
Cohesion: 0.11
Nodes (22): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+14 more)

### Community 10 - "RewardService.luau"
Cohesion: 0.08
Nodes (28): CameraStability.IsMoving(), CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers() (+20 more)

### Community 11 - "PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 12 - "ObjectiveRegistry.luau"
Cohesion: 0.57
Nodes (5): bootstrap(), considerInstance(), register(), unregister(), watchAttribute()

### Community 13 - "Signal.luau"
Cohesion: 0.07
Nodes (24): MatchStates.IsGameplayActive(), PlayerStates.CanTransition(), PlayerStates.IsValid(), DeathPolicy.Get(), bindCharacter(), DeathService.Start(), onCharacterAdded(), onHumanoidDied() (+16 more)

### Community 14 - "DeathScreen.luau"
Cohesion: 0.15
Nodes (12): ensureBuilt(), SpectateHud.Update(), buildButtonHolder(), buildMessageLabel(), buildPanel(), DeathScreen.Show(), ensureBuilt(), renderButtons() (+4 more)

### Community 15 - "PlayerStats ModuleScript"
Cohesion: 0.25
Nodes (8): CameraInventory (server), CameraSessionTracker (server), CameraShelfSwap (server), CurrentCamera Player Attribute, LinearVelocity-based Movement, PlayerStats ModuleScript, Reactive HUD (BindableEvent), Sprint/Stamina System

### Community 16 - "Inventory & Shop System"
Cohesion: 0.29
Nodes (7): BuyHandler, Inventory & Shop System, IsEmpty Attribute, KitGiven Attribute, Proximity Shop GUI, ShopFillSlot, StartGame / EndGame Lifecycle Modules

### Community 17 - "Camera Framework"
Cohesion: 0.29
Nodes (7): Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraId Attribute, CameraState, CanCapture Attribute, CanCapture Attribute (Monster Model), Grey Cube MVP Vertical Slice

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
Cohesion: 0.07
Nodes (15): ShotResultCodes.GetMessage(), CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.GetCurrentId(), CameraInventory.Give(), CameraShelfSwap.ClearCameraSlot(), CameraShelfSwap.TakeCamera() (+7 more)

### Community 36 - "ServerRole.luau"
Cohesion: 0.07
Nodes (33): MatchStates.CanTransition(), MatchStates.IsScoringActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), MatchStates.MonstersSpawn(), MatchStates.Validate(), PlayerStates.CountsAsActive() (+25 more)

### Community 37 - "SpectateCameraController.luau"
Cohesion: 0.60
Nodes (3): ensureFreeCameraAnchor(), SpectateCameraController.SetTarget(), tryExitCameraSession()

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
- **Why does `MonsterService.Spawn()` connect `MonsterService.Spawn` to `ServerRole.luau`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `SpectateService.SetTarget()` (e.g. with `MatchStates.IsSpectateAllowed()` and `PlayerStates.CanSpectate()`) actually correct?**
  _`SpectateService.SetTarget()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 7 inferred relationships involving `RewardService.AwardFromCapture()` (e.g. with `handleShot()` and `CaptureRules.Check()`) actually correct?**
  _`RewardService.AwardFromCapture()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **What connects `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point` to the rest of the system?**
  _49 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CameraSession.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.07207792207792207 - nodes in this community are weakly interconnected._