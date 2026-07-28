# Graph Report - ROBLOX-DEV  (2026-07-28)

## Corpus Check
- 60 files · ~22,511 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 307 nodes · 419 edges · 32 communities (28 shown, 4 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 67 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d91db68c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- CameraSession.Enter
- CameraSession
- Camera Framework
- StartGame.luau
- MonsterAgent.luau
- CameraViewfinder.luau
- Reward System
- CameraShelfGui.luau
- Photo Scoring Blueprint
- CameraShotHandler.legacy.luau
- ShopFillSlot.luau
- PhotoCapture.luau
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
6. `CameraShelfGui.Build()` - 8 edges
7. `CameraSession.Exit()` - 7 edges
8. `CameraState.Get()` - 7 edges
9. `CameraViewfinder.Show()` - 7 edges
10. `RewardStore.Save()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `CaptureGuard.ResolveShotQuality()` --calls--> `CameraStats.GetStabilitySettings()`  [INFERRED]
  ServerScriptService/GameService/Reward/CaptureGuard.luau → ReplicatedStorage/Modules/Camera/CameraStats.luau
- `handleShot()` --calls--> `RewardCalculator.Calculate()`  [INFERRED]
  ServerScriptService/GameService/Camera/CameraShotHandler.legacy.luau → ReplicatedStorage/Modules/Reward/RewardCalculator.luau
- `getValue()` --calls--> `RewardTypes.Get()`  [INFERRED]
  ServerScriptService/GameService/Reward/RewardLedger.luau → ReplicatedStorage/Modules/Reward/RewardTypes.luau
- `Graphify Knowledge Graph Workflow` --conceptually_related_to--> `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md → MAINHANDOFF.md

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

### Community 1 - "CameraSession"
Cohesion: 0.07
Nodes (34): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, BuyHandler, CameraClient (LocalScript), CameraEffects, CameraInventory (server), CameraSession, CameraSessionTracker (server) (+26 more)

### Community 2 - "Camera Framework"
Cohesion: 0.08
Nodes (29): Camera Framework, Strong/Weak Shot Client-Trust Exploit (Known Gap), Camera System Rebuilt for Modularity (from God-Object), CameraId Attribute, CameraShelfHandler (server), CameraShotHandler (server), CameraState, CanCapture Attribute (+21 more)

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

### Community 10 - "CameraShotHandler.legacy.luau"
Cohesion: 0.13
Nodes (7): RewardCalculator.Calculate(), RewardModifiers.Collect(), Units.StudsToMeters(), handleShot(), flagIfAnomalous(), RewardService.AwardFromCapture(), RewardService.Grant()

### Community 11 - "ShopFillSlot.luau"
Cohesion: 0.60
Nodes (3): ShopPrices.GetPrice(), findSlot(), ShopFillSlot.PurchaseItem()

### Community 12 - "PhotoCapture.luau"
Cohesion: 0.83
Nodes (3): buildBasis(), findCapturableFromHit(), PhotoCapture.Fire()

### Community 13 - "CaptureGuard.luau"
Cohesion: 0.36
Nodes (5): CameraStability.IsMoving(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), isFiniteVector(), validateOrigin()

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
- **Why does `RewardService.Grant()` connect `CameraShotHandler.legacy.luau` to `RewardLedger.luau`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Why does `RewardLedger.Add()` connect `RewardLedger.luau` to `CameraShotHandler.legacy.luau`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `Camera Framework` connect `Camera Framework` to `CameraSession`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `The core idea`, `Contract 1 — Units`, `Known bias: distance is measured to the hit point` to the rest of the system?**
  _49 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CameraSession.Enter` be split into smaller, more focused modules?**
  _Cohesion score 0.0841813135985199 - nodes in this community are weakly interconnected._