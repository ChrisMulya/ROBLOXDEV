# Graph Report - ROBLOX-DEV  (2026-07-29)

## Corpus Check
- 91 files · ~33,761 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 427 nodes · 646 edges · 31 communities (25 shown, 6 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 108 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d311d043`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CameraSession.luau
- Camera Framework
- Monster System Blueprint
- StartGame.luau
- MonsterAgent.luau
- CameraViewfinder.luau
- Reward System
- CameraShelfGui.luau
- PlayerRuntimeStats.luau
- ObjectiveService.luau
- RewardService.luau
- PurchaseNotification.luau
- ObjectiveRegistry.luau
- CameraStats.luau
- RewardLedger.luau
- CameraTouchHud.luau
- CameraFlashEffect
- FloatingShotText
- Remotes (Shared Utility)
- MonsterSensing
- Remotes.luau
- ScreenFlashRenderer.luau
- WorldLightRenderer.luau

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 18 edges
2. `Reward System` - 12 edges
3. `CameraStats.GetStats()` - 10 edges
4. `Photo Scoring Blueprint` - 10 edges
5. `CameraShelfGui.Build()` - 9 edges
6. `ensureBuilt()` - 9 edges
7. `RewardService.AwardFromCapture()` - 9 edges
8. `handleShot()` - 8 edges
9. `ObjectiveService.SetState()` - 8 edges
10. `CameraSession.Exit()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `onPhotoPressed()` --calls--> `CameraSession.Capture()`  [INFERRED]
  StarterPlayerScripts/CameraTouchHudClient.local.luau → ReplicatedStorage/Modules/Camera/CameraSession.luau
- `setupCharacter()` --calls--> `CameraState.GetWalkSpeedMultiplier()`  [INFERRED]
  StarterPlayerScripts/Playermovementcontroller.local.luau → ReplicatedStorage/Modules/Camera/CameraState.luau
- `ObjectiveService.SetState()` --calls--> `ObjectiveStates.IsValid()`  [INFERRED]
  ServerScriptService/GameService/Objective/ObjectiveService.luau → ReplicatedStorage/Modules/Objective/ObjectiveStates.luau
- `setupCharacter()` --calls--> `PlayerRuntimeStats.Set()`  [INFERRED]
  StarterPlayerScripts/Playermovementcontroller.local.luau → ReplicatedStorage/Modules/PlayerRuntimeStats.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (31 total, 6 thin omitted)

### Community 0 - "CameraSession.luau"
Cohesion: 0.09
Nodes (29): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.IsActive() (+21 more)

### Community 1 - "Camera Framework"
Cohesion: 0.08
Nodes (31): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, BuyHandler, Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraEffects, CameraId Attribute, CameraInventory (server) (+23 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.07
Nodes (32): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraClient (LocalScript), CameraShelfGui, CameraShelfHandler (server), CameraShotHandler (server), CameraStability, CameraStats, CameraViewfinder (+24 more)

### Community 3 - "StartGame.luau"
Cohesion: 0.20
Nodes (12): CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.GetCurrentId(), CameraInventory.Give(), CameraShelfSwap.ClearCameraSlot(), CameraShelfSwap.TakeCamera(), bindDeathHandler(), onPlayerAdded() (+4 more)

### Community 4 - "MonsterAgent.luau"
Cohesion: 0.11
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
Cohesion: 0.12
Nodes (18): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+10 more)

### Community 11 - "PurchaseNotification.luau"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 12 - "ObjectiveRegistry.luau"
Cohesion: 0.57
Nodes (5): bootstrap(), considerInstance(), register(), unregister(), watchAttribute()

### Community 13 - "CameraStats.luau"
Cohesion: 0.10
Nodes (19): CameraStability.IsMoving(), CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetIdFromTool(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings() (+11 more)

### Community 18 - "RewardLedger.luau"
Cohesion: 0.16
Nodes (22): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), currentPersistentValues(), getOrCreateLeaderstats(), getValue() (+14 more)

### Community 19 - "CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

### Community 27 - "Remotes.luau"
Cohesion: 0.08
Nodes (6): ShotResultCodes.GetMessage(), UIBuilder.CreateScreenGui(), CameraSessionTracker.IsInCamera(), ensureBuilt(), showCurrencyUI(), buildHitText()

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
- **Why does `ObjectiveRegistry.All()` connect `ObjectiveService.luau` to `ObjectiveRegistry.luau`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `CameraSession.Enter()` connect `CameraSession.luau` to `CameraViewfinder.luau`, `CameraStats.luau`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **Why does `handleShot()` connect `CameraStats.luau` to `RewardService.luau`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `CameraShelfGui.Build()` (e.g. with `CameraStats.GetOrderedIds()` and `openShelf()`) actually correct?**
  _`CameraShelfGui.Build()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point` to the rest of the system?**
  _49 weakly-connected nodes found - possible documentation gaps or missing edges._