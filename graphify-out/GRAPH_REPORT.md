# Graph Report - .  (2026-08-06)

## Corpus Check
- 51 files · ~162,428 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1800 nodes · 3076 edges · 148 communities (132 shown, 16 thin omitted)
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 641 edges (avg confidence: 0.8)
- Token cost: 76,558 input · 0 output

## Community Hubs (Navigation)
- Match Time & Queue HUD
- Lobby Launch & Config
- Match Time & Queue HUD
- Lobby Launch & Config
- Loadout Persistence
- Reward Types & Currency
- Camera Touch HUD
- Camera Shelf UI
- Camera Touch HUD
- Player & Match State Enums
- Objective State & Types
- Objective State & Types
- Capture Rules & Targets
- Pickup Types & Signals
- Server Role & Arrival
- Match State Enum
- Pickup Types & Handlers
- Server Role & Match Cleanup
- Player State Enum
- Queue Controller & Cooldown
- Spectate Service
- ProfileStore Vendor
- Loadout & Camera Inventory
- Camera Session & Effects
- Reward Calculator
- Camera Shelf UI
- Monster System Blueprint
- Shop Purchase UI
- Match Participants
- Shop Purchase UI
- Camera Session & Effects
- Encounter Director
- Encounter Director
- Camera Tool Controller
- Match Time Service & Events
- Match Time Service & Events
- Camera Shot Handling
- Camera Viewfinder
- Camera Shot Handling
- Camera Viewfinder
- Match End Condition
- Match Time Client & Math
- Match Time Client & Math
- Signal Primitive
- Match Lifecycle Modules
- Camera Stats
- Match Phases
- Match Launcher
- Monster Damage & Movement
- Camera Tool Controller
- Camera Stats
- Match Phases
- Pickup Visuals
- Monster Damage & Movement
- Reward Store Migration Debt
- Shot Security Boundary
- Camera State
- Boot Order Gotchas
- Camera State
- Pickup Visuals
- Queue Pad Display
- Spectate Camera Controller
- Monster Stage Escalation
- Touch UI Layering Gotchas
- Queue Pad Display
- Match Stats & Grade
- Spectate Camera Controller
- XP Migration Tool
- CLAUDE.md Workflow Rules
- Roblox Project Facts
- Reward Curves
- Work Mode Conventions
- Teleport Round Trip
- Shot Feedback UI
- Monster Agent & Stats
- Death Service
- Reward Seams & Persistence
- Studio vs Live Gotchas
- Monster Agent & Stats
- Death Service
- Return To Lobby
- Cash Pickup & Wallet
- Match Result Builder
- Match Time Replicator
- Pickup Claim Race Safety
- Movement Authority
- Match Time Authority
- Match Time Replicator
- Launch Gate Timing
- Match Arrival
- Match Time Lighting
- Touch & Orientation Gotchas
- Sunrise Ending Order
- Queue Pad Identity
- Match Arrival
- Match Time Lighting
- Photo Scoring
- Camera Tool Watcher
- Photo Capture Distance
- Boot Entry Points
- Screen Flash Renderer
- World Light Renderer
- Continuous Hour Scale
- Screen Flash Renderer
- World Light Renderer
- Cleanup Timeout Ordering
- Match Clock & End Condition
- Spectate Targets
- Data-Driven Config Rules
- ProfileStore Diagnostics
- Deleted Mirror Tooling
- Match Config
- Match Replicator
- Published Build Verification
- Player States
- Monster Sensing

## God Nodes (most connected - your core abstractions)
1. `ServerRole.AssertGameServer()` - 19 edges
2. `ServerRole.AssertGameServer()` - 19 edges
3. `CameraSession.Enter()` - 18 edges
4. `CameraSession.Enter()` - 18 edges
5. `ensureBuilt()` - 16 edges
6. `ensureBuilt()` - 16 edges
7. `Remotes.Get()` - 13 edges
8. `Remotes.Get()` - 13 edges
9. `onPromptTriggered()` - 12 edges
10. `onPromptTriggered()` - 12 edges

## Surprising Connections (you probably didn't know these)
- `No DataStore session locking (deferred debt)` --semantically_similar_to--> `Known gap: no session locking`  [INFERRED] [semantically similar]
  docs/Planned.md → REWARD_SYSTEM.md
- `PickupVisuals.Apply()` --calls--> `Trove.new()`  [INFERRED]
  Lobby/ReplicatedStorage/Modules/Pickup/PickupVisuals.luau → Lobby/ReplicatedStorage/Modules/Shared/Trove.luau
- `renderStats()` --calls--> `CaptureTargets.OrderedNames()`  [INFERRED]
  Lobby/ReplicatedStorage/Modules/UI/MatchReceipt.luau → Lobby/ReplicatedStorage/Modules/Reward/CaptureTargets.luau
- `SpectateService.SetTarget()` --calls--> `PlayerStates.CanSpectate()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Spectate/SpectateService.luau → Lobby/ReplicatedStorage/Modules/Shared/PlayerStates.luau
- `CameraSessionTracker.Start()` --calls--> `Remotes.Get()`  [INFERRED]
  Lobby/ServerScriptService/GameService/Camera/CameraSessionTracker.luau → Lobby/ReplicatedStorage/Modules/Shared/Remotes.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Match time authority: schedule, clock, phases, replication** — mainhandoff_matchschedule, mainhandoff_matchclock, mainhandoff_matchphases, mainhandoff_matchtimeevents, mainhandoff_matchtimereplicator, mainhandoff_matchtimelighting, mainhandoff_continuous_hour_scale [EXTRACTED 1.00]
- **Queue pad matchmaking flow (sense → arm → launch → teleport)** — mainhandoff_queuepadservice, mainhandoff_queueservice, mainhandoff_partyservice, mainhandoff_launchgate, mainhandoff_matchlauncher, mainhandoff_queueresultcodes, mainhandoff_queuepaddisplay [EXTRACTED 1.00]
- **Gotchas where Studio behaviour diverges from a published build** — mainhandoff_g3_execute_luau_isolation, mainhandoff_g6_touchenabled_race, mainhandoff_g10_teleport_403_studio, mainhandoff_g14_humanoid_no_replicate, mainhandoff_g21_guardnonreservedserver [INFERRED 0.85]
- **Reward pipeline: shot to persisted currency** — reward_system_rewardservice, reward_system_rewardcalculator, reward_system_rewardledger, reward_system_rewardstore [EXTRACTED 1.00]
- **Phase 12.5: six deviations closed** — plans_phase_12_5_v1_migration_gate_bug, plans_phase_12_5_onlaunched_timing_bug, plans_phase_12_5_save_confirm_timeout, plans_phase_12_5_step_timeout, plans_phase_12_5_checkprogression, plans_phase_12_5_module_scope_side_effects, plans_phase_12_5_rewardstorediagnostics [EXTRACTED 0.95]
- **Grey Cube MVP Module Set** — monsters_monsterstats, monsters_monsterservice, monsters_monsteragent, monsters_state_chase, monsters_monsterdamage, monsters_monstersensing, monsters_monstermovement, monsters_behaviors_greycube [EXTRACTED 0.90]

## Communities (148 total, 16 thin omitted)

### Community 0 - "Match Time & Queue HUD"
Cohesion: 0.05
Nodes (56): ensureBuilt(), MatchTimeHud.Hide(), MatchTimeHud.Update(), getMatchState(), tick(), ensureBuilt(), QueueHud.Hide(), QueueHud.SetMessage() (+48 more)

### Community 1 - "Lobby Launch & Config"
Cohesion: 0.06
Nodes (55): MatchConfig.Get(), ServerRole.AssertLobbyServer(), LaunchGate.Check(), LaunchGate.OnLaunchAborted(), LaunchGate.OnLaunched(), LaunchGate.RegisterOnLaunchAborted(), LaunchGate.RegisterOnLaunched(), LaunchGate.RegisterPrecondition() (+47 more)

### Community 2 - "Match Time & Queue HUD"
Cohesion: 0.06
Nodes (49): ensureBuilt(), MatchTimeHud.Hide(), MatchTimeHud.Update(), getMatchState(), tick(), ensureBuilt(), QueueHud.Hide(), QueueHud.SetMessage() (+41 more)

### Community 3 - "Lobby Launch & Config"
Cohesion: 0.07
Nodes (48): MatchConfig.Get(), LaunchGate.Check(), LaunchGate.OnLaunched(), LaunchGate.RegisterOnLaunchAborted(), LaunchGate.RegisterOnLaunched(), LaunchGate.RegisterPrecondition(), onPlayerRemoving(), PartyService.GetLeader() (+40 more)

### Community 4 - "Loadout Persistence"
Cohesion: 0.07
Nodes (42): attempt(), keyFor(), LoadoutService.ClearSession(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), RewardTypes.Get(), RewardTypes.Persistent() (+34 more)

### Community 5 - "Reward Types & Currency"
Cohesion: 0.06
Nodes (31): LoadoutService.ClearSession(), RewardTypes.Get(), RewardTypes.Persistent(), RewardTypes.RunScoped(), onPlayerAdded(), onPlayerRemoving(), checkProgression(), onLaunchAborted() (+23 more)

### Community 6 - "Camera Touch HUD"
Cohesion: 0.06
Nodes (28): buildCircleButton(), CameraTouchHud.Init(), CameraTouchHud.SetInCamera(), CameraTouchHud.Show(), ensureBuilt(), ensureReady(), isTouchDevice(), PlayerRuntimeStats.Get() (+20 more)

### Community 7 - "Camera Shelf UI"
Cohesion: 0.05
Nodes (18): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+10 more)

### Community 8 - "Camera Touch HUD"
Cohesion: 0.06
Nodes (28): buildCircleButton(), CameraTouchHud.Init(), CameraTouchHud.SetInCamera(), CameraTouchHud.Show(), ensureBuilt(), ensureReady(), isTouchDevice(), PlayerRuntimeStats.Get() (+20 more)

### Community 9 - "Player & Match State Enums"
Cohesion: 0.09
Nodes (35): MatchStates.IsSpectateAllowed(), PlayerStates.CanControlCharacter(), PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.IsValid(), PlayerStates.Validate(), Remotes.Get(), LobbyBoot.Start() (+27 more)

### Community 10 - "Objective State & Types"
Cohesion: 0.09
Nodes (27): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+19 more)

### Community 11 - "Objective State & Types"
Cohesion: 0.09
Nodes (26): ObjectiveStateClient.GetEffectiveState(), ObjectiveStates.IsValid(), ObjectiveTypes.Get(), ObjectiveTypes.TypeOf(), ObjectiveVisuals.Clear(), ObjectiveVisuals.ClearAll(), clearAllVisible(), considerInstance() (+18 more)

### Community 12 - "Capture Rules & Targets"
Cohesion: 0.08
Nodes (25): CaptureRules.Check(), CaptureTargets.AttributeFor(), CaptureTargets.IsType(), CaptureTargets.OrderedNames(), CaptureTargets.Resolve(), CaptureTargets.TypeOf(), applyModifiers(), calculateCurve() (+17 more)

### Community 13 - "Pickup Types & Signals"
Cohesion: 0.09
Nodes (21): PickupResultCodes.GetMessage(), PickupTypes.Get(), PickupTypes.TypeOf(), PickupHandlers.Get(), anchorPartOf(), PickupPrompt.Clear(), PickupPrompt.Disable(), PickupPrompt.Enable() (+13 more)

### Community 14 - "Server Role & Arrival"
Cohesion: 0.09
Nodes (24): resolve(), ServerRole.AssertGameServer(), ServerRole.AssertLobbyServer(), ServerRole.Get(), ServerRole.Is(), ArrivalService.Start(), handleArrival(), LaunchGate.Start() (+16 more)

### Community 15 - "Match State Enum"
Cohesion: 0.11
Nodes (25): MatchStates.AcceptsJoins(), MatchStates.CanTransition(), MatchStates.IsKitGranted(), MatchStates.IsScoringActive(), MatchStates.IsSpectateAllowed(), MatchStates.IsTerminal(), MatchStates.IsValid(), MatchManager.Abort() (+17 more)

### Community 16 - "Pickup Types & Handlers"
Cohesion: 0.12
Nodes (21): PickupResultCodes.GetMessage(), PickupTypes.Get(), PickupTypes.TypeOf(), PickupHandlers.Get(), anchorPartOf(), PickupPrompt.Clear(), PickupPrompt.Disable(), PickupPrompt.Enable() (+13 more)

### Community 17 - "Server Role & Match Cleanup"
Cohesion: 0.11
Nodes (19): resolve(), ServerRole.AssertGameServer(), ServerRole.Get(), ServerRole.Is(), MatchCleanup.RegisterSaveStep(), MatchCleanup.RegisterTeardownStep(), MatchCleanup.Start(), runCleanup() (+11 more)

### Community 18 - "Player State Enum"
Cohesion: 0.12
Nodes (18): PlayerStates.CanSpectate(), PlayerStates.CanTransition(), PlayerStates.CountsAsActive(), PlayerStates.IsValid(), PlayerStates.Validate(), LobbyBoot.Start(), bindCharacter(), LobbyDeathPolicy.Start() (+10 more)

### Community 20 - "Spectate Service"
Cohesion: 0.21
Nodes (20): PlayerStates.CanControlCharacter(), Remotes.Get(), PlayerStateService.Get(), assignBest(), fireSync(), onMatchStateChanged(), onPlayerRemoving(), onPlayerStateChanged() (+12 more)

### Community 21 - "ProfileStore Vendor"
Cohesion: 0.10
Nodes (4): AcquireRunnerThreadAndCallEventHandler(), ProfileStore:VersionQuery(), ProfileVersionQuery.New(), RunEventHandlerInFreeThread()

### Community 22 - "Loadout & Camera Inventory"
Cohesion: 0.18
Nodes (14): attempt(), keyFor(), LoadoutService.GetCameraId(), LoadoutService.Load(), LoadoutService.Save(), CameraInventory.ClearSlot(), CameraInventory.FindSlot(), CameraInventory.Give() (+6 more)

### Community 23 - "Camera Session & Effects"
Cohesion: 0.18
Nodes (18): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Capture(), CameraSession.Enter(), CameraSession.Exit(), CameraSession.Toggle() (+10 more)

### Community 24 - "Reward Calculator"
Cohesion: 0.17
Nodes (12): CaptureRules.Check(), applyModifiers(), calculateCurve(), calculateFlatRoll(), RewardCalculator.Calculate(), RewardCalculator.Describe(), RewardModifiers.Collect(), Units.StudsToMeters() (+4 more)

### Community 25 - "Camera Shelf UI"
Cohesion: 0.17
Nodes (14): CameraStats.GetOrderedIds(), buildCameraRow(), buildCloseButton(), buildListHolder(), buildMessageLabel(), buildPanel(), buildTitle(), CameraShelfGui.Build() (+6 more)

### Community 26 - "Monster System Blueprint"
Cohesion: 0.12
Nodes (19): Behavior Hook Layer (OnSpawn/OnUpdate/OnPhotographed/etc.), 3 Monsters x 3 Behavior Variants Recommendation, Behaviors/GreyCube, CanCapture Attribute (Monster Model), Evolution Doubles Per-Monster Cost (Risk), Monster System Blueprint, MonsterAgent, MonsterAggression (+11 more)

### Community 27 - "Shop Purchase UI"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 28 - "Match Participants"
Cohesion: 0.17
Nodes (13): MatchStates.AcceptsJoins(), MatchStates.IsKitGranted(), MatchStates.IsScoringActive(), MatchManager.Get(), MatchParticipants.CountActive(), MatchParticipants.GetPresent(), MatchParticipants.IsParticipant(), loadIfNeeded() (+5 more)

### Community 29 - "Shop Purchase UI"
Cohesion: 0.17
Nodes (10): playSound(), PurchaseNotification.Handle(), showText(), PurchaseResultCodes.GetMessage(), ShopPrices.GetPrice(), SoundIds.GetSoundId(), findSlot(), ShopFillSlot.PurchaseItem() (+2 more)

### Community 30 - "Camera Session & Effects"
Cohesion: 0.21
Nodes (11): CameraEffects.Apply(), CameraEffects.Clear(), CameraEffects.GetBlurAlpha(), CameraEffects.UpdateFromSpeed(), CameraSession.Enter(), CameraSession.UpdateBlur(), hideOtherGuis(), setToolLocalTransparency() (+3 more)

### Community 31 - "Encounter Director"
Cohesion: 0.19
Nodes (13): MatchStates.IsGameplayActive(), MatchStates.MonstersSpawn(), cframeOf(), despawnEncounter(), effectiveStage(), EncounterDirector.Start(), findSpawnPoints(), restageEncounter() (+5 more)

### Community 32 - "Encounter Director"
Cohesion: 0.19
Nodes (13): MatchStates.IsGameplayActive(), MatchStates.MonstersSpawn(), cframeOf(), despawnEncounter(), effectiveStage(), EncounterDirector.Start(), findSpawnPoints(), restageEncounter() (+5 more)

### Community 33 - "Camera Tool Controller"
Cohesion: 0.20
Nodes (12): CameraSession.Capture(), CameraSession.Exit(), CameraSession.IsActive(), CameraSession.Toggle(), CameraState.Get(), CameraState.GetStable(), CameraState.SetMovementSettings(), CameraToolController.GetEquipped() (+4 more)

### Community 34 - "Match Time Service & Events"
Cohesion: 0.20
Nodes (8): MatchPhases.FromHour(), MatchTimeEvents.Dispatch(), MatchTimeEvents.Reset(), MatchTimeService.GetPhase(), MatchTimeService.Start(), sample(), startClock(), stopClock()

### Community 35 - "Match Time Service & Events"
Cohesion: 0.20
Nodes (8): MatchPhases.FromHour(), MatchTimeEvents.Dispatch(), MatchTimeEvents.Reset(), MatchTimeService.GetPhase(), MatchTimeService.Start(), sample(), startClock(), stopClock()

### Community 36 - "Camera Shot Handling"
Cohesion: 0.22
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 37 - "Camera Viewfinder"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 38 - "Camera Shot Handling"
Cohesion: 0.22
Nodes (10): CameraStability.IsMoving(), CameraStats.GetIdFromTool(), getEquippedCameraTool(), handleShot(), CaptureGuard.CheckRepeatPolicy(), CaptureGuard.ResolveShotQuality(), CaptureGuard.ValidateShot(), checkCooldown() (+2 more)

### Community 39 - "Camera Viewfinder"
Cohesion: 0.26
Nodes (12): applyGrain(), applyScanlines(), applyVignette(), CameraViewfinder.Show(), createBar(), createBracket(), createCornerLabel(), createGrainFrame() (+4 more)

### Community 40 - "Match End Condition"
Cohesion: 0.23
Nodes (11): MatchStates.CanTransition(), MatchStates.IsTerminal(), MatchStates.IsValid(), PlayerStates.CountsAsActive(), evaluate(), MatchEndCondition.Start(), MatchManager.Abort(), MatchManager.Is() (+3 more)

### Community 41 - "Match Time Client & Math"
Cohesion: 0.26
Nodes (11): getMatchInfo(), MatchTimeClient.GetAnchors(), MatchTimeClient.GetHour(), MatchTimeClient.GetHourText(), MatchTimeClient.GetPhase(), MatchTimeClient.GetProgress(), MatchTimeMath.FormatHour(), MatchTimeMath.HourToReal() (+3 more)

### Community 42 - "Match Time Client & Math"
Cohesion: 0.26
Nodes (11): getMatchInfo(), MatchTimeClient.GetAnchors(), MatchTimeClient.GetHour(), MatchTimeClient.GetHourText(), MatchTimeClient.GetPhase(), MatchTimeClient.GetProgress(), MatchTimeMath.FormatHour(), MatchTimeMath.HourToReal() (+3 more)

### Community 43 - "Signal Primitive"
Cohesion: 0.17
Nodes (5): MatchManager.GetElapsed(), MatchParticipants.All(), buildPerPlayer(), MatchResultBuilder.Build(), MatchResultBuilder.Start()

### Community 44 - "Match Lifecycle Modules"
Cohesion: 0.17
Nodes (12): DeathService, KitLifecycleHook, LobbyDeathPolicy, MatchCleanup, MatchManager, MatchParticipants, MatchResultBuilder, MatchResultSync (+4 more)

### Community 45 - "Camera Stats"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 46 - "Match Phases"
Cohesion: 0.21
Nodes (7): MatchPhases.GetMonsterStage(), MatchPhases.Validate(), MatchSchedule.Get(), MatchSchedule.Validate(), MatchStates.Validate(), GameBoot.Start(), guardNonReservedServer()

### Community 47 - "Match Launcher"
Cohesion: 0.24
Nodes (9): LaunchGate.OnLaunchAborted(), handleInitFailed(), MatchLauncher.Launch(), attemptReturn(), buildTeleportData(), handleInitFailed(), handleReturnRequest(), ReturnToLobbyService.ReturnAll() (+1 more)

### Community 48 - "Monster Damage & Movement"
Cohesion: 0.18
Nodes (5): getCooldownTable(), MonsterDamage.TryKill(), MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 49 - "Camera Tool Controller"
Cohesion: 0.24
Nodes (8): CameraSession.IsActive(), CameraToolController.GetEquipped(), CameraToolController.Init(), fireEquippedChanged(), onCharacterAdded(), tryInit(), watchContainer(), onOpenPressed()

### Community 50 - "Camera Stats"
Cohesion: 0.29
Nodes (9): CameraStats.GetBlurSettings(), CameraStats.GetColorGradeSettings(), CameraStats.GetEffectsSettings(), CameraStats.GetFlashSettings(), CameraStats.GetMovementSettings(), CameraStats.GetShotSettings(), CameraStats.GetStabilitySettings(), CameraStats.GetStats() (+1 more)

### Community 51 - "Match Phases"
Cohesion: 0.21
Nodes (7): MatchPhases.GetMonsterStage(), MatchPhases.Validate(), MatchSchedule.Get(), MatchSchedule.Validate(), MatchStates.Validate(), GameBoot.Start(), guardNonReservedServer()

### Community 52 - "Pickup Visuals"
Cohesion: 0.23
Nodes (6): PickupVisuals.Apply(), PickupVisuals.Clear(), PickupVisuals.Step(), clearAllVisible(), considerInstance(), unregister()

### Community 53 - "Monster Damage & Movement"
Cohesion: 0.18
Nodes (5): getCooldownTable(), MonsterDamage.TryKill(), MonsterMovement.MoveTo(), MonsterSensing.GetNearestPlayer(), Chase.Update()

### Community 54 - "Reward Store Migration Debt"
Cohesion: 0.20
Nodes (11): No DataStore session locking (deferred debt), checkProgression (RewardLaunchHook), RewardStore.Load, v1 migration gate is one-shot (data-loss bug), EndGame.luau, PlayerCurrency.legacy.luau, RewardLedger, RewardModifiers (+3 more)

### Community 55 - "Shot Security Boundary"
Cohesion: 0.20
Nodes (11): CameraShotHandler.legacy.luau, CaptureGuard.ValidateShot, FlashEvents (server, no subscribers), Security boundary — client-reported flags are UX only, CameraShotHandler.legacy.luau, Client-supplied origin exploit, PlayerRewards.Award, CaptureContext shape (+3 more)

### Community 56 - "Camera State"
Cohesion: 0.24
Nodes (4): CameraState.SetInCamera(), CameraState.SetStable(), fireListeners(), fireStableListeners()

### Community 57 - "Boot Order Gotchas"
Cohesion: 0.20
Nodes (10): Bootstrap.legacy.luau, G20 — no guaranteed Connect handler order, G21 — guardNonReservedServer blocks Game boot in Studio, G9 — no guaranteed Script execution order, GameBoot, MatchTimeService, RemoteEvents only, result code strings, Remotes.ALL_NAMES (+2 more)

### Community 58 - "Camera State"
Cohesion: 0.24
Nodes (4): CameraState.SetInCamera(), CameraState.SetStable(), fireListeners(), fireStableListeners()

### Community 59 - "Pickup Visuals"
Cohesion: 0.33
Nodes (6): PickupVisuals.Apply(), PickupVisuals.Clear(), PickupVisuals.Step(), clearAllVisible(), considerInstance(), unregister()

### Community 60 - "Queue Pad Display"
Cohesion: 0.36
Nodes (6): bootstrap(), considerInstance(), findLabel(), refresh(), QueuePadLabels.Counting(), QueuePadLabels.Format()

### Community 61 - "Spectate Camera Controller"
Cohesion: 0.50
Nodes (8): applySubject(), ensureFreeCameraAnchor(), ensureSubjectGuard(), getCamera(), resolveSubject(), SpectateCameraController.SetTarget(), SpectateCameraController.Stop(), tryExitCameraSession()

### Community 62 - "Monster Stage Escalation"
Cohesion: 0.22
Nodes (9): ClientBootstrap, Monster/EncounterDirector.luau, MatchPhases, Effective monster stage = max(authored, phase), MonsterService, PickupRegistry, PickupSpawner (planned, not built), Pickup/PickupTypes.luau (+1 more)

### Community 63 - "Touch UI Layering Gotchas"
Cohesion: 0.22
Nodes (8): ScreenGui DisplayOrder registry, G16 — DynamicThumbstickFrame occupies bottom-left, G1 — StarterGui LocalScripts re-run on respawn, StarterPlayerScripts/MobileSprintButton.local.luau, Playermovementcontroller, ReplicatedStorage/Modules/Movement/SprintIntent.luau, Tap-to-arm mobile sprint, UIBuilder.CreateScreenGui

### Community 64 - "Queue Pad Display"
Cohesion: 0.36
Nodes (6): bootstrap(), considerInstance(), findLabel(), refresh(), QueuePadLabels.Counting(), QueuePadLabels.Format()

### Community 65 - "Match Stats & Grade"
Cohesion: 0.33
Nodes (6): MatchGrade.Evaluate(), ensureCaptureRow(), MatchStats.Start(), onAwarded(), reset(), survivedSeconds()

### Community 66 - "Spectate Camera Controller"
Cohesion: 0.50
Nodes (8): applySubject(), ensureFreeCameraAnchor(), ensureSubjectGuard(), getCamera(), resolveSubject(), SpectateCameraController.SetTarget(), SpectateCameraController.Stop(), tryExitCameraSession()

### Community 67 - "XP Migration Tool"
Cohesion: 0.39
Nodes (7): classify(), describeTotals(), keyFor(), listAllV1UserIds(), read(), reportVerbose(), waitForBudget()

### Community 68 - "CLAUDE.md Workflow Rules"
Cohesion: 0.25
Nodes (6): Budgets (checkpoints, not walls), Done means verified, Graphify workflow rule, MCP vs Disk rule, Reporting format, Scope Contract

### Community 69 - "Roblox Project Facts"
Cohesion: 0.25
Nodes (8): Roblox Project Facts, LoadoutService, CameraInventory, CameraSessionTracker InCamera flag, CameraState, G12 — Spectate uses CameraType.Custom, not Scriptable, CameraShelfSwap, CameraSessionTracker module-scope side effects

### Community 70 - "Reward Curves"
Cohesion: 0.25
Nodes (8): CurveFactory, DistanceBandLabels, DistanceMultiplierCurve, RewardCalculator, RewardResult shape, RewardTypes, ScoreRewardCurve, XPRewardCurve

### Community 71 - "Work Mode Conventions"
Cohesion: 0.29
Nodes (7): Audit Mode, Bug Fix Mode, Implementation Mode, MAINHANDOFF.md convention, Plan files convention, Planning Mode, Work Modes

### Community 72 - "Teleport Round Trip"
Cohesion: 0.29
Nodes (7): ArrivalService, MatchArrival, MatchLauncher, ReturnToLobbyService, Lobby/MatchLauncher.luau, ReturnToLobbyService.handleInitFailed, TeleportInitFailed handler

### Community 74 - "Monster Agent & Stats"
Cohesion: 0.43
Nodes (5): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), MonsterService.Restage()

### Community 75 - "Death Service"
Cohesion: 0.48
Nodes (5): MatchStates.RespawnsOnDeath(), bindCharacter(), DeathService.Start(), onCharacterAdded(), onHumanoidDied()

### Community 76 - "Reward Seams & Persistence"
Cohesion: 0.29
Nodes (7): Reward/CaptureTargets.luau, Tools/CheckXpMigration.luau, Defaults are for display, never persistence, RewardModifiers (empty registry seam), RewardService, RewardStore.luau, RewardStore_v1 legacy read sunset condition

### Community 77 - "Studio vs Live Gotchas"
Cohesion: 0.38
Nodes (7): G10 — ReserveServer/TeleportAsync 403 in Studio, G3 — execute_luau require-cache isolation, LaunchGate, MatchLauncher, Lobby/PartyService.luau, Shared/QueueResultCodes.luau, QueueService.luau

### Community 78 - "Monster Agent & Stats"
Cohesion: 0.43
Nodes (5): MonsterStats.Get(), MonsterAgent.New(), MonsterAgent.SetState(), MonsterAgent.Tick(), MonsterService.Restage()

### Community 79 - "Death Service"
Cohesion: 0.48
Nodes (5): MatchStates.RespawnsOnDeath(), bindCharacter(), DeathService.Start(), onCharacterAdded(), onHumanoidDied()

### Community 80 - "Return To Lobby"
Cohesion: 0.52
Nodes (6): attemptReturn(), buildTeleportData(), handleInitFailed(), handleReturnRequest(), ReturnToLobbyService.ReturnAll(), ReturnToLobbyService.Start()

### Community 81 - "Cash Pickup & Wallet"
Cohesion: 0.48
Nodes (5): Cash.Collect(), CashWallet.Add(), CashWallet.Get(), CashWallet.Has(), findCash()

### Community 82 - "Match Result Builder"
Cohesion: 0.40
Nodes (5): MatchManager.GetElapsed(), MatchParticipants.All(), buildPerPlayer(), MatchResultBuilder.Build(), MatchResultBuilder.Start()

### Community 83 - "Match Time Replicator"
Cohesion: 0.53
Nodes (5): clear(), ensureMatchInfoFolder(), MatchTimeReplicator.Start(), publish(), MatchTimeService.GetAnchors()

### Community 84 - "Pickup Claim Race Safety"
Cohesion: 0.33
Nodes (6): Player/CashWallet.luau, EndGame, KitLifecycleHook, Claim-before-yield race safety (no lock object), PickupService, Teleport lock (teleporting set)

### Community 85 - "Movement Authority"
Cohesion: 0.33
Nodes (6): GameService/Player/CharacterMovementService.luau, G14 — client Humanoid writes don't replicate, LobbyBoot, One simulator per value, Server-owned movement authority, WalkSpeed budget with BUDGET_HEADROOM

### Community 86 - "Match Time Authority"
Cohesion: 0.40
Nodes (6): Countdowns cross the wire as a deadline, MatchClock, MatchTime/MatchSchedule.luau, Match time — single authority on match length, MatchTimeEvents, MatchTimeReplicator

### Community 87 - "Match Time Replicator"
Cohesion: 0.53
Nodes (5): clear(), ensureMatchInfoFolder(), MatchTimeReplicator.Start(), publish(), MatchTimeService.GetAnchors()

### Community 88 - "Launch Gate Timing"
Cohesion: 0.33
Nodes (6): LaunchGate.OnLaunched, LaunchGate.Rollback (removed in Phase 12), OnLaunched fires on request-accepted, not arrival, RewardLaunchHook, RewardLedger.SetupPlayer, RewardStore.Reacquire

### Community 89 - "Match Arrival"
Cohesion: 0.50
Nodes (3): MatchArrival.Start(), seedFrom(), MatchParticipants.Seed()

### Community 90 - "Match Time Lighting"
Cohesion: 0.60
Nodes (3): captureAuthored(), MatchTimeLighting.Start(), onPhaseOrTick()

### Community 91 - "Touch & Orientation Gotchas"
Cohesion: 0.40
Nodes (5): CameraTouchHud, G19 — PlayerGui.ScreenOrientation startup race, G6 — TouchEnabled/KeyboardEnabled gate is wrong, ScreenOrientationController.local.luau, Shared/TouchSession.IsActive()

### Community 92 - "Sunrise Ending Order"
Cohesion: 0.40
Nodes (5): DeathService, MatchEndCondition, MatchReplicator, MatchStates, Sunrise ending ordering (RequestEnd before Health=0)

### Community 93 - "Queue Pad Identity"
Cohesion: 0.40
Nodes (5): Identity by attribute, never by .Name, QueuePadDisplay.luau, Queue/QueuePadLabels.luau, QueuePadService, QueuePadSize lives on the pad's Zone part

### Community 94 - "Match Arrival"
Cohesion: 0.50
Nodes (3): MatchArrival.Start(), seedFrom(), MatchParticipants.Seed()

### Community 95 - "Match Time Lighting"
Cohesion: 0.60
Nodes (3): captureAuthored(), MatchTimeLighting.Start(), onPhaseOrTick()

### Community 96 - "Photo Scoring"
Cohesion: 0.40
Nodes (5): CameraStability, Distance score bands (100/60/30/10), Behavior.OnPhotographed, PhotoScoring module, ShotTypeMultiplier

### Community 97 - "Camera Tool Watcher"
Cohesion: 0.83
Nodes (3): onCharacterAdded(), tryInit(), watchContainer()

### Community 98 - "Photo Capture Distance"
Cohesion: 0.67
Nodes (4): Known bias: distance measured to hit point, PhotoCapture.luau, Shared/Units, Known bias: distance measured to hit point

### Community 99 - "Boot Entry Points"
Cohesion: 0.67
Nodes (3): GameBoot, LobbyBoot, ServerRole

### Community 104 - "Continuous Hour Scale"
Cohesion: 0.67
Nodes (3): Continuous hour scale past 24, MatchTimeLighting, MatchTimeMath.FormatHour

### Community 109 - "Cleanup Timeout Ordering"
Cohesion: 0.67
Nodes (3): RewardCleanupHook, RewardStore.SAVE_CONFIRM_TIMEOUT_SECONDS, MatchCleanup.STEP_TIMEOUT_SECONDS

## Ambiguous Edges - Review These
- `G12 — Spectate uses CameraType.Custom, not Scriptable` → `CameraInventory`  [AMBIGUOUS]
  MAINHANDOFF.md · relation: conceptually_related_to

## Knowledge Gaps
- **74 isolated node(s):** `MonsterSensing`, `MonsterMovement`, `MonsterDamage`, `MonsterAggression`, `States/Wandering` (+69 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `G12 — Spectate uses CameraType.Custom, not Scriptable` and `CameraInventory`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `ServerRole.AssertGameServer()` connect `Server Role & Arrival` to `Capture Rules & Targets`, `Pickup Types & Signals`, `Match State Enum`, `Match Launcher`, `Player State Enum`, `Match Result Builder`, `Spectate Service`, `Match Arrival`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `onPromptTriggered()` connect `Pickup Types & Signals` to `Player State Enum`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Are the 17 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `MatchArrival.Start()` and `MatchCleanup.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 17 inferred relationships involving `ServerRole.AssertGameServer()` (e.g. with `MatchArrival.Start()` and `MatchCleanup.Start()`) actually correct?**
  _`ServerRole.AssertGameServer()` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 14 inferred relationships involving `CameraSession.Enter()` (e.g. with `CameraEffects.Apply()` and `CameraEffects.Clear()`) actually correct?**
  _`CameraSession.Enter()` has 14 INFERRED edges - model-reasoned connections that need verification._