# Graph Report - ROBLOX-DEV  (2026-07-28)

## Corpus Check
- 63 files · ~25,097 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 322 nodes · 452 edges · 32 communities (28 shown, 4 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 78 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d91db68c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CameraSession.Enter
- Camera Framework
- Monster System Blueprint
- StartGame.luau
- MonsterAgent.luau
- CameraViewfinder.luau
- Reward System
- CameraShelfGui.luau
- Photo Scoring Blueprint
- RewardService.AwardFromCapture
- ShopFillSlot.luau
- CaptureGuard.luau
- RewardLedger.luau
- CameraTouchHud.luau
- CameraFlashEffect
- FloatingShotText
- Remotes (Shared Utility)
- MonsterSensing

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 18 edges
2. `Reward System` - 12 edges
3. `Photo Scoring Blueprint` - 10 edges
4. `CameraStats.GetStats()` - 9 edges
5. `ensureBuilt()` - 9 edges
6. `RewardService.AwardFromCapture()` - 9 edges
7. `CameraShelfGui.Build()` - 8 edges
8. `handleShot()` - 8 edges
9. `CameraSession.Exit()` - 7 edges
10. `CameraState.Get()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `CaptureGuard.ResolveShotQuality()` --calls--> `CameraStats.GetStabilitySettings()`  [INFERRED]
  ServerScriptService/GameService/Reward/CaptureGuard.luau → ReplicatedStorage/Modules/Camera/CameraStats.luau
- `handleShot()` --calls--> `CameraStats.GetShotSettings()`  [INFERRED]
  ServerScriptService/GameService/Camera/CameraShotHandler.legacy.luau → ReplicatedStorage/Modules/Camera/CameraStats.luau
- `handleShot()` --calls--> `CameraStats.GetIdFromTool()`  [INFERRED]
  ServerScriptService/GameService/Camera/CameraShotHandler.legacy.luau → ReplicatedStorage/Modules/Camera/CameraStats.luau
- `RewardService.AwardFromCapture()` --calls--> `CaptureRules.Check()`  [INFERRED]
  ServerScriptService/GameService/Reward/RewardService.luau → ReplicatedStorage/Modules/Reward/CaptureRules.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (32 total, 4 thin omitted)

### Community 0 - "CameraSession.Enter"
Cohesion: 0.08
Nodes (33): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraFlashEffect.Play(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit() (+25 more)

### Community 1 - "Camera Framework"
Cohesion: 0.08
Nodes (31): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, BuyHandler, Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraEffects, CameraId Attribute, CameraInventory (server) (+23 more)

### Community 2 - "Monster System Blueprint"
Cohesion: 0.07
Nodes (32): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraClient (LocalScript), CameraShelfGui, CameraShelfHandler (server), CameraShotHandler (server), CameraStability, CameraStats, CameraViewfinder (+24 more)

### Community 3 - "StartGame.luau"
Cohesion: 0.13
Nodes (12): CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.GetCurrentId(), CameraInventory.Give(), CameraShelfSwap.ClearCameraSlot(), CameraShelfSwap.TakeCamera(), bindDeathHandler() (+4 more)

### Community 4 - "MonsterAgent.luau"
Cohesion: 0.11
Nodes (11): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill(), MonsterMovement.MoveTo() (+3 more)

### Community 5 - "CameraViewfinder.luau"
Cohesion: 0.24
Nodes (13): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Hide(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel() (+5 more)

### Community 6 - "Reward System"
Cohesion: 0.11
Nodes (19): ⚠ Anti-exploit — this lands before the payout, Architecture, Balance note: the curve's tail is currently unreachable, Build order, Calculation pipeline, Configuration, Data flow: Camera → Reward System, Distance multiplier (+11 more)

### Community 7 - "CameraShelfGui.luau"
Cohesion: 0.29
Nodes (8): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build()

### Community 9 - "Photo Scoring Blueprint"
Cohesion: 0.15
Nodes (11): Build order, Contract 1 — Units, Contract 2 — Scoring, Contract 3 — Reward routing, Files, Known bias: distance is measured to the hit point, Photo Scoring Blueprint, ⚠ Security — this must land before the payout (+3 more)

### Community 10 - "RewardService.AwardFromCapture"
Cohesion: 0.12
Nodes (18): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.Get(), CaptureTargets.IsType(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+10 more)

### Community 11 - "ShopFillSlot.luau"
Cohesion: 0.60
Nodes (3): ShopPrices.GetPrice(), findSlot(), ShopFillSlot.PurchaseItem()

### Community 13 - "CaptureGuard.luau"
Cohesion: 0.16
Nodes (9): CameraStability.IsMoving(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown(), isFiniteVector() (+1 more)

### Community 18 - "RewardLedger.luau"
Cohesion: 0.14
Nodes (23): RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), RemoveAllSlot.ClearPlayerTools(), onPlayerAdded(), onPlayerRemoving(), currentPersistentValues(), getOrCreateLeaderstats() (+15 more)

### Community 19 - "CameraTouchHud.luau"
Cohesion: 0.38
Nodes (3): buildCircleButton(), CameraTouchHud.Init(), ensureBuilt()

## Ambiguous Edges - Review These
- `Graphify Knowledge Graph Workflow` → `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **49 isolated node(s):** `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point`, `Contract 3 — Reward routing`, `⚠ Security — this must land before the payout` (+44 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `RewardService.Grant()` connect `RewardService.AwardFromCapture` to `RewardLedger.luau`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Why does `RewardLedger.Add()` connect `RewardLedger.luau` to `RewardService.AwardFromCapture`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Why does `RewardService.AwardFromCapture()` connect `RewardService.AwardFromCapture` to `CaptureGuard.luau`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point` to the rest of the system?**
  _49 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CameraSession.Enter` be split into smaller, more focused modules?**
  _Cohesion score 0.0841813135985199 - nodes in this community are weakly interconnected._