# Graph Report - .  (2026-07-27)

## Corpus Check
- Corpus is ~11,771 words - fits in a single context window. You may not need a graph.

## Summary
- 215 nodes · 291 edges · 28 communities (24 shown, 4 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 51 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Camera Lighting Effects & Flash
- Camera Refactor Design Doc
- Photo Capture & Monster Blueprint
- Player Stats & Camera Inventory
- Monster Movement & Damage
- Viewfinder GUI Construction
- Camera Session Entry & Stats
- Camera Shelf GUI Builder
- Camera Client Bootstrap Scripts
- Monster Agent State Machine
- Shop Pricing & Purchase
- Photo Raycast Capture
- Camera Flash Effect Module
- Floating Shot Text Module
- Shared Remotes Utility
- Monster Sensing Module

## God Nodes (most connected - your core abstractions)
1. `CameraSession.Enter()` - 17 edges
2. `CameraStats.GetStats()` - 9 edges
3. `ensureBuilt()` - 9 edges
4. `CameraShelfGui.Build()` - 8 edges
5. `CameraViewfinder.Show()` - 7 edges
6. `Camera Framework` - 7 edges
7. `CameraSession` - 7 edges
8. `CameraSession.Exit()` - 6 edges
9. `CameraState.Get()` - 6 edges
10. `Roblox Game Project Handoff` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Cooldown (Shared Utility)` --semantically_similar_to--> `MonsterDamage`  [INFERRED] [semantically similar]
  MAINHANDOFF.md → MONSTERS.md
- `Graphify Knowledge Graph Workflow` --conceptually_related_to--> `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md → MAINHANDOFF.md
- `CameraSession.Enter()` --calls--> `CameraViewfinder.Hide()`  [INFERRED]
  ReplicatedStorage/Modules/Camera/CameraSession.luau → ReplicatedStorage/Modules/Camera/CameraViewfinder.luau
- `handleShot()` --calls--> `CameraStats.GetShotSettings()`  [INFERRED]
  ServerScriptService/GameService/Camera/CameraShotHandler.legacy.luau → ReplicatedStorage/Modules/Camera/CameraStats.luau
- `handleShot()` --calls--> `CameraStats.GetIdFromTool()`  [INFERRED]
  ServerScriptService/GameService/Camera/CameraShotHandler.legacy.luau → ReplicatedStorage/Modules/Camera/CameraStats.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Camera Client Subsystem Modules** — mainhandoff_camerasession, mainhandoff_cameraeffects, mainhandoff_cameraviewfinder, mainhandoff_camerastability, mainhandoff_cameratoolcontroller, mainhandoff_cameraclient [EXTRACTED 0.90]
- **Camera Shelf Feature Modules** — mainhandoff_camerashelfgui, mainhandoff_camerainventory, mainhandoff_camerashelfswap, mainhandoff_camerashelfhandler, mainhandoff_shelfresultcodes [EXTRACTED 0.90]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (28 total, 4 thin omitted)

### Community 0 - "Camera Lighting Effects & Flash"
Cohesion: 0.10
Nodes (21): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraFlashEffect.Play(), CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive() (+13 more)

### Community 1 - "Camera Refactor Design Doc"
Cohesion: 0.08
Nodes (31): CLAUDE.md Graphify Instructions, Graphify Knowledge Graph Workflow, BuyHandler, Camera Framework, Camera System Rebuilt for Modularity (from God-Object), CameraEffects, CameraId Attribute, CameraInventory (server) (+23 more)

### Community 2 - "Photo Capture & Monster Blueprint"
Cohesion: 0.09
Nodes (25): Strong/Weak Shot Client-Trust Exploit (Known Gap), CameraShelfHandler (server), CameraShotHandler (server), CanCapture Attribute, Cooldown (Shared Utility), PhotoCapture (server), Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation (+17 more)

### Community 3 - "Player Stats & Camera Inventory"
Cohesion: 0.13
Nodes (12): CameraSessionTracker.IsInCamera(), CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.GetCurrentId(), CameraInventory.Give(), CameraShelfSwap.ClearCameraSlot(), CameraShelfSwap.TakeCamera(), bindDeathHandler() (+4 more)

### Community 4 - "Monster Movement & Damage"
Cohesion: 0.14
Nodes (7): getCooldownTable(), MonsterDamage.ClearAgent(), MonsterDamage.TryKill(), MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), MonsterService.Spawn(), Chase.Update()

### Community 5 - "Viewfinder GUI Construction"
Cohesion: 0.24
Nodes (13): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Hide(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel() (+5 more)

### Community 6 - "Camera Session Entry & Stats"
Cohesion: 0.31
Nodes (12): CameraSession.Enter(), CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetIdFromTool(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings() (+4 more)

### Community 7 - "Camera Shelf GUI Builder"
Cohesion: 0.29
Nodes (8): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build()

### Community 8 - "Camera Client Bootstrap Scripts"
Cohesion: 0.29
Nodes (7): CameraClient (LocalScript), CameraShelfGui, CameraStability, CameraStats, CameraViewfinder, ShelfResultCodes, ViewfinderTheme

### Community 9 - "Monster Agent State Machine"
Cohesion: 0.53
Nodes (4): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick()

### Community 11 - "Shop Pricing & Purchase"
Cohesion: 0.60
Nodes (3): ShopPrices.GetPrice(), findSlot(), ShopFillSlot.PurchaseItem()

### Community 12 - "Photo Raycast Capture"
Cohesion: 0.83
Nodes (3): buildBasis(), findCapturableFromHit(), PhotoCapture.Fire()

## Ambiguous Edges - Review These
- `Graphify Knowledge Graph Workflow` → `Hard-Won Debugging Lessons`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **25 isolated node(s):** `CLAUDE.md Graphify Instructions`, `LinearVelocity-based Movement`, `Sprint/Stamina System`, `Reactive HUD (BindableEvent)`, `IsEmpty Attribute` (+20 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Graphify Knowledge Graph Workflow` and `Hard-Won Debugging Lessons`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Camera Framework` connect `Camera Refactor Design Doc` to `Photo Capture & Monster Blueprint`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.)` connect `Photo Capture & Monster Blueprint` to `Camera Refactor Design Doc`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `CameraViewfinder.Show()` (e.g. with `CameraSession.Enter()` and `Trove.new()`) actually correct?**
  _`CameraViewfinder.Show()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `CLAUDE.md Graphify Instructions`, `LinearVelocity-based Movement`, `Sprint/Stamina System` to the rest of the system?**
  _25 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Camera Lighting Effects & Flash` be split into smaller, more focused modules?**
  _Cohesion score 0.1028225806451613 - nodes in this community are weakly interconnected._