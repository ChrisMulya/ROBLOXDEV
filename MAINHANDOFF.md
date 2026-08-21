# MAINHANDOFF — current state

Agent-facing. Current phase only, no history. Git has the changelog.
Module behavior lives in the code and `graphify-out/GRAPH_REPORT.md` — not here.
Per-system design detail lives in `plans/` — not here.

## Phase

Two published places in one universe, live-syncing to disk independently:
`Lobby/` (Lobby server) and `Map0_Test/` (reserved Game server, teleported to
via matchmaking). One source tree, duplicated on disk, branching at runtime on
`ReplicatedStorage/Modules/Shared/ServerRole.luau` (resolved from `game.PlaceId`,
no setter by design).

**The two trees are meant to be byte-identical on every shared path** — verify
with `diff -rq Lobby Map0_Test`. There is no Rojo project file and no automated
drift check beyond that diff. **This invariant is currently VIOLATED** — see
Known broken.

What works end to end: move → buy camera → photograph monsters/objectives →
earn XP/Score → queue on a lobby pad → teleport into a reserved match server →
match runs a 6 PM → 6 AM night on a configurable schedule → sunrise kills whoever
is left and ends the match → return to Lobby with XP persisted. Loadout (camera
choice) survives both a teleport and a plain rejoin. Reward persistence is on
ProfileStore with a real per-session lock.

**Committed but not verified live this session** on top of that baseline: the
formal Match layer (`GameService/Match/*`) with a timed `Loading` phase and
client curtain, a shared Mission List HUD, a Monster investigation/search
overhaul (`Investigation`, `VisualScan`, `PointSelector`), a capture-target
registry feeding a cone-based `PhotoCapture` rewrite, a Document pickup, the
match-time announcer, and responsive-HUD scaling. All of these are committed
at HEAD (confirmed via `git status` — do not re-label them "uncommitted"
without re-checking); "not verified" means nobody has confirmed them working
end to end in a real playtest recently, not that the code is missing.

**Genuinely uncommitted right now:** the Lobby reduction (below) and its
follow-up remediation phases (monster-behaviour fixes, rate limiting, Lobby
rejoin correctness, capture-origin containment, this doc pass). See
`git status` for the exact file list and `plans/` for specs — read the diff
before touching any of it.

### Lobby scope (reduced)

The Lobby ships **only**: the camera shelf, an XP/Score leaderboard, the queue
system, and movement. Everything else is hard-gated off it.

Removal is **runtime role-gating, not deletion** — files stay on disk so the two
trees can stay identical. Two gate forms:

- Boot-list services → `ServerRole.AssertGameServer()` at the top of `Start()`.
- Self-wiring `.legacy.luau` Scripts and `StarterPlayerScripts` LocalScripts →
  `if not ServerRole.Is("GameServer") then return end` after the requires.

Notable consequences:

- **Scoring fails closed off the Game Server.** `RewardService.isScoringActive()`
  and `MonsterService.monstersCanSpawn()` used to return `true` on the Lobby (the
  old "content-migration gap"), so Lobby photos banked real persisted XP. Both now
  return `false`. `CameraShotHandler.legacy.luau` is role-gated and does not even
  wire its remotes on the Lobby.
- **The camera shelf is preference-only on the Lobby, by construction.**
  `GivePlayerStarterKit` is called only by `KitLifecycleHook` (GameServer-asserted),
  so no Lobby player has a `Camera` slot; `CameraShelfSwap.TakeCamera` takes the
  `PreferenceSaved` branch, writing the `CurrentCamera` attribute and
  `LoadoutService.Save`. The Game place reads it back at kit grant. Do not "fix" this.
- **Stamina does not exist on the Lobby; sprint is free.**
  `CharacterMovementService` stays booted on both places because it is the server's
  WalkSpeed authority (see G14) — it carries an `isLobby` flag that skips the
  stamina gate, the drain/regen loop, and the `StaminaSync` remote.
- **The Lobby leaderboard is Roblox's native PlayerList.** `RewardLedger` already
  builds `leaderstats` on both places; `CoreGuiController` simply stops disabling
  `PlayerList` on the Lobby. No custom UI.

## Place split — what runs where

Everything in `StarterPlayerScripts/` is copied to every client on **both**
places by the engine; role-gating is what actually decides scope.

| | Lobby | Game |
|---|---|---|
| Server boot list | `Boot/LobbyBoot.luau` (13 services) | `Boot/GameBoot.luau` (~60) |
| Client boot | `ClientBootstrap.local.luau` `LobbyServer` branch | same file, `GameServer` branch |
| Camera **shelf** | yes (preference-only) | yes |
| Camera **session** (aim/viewfinder/capture) | no | yes |
| Photo scoring | no (fails closed) | yes, during `Playing` |
| Stamina | no (free sprint) | yes |
| Flashlight | no | yes |
| Items / shop / pickups | no | yes |
| Monsters / objectives / missions | no | yes |
| Queue pads / matchmaking | yes | no |
| Native PlayerList (leaderboard) | **enabled** | disabled |
| `leaderstats` (XP/Score/Cash) | yes | yes |
| Loading curtain | built, then cleared immediately | full staged sequence |

Always-on regardless of place: `Remotes.Init()`, `PlayerCurrency.legacy.luau`
(`RewardLedger.SetupPlayer` + `LoadoutService.Load` + Cash), `PlayerStateService`,
`CameraSessionTracker`, `CharacterMovementService`, `ScreenOrientationController`,
`CoreGuiController`, `ReplicatedFirst/LoadingCurtain.local.luau`.

**Loading curtain contract.** `ReplicatedFirst/LoadingCurtain.local.luau` builds an
opaque full-screen `LoadingCurtainGui` on both places and **has no self-hide path** —
it requires nothing so it can run before `ReplicatedStorage.Modules` replicates.
The only thing that ever hides it is `LoadingController`, which must therefore be
required in **both** branches of `ClientBootstrap`. Its `LobbyServer` path waits for
the curtain by name, then `LoadingHud.HideInstant()`. If the Lobby ever shows a
permanent black screen again, that require is the first thing to check.

## Architecture invariants

Rules that outlive any single file. Violating one is a bug even if it works.

- **Config in data tables, not logic.** `CameraStats`, `MonsterStats`, `RewardTypes`, `CaptureTargets`, `ObjectiveTypes`, `MatchConfig`. Adding a camera/monster/reward/target/mode = one table row, no new script.
- **Enum as data.** States are rows with flags (`ObjectiveStates`, `MatchStates`, `PlayerStates`). Never branch on a state *name*; read its flag. Predicates fail closed on unknown states.
- **Role gates fail closed.** Anything that pays out, spawns, or grants must require `ServerRole.Is("GameServer")` explicitly, never treat "not a Game Server" as permissive. This class of bug shipped once already.
- **Replication split.** Shared state → Instance attribute (auto-replicates). Per-player state → RemoteEvent + snapshot on join/`CharacterAdded`. Attributes cannot express per-player values.
- **RemoteEvents only.** Zero RemoteFunctions in the repo. Client fires a request; server replies on a separate `*Result`/`*Feedback` remote with a **code string**; a shared `*ResultCodes` module maps code → message.
- **All remotes registered** in `Remotes.ALL_NAMES`; `Remotes.Init()` provisions them (server, from `Bootstrap.legacy.luau`). Never `WaitForChild` a remote by hand. Both places register the full list even where only one connects, so the diff stays a clean machine check.
- **Ownership is symmetric.** Whoever acquires a GUI/effect/connection releases it, by reference, via a `Trove` — never by name lookup.
- **Freezing player input goes through `Shared/ControlLock`**, never a bare `PlayerModule.Controls:Disable()/Enable()`. The raw switch is shared and unrefcounted — two independent freeze reasons stomp each other.
- **No reward amount ever crosses a remote.** `RewardService` is the only sink.
- **Server reads attributes off the server-observed instance**, never client-declared identity.
- **Countdowns cross the wire as a deadline, never a remaining duration** — a `workspace:GetServerTimeNow()` timestamp the client subtracts locally. Corollary: **one owner computes the deadline, everyone else reads it** (`MatchClock.GetEndingDeadline()` anchors on first request precisely so the receipt countdown and the real transition can't disagree).
- **One simulator per value.** If the server owns a number, the client renders it — never run the same rule in parallel "for smoothness". Stamina was simulated on both sides; the moment they disagreed the sync stomped the client every tick and the HUD looked frozen.
- **Defaults are for display, never persistence.** If you can't distinguish "no data" from "couldn't read data", do not write.
- **Identity by attribute, never by `.Name`.** A rename or a `"Camera"` collision must not change behavior.
- **Match time runs on a continuous hour scale past 24** (6 AM is `30`, midnight is `24`). Every comparison is plain arithmetic on that scale; the only legal `% 24` are `MatchTimeMath.FormatHour` (display) and `MatchTimeLighting` (`ClockTime` is a 0-24 engine property). A wrap anywhere else reintroduces midnight-crossing bugs.
- **`MatchConfig.MatchDuration` does not exist.** How long `Playing` lasts is the schedule's total (`MatchTime/MatchSchedule.luau`) and nothing else. The clock is match-scoped: `GetHour`/`GetPhase`/`GetProgress` return **nil** outside `Playing`, and that nil is the contract — consumers handle "no match time right now" rather than defaulting to a number.
- No `--!strict`. No circular dependencies (graph currently reports **zero** import cycles — protect that).

## Systems

| System | Status | Notes |
|---|---|---|
| Movement / FOV / camera tilt | works | client `LinearVelocity`, asymmetric smoothing; speed budget is server-set (`CharacterMovementService`, both places) — see G14 |
| Sprint / stamina / jump cooldown | works | server-authoritative; client renders, never simulates. Lobby runs the same service in free-sprint mode (no stamina) |
| Stamina HUD / mobile sprint button | works | **Game place only** — both role-gated off the Lobby. `StarterPlayerScripts`, not `StarterGui` (G1) |
| Per-player stat buffs | works | `Player/PlayerEffects` — additive deltas against the `PlayerStats` base, independently timed, never captured/restored absolutes. Every reader of `WalkSpeed`/`SprintSpeed`/`MaxStamina` goes through `PlayerEffects.GetStat`, both sides |
| Lobby leaderboard | works | native PlayerList + `leaderstats` (XP persistent, Score `ResetOnRunEnd`, Cash). Lobby only |
| Inventory slots + shop | works | Game place only; `ShopCatalog` drives price/description/UI; server-authoritative buy through `CashWallet` |
| Support item gameplay | committed, unverified | Generic 3s hold-to-use (`Item/ItemUseService`); needs `Assets.Tool.SupportItem.*` authored in Studio |
| Flashlight | works | **Game place only** — `FlashlightService.Start()` asserts GameServer and is in `GameBoot` only; all three client scripts role-gated |
| Camera shelf | works | both places; preference-only on the Lobby — see Lobby scope |
| Camera session / viewfinder / touch HUD | works | Game place only; one `Trove` per session |
| Photo capture → reward | works | Game place only, `Playing` only. `CaptureTargets.Resolve` → `RewardService` |
| XP persistence | works | ProfileStore (`RewardStore_v2`), real session lock. `RewardStore_v1` is a legacy read path only — see Tracked sunset |
| Loadout persistence | works | camera choice survives teleport and rejoin; refuses `TeleportData` by design |
| Match time / sunrise ending | works | Game place only. Sunrise fires `RequestEnd("Sunrise")` **first**, then `Health = 0` on survivors with no yield between — those deaths land while state is already `Ending`, where `MatchStates.RespawnsOnDeath` is false |
| Match time HUD | works | client renders from replicated anchors; never simulates |
| Monsters | works | Game place only. Capability-driven components (`Monster/`); `Monster1` only. Effective stage is `max(spawnPoint.Stage, phase.MonsterStage)` — authored stage is a floor |
| Objectives | works | Game place only; registry/service/replicator + client visuals |
| Flash | works | Game place only; client `FlashSignal` → screen + world-light renderers |
| Pickup / Cash collection | works | Game place only (prompt, grant, **and** visuals); hand-placed, no spawner yet |
| Spectate / death → kit teardown | works | `KitLifecycleHook` clears tools on death; `SpectateHud` hides Backpack CoreGui |
| Matchmaking (queue pads) | works | Lobby only. 5 Hz server-side zone polling; per-pad generation-guarded countdown; `LaunchGate` preconditions |
| Party | server-only | no client surface — see Half-built |
| Touch-device detection | works | `Shared/TouchSession.IsActive()` — the single answer, called never cached (G6) |
| Mobile landscape lock | works | `ScreenOrientationController.local.luau`, re-applied on change (G19) |
| Match layer (`GameService/Match/*`) | committed, unverified | Formal phased lifecycle replacing prior ad hoc glue |
| Match loading screen | committed, unverified | Timed `Loading` phase + curtain, gated on `MatchClientReady`/`LoadingTimeout` — see `plans/match-loading-screen.md` |
| Mission List HUD | committed, unverified | Shared match-scoped progress |
| Monster investigation/search overhaul | committed, unverified | Needs the same unplaced Patrol/Search points as Patrol |
| Photo capture (cone detection) | committed, unverified | Behind `USE_CONE_DETECTION`; old 5×5 grid path still reachable |
| Document pickup | committed, unverified | Match-scoped mission collectible, no currency |
| Match-time announcer | committed, unverified | Plan says "not implemented" but the files exist and are wired — verify against `plans/match-time-announcer.md` before trusting either claim |
| Responsive HUD scaling | implemented per plan, unverified | `UIScaleController` + holders — see `plans/responsive-hud.md` |

## Half-built / not wired

- **`RewardModifiers`** — registry exists, zero entries. The Combo/Streak/Event seam, unproven.
- **`MatchTimeEvents`** — registry + dispatcher exist and are exercised by the clock, zero registered entries. The seam for timed spawn waves / extraction windows.
- **`MatchPhases` flags beyond `MonsterStage`** — `MonstersAggressive` and `ExtractionOpen` are declared and read by nothing.
- **`Monster1` Stage 2 / Evolution numbers** — real and reachable, tuned by eye, not by playtest. See `Configs/Monster1.luau`; schema in `plans/EvolutionPlan.md`.
- **PatrolPoint/SearchPoint authoring** — `PatrolGraph` and `States/Patrol.luau` are complete; neither map has any points placed. Patrol falls back to `Wander`.
- **Party client surface** — `PartyService` exists and `QueueService` treats a party as one atomic queue unit, but there are no remotes, no UI, and nothing calls `Join`/`Leave`. So `IsLeader` is always `true` and three `QueueResultCodes` (`AlreadyQueued`, `PartyTooLarge`, `NotPartyLeader`) are unreachable — **do not delete them as dead code**, they activate the moment invites ship. Latent: `PlayerRemoving` does not fire `Changed`; harmless until something subscribes.
- **`SoundIds.luau`** — TODO stub.

## Known broken / deferred (accepted)

| Issue | Impact | Why deferred |
|---|---|---|
| **Mirror drift — `diff -rq Lobby Map0_Test` is not clean** | 15 files differ in content, 2 exist only in `Map0_Test/` (`Flash/FlashRenderers/FlashSoundRenderer.luau`, `StarterPlayerScripts/FirstPersonCrosshair.local.luau`). `Map0_Test/` holds real feature work never ported back: camera capture-lock + exposure watcher (`CameraSession`), scope-vs-sprint FOV precedence (`Playermovementcontroller`), receipt mouse handling (`MatchReceiptController`), plus `Camera/*`, `Flash/*`, `MatchTimeHud`, `ObjectiveVisualsController`, `ShopCatalog`, `MatchReceipt` | Needs a real per-file merge decision, not a guess-merge. Until it is resolved the byte-identical invariant is aspirational — **check the diff before assuming a shared path is shared** |
| `origin` is client-supplied | Spoofable shot origin | `CaptureGuard.ValidateShot` 10-stud proximity check is a mitigation; server-derived origin is a larger change |
| Camera-mode sprint block is client-side only | A modified client can sprint while scoped | The only server-side signal is `CameraSessionTracker`'s client-reported InCamera flag, which must never back a server-authoritative check. UX rule only; the WalkSpeed budget still caps absolute speed |
| `CoreGui...Settings.Pages.Players` errors in Studio | Console noise | Roblox's own code (Escape-menu Players tab, `layoutMuteAll`), not ours. We never toggle `PlayerList` on the Lobby, we just leave it at its default. Commonly trips in solo playtest |

## Tracked sunset conditions

- **`RewardStore_v1` legacy read** (`RewardStore.luau`: `legacyBackend`, `attemptLegacyRead`, the `RobloxMetaData.MigratedFromV1` block in `Load`). Every real player's XP was confirmed migrated to `v2` as of Phase 12.5 (`Tools/CheckXpMigration.luau`, `SWEEP_ALL_V1 = true`). New joins only need this path for an account that played before Phase 12 and has never rejoined. **Sunset:** once migration logging shows zero migrations across a full retention window (suggest 90 days from next check), delete all three. Re-run the sweep tool and confirm zero `STILL EXPOSED` accounts first.

## Environment & tooling gotchas

Non-derivable from code. These will burn a session if forgotten.

- **G1 — `StarterGui` LocalScripts re-run on every respawn.** They get re-copied per spawn, stacking duplicate GUIs and duplicate listeners. Put persistent UI in `StarterPlayerScripts` with `ResetOnSpawn = false`. `CoreGuiController` disables the default Health CoreGui on both places (it overlaps the stamina bar) and `PlayerList` on the Game place only.
- **G2 — Local files are live-synced with the open Studio session, both directions.** Never hand-edit a file *and* push the same content via a Studio tool call in one turn — it appends instead of replacing.
- **G3 — `execute_luau` runs in an isolated `require()` cache** from real Scripts/LocalScripts (plugin identity), on **both** Client and Server datamodels. A module's internal Lua state populated by a real script is invisible to it — looks exactly like a hung async call, with no error. Verify via shared Instances (properties/attributes/leaderstats) only. *Tell: a real script's background op "never completes" with zero errors → suspect isolation before a hang.*
- **G4 — Play datamodel clones from Edit at Play-start, and file sync is async.** Editing locally then immediately hitting Play can silently run the **old** code. Confirm the Edit datamodel has the new source before Play. *Tell: `script_grep` finds nothing for something you definitely just wrote.*
- **G5 — `execute_luau` is misleadingly permissive.** It has plugin capability; real Scripts don't. `Instance:GetDebugId()` passes every `execute_luau` check and errors the instant a real player hits it. **Always do one end-to-end pass firing the real remote from a Client context** before calling a feature done.
- **G6 — Studio reports `TouchEnabled` *and* `KeyboardEnabled` true — in Play Solo *and* under Test → Device emulation** (the developer's real keyboard keeps the latter true). A `TouchEnabled and not KeyboardEnabled` gate is therefore wrong: always wrong on a touchscreen laptop, and **nondeterministic under emulation** — measured, `KeyboardEnabled` can read false at module-load and true a moment later, so a gate cached at load flips between sessions with no code change. **Use `Shared/TouchSession.IsActive()`** — never hand-roll this, and never cache its result, since a phone preset selected after Play never reaches a script that already decided.
- **G7 — Studio API Services off** ⇒ every join lands in `RewardStore` state `Failed`: XP shows 0 and *nothing is written*. Real data stays intact. Not a bug.
- **G8 — `ServerScriptService` modules are unreachable from clients.** Shared code must live in `ReplicatedStorage`.
- **G9 — Roblox does not guarantee Script execution order.** `Bootstrap.legacy.luau` is a decoupling point, *not* an ordered bootstrap. Boot order for a place's services comes from the ordered list in its `Boot/*Boot.luau` `Start()`, not require order.
- **G10 — `ReserveServer`/`TeleportAsync` return HTTP 403 in Studio Play/Test, even against a published place.** DataStore calls **do** work in Studio Play with API Services on (G7) — don't conflate the two. Matchmaking's launch step can only be verified on a published two-place build.
- **G11 — `Signal:Fire` (the shared `BindableEvent` wrapper) is deferred.** A synchronous read of an attribute or state immediately after the `Set`/`Fire` that changed it sees the *previous* value. Needs a `task.wait()` between write and read when testing from the command bar.
- **G12 — Spectating is `CameraType.Custom` + `CameraSubject`, NOT `Scriptable`.** `Scriptable` means "no engine camera logic at all" — the engine stops writing `CFrame` and **ignores `CameraSubject` entirely**, so the camera freezes while the HUD happily names a target. `Custom` follows a subject. Its one cost: Roblox's camera scripts reassign `CameraSubject` to the local humanoid on respawn — re-assert rather than giving up engine camera control. Also `CameraSubject = nil` does not clear it (a free-camera fallback needs a real anchored Part), and **never cache `Workspace.CurrentCamera` at require time** — the engine replaces it on respawn/teleport.
- **G13 — `get_console_output` (Studio MCP) can return a stale buffer across a Play stop/restart.** Don't trust it as a liveness signal; re-read Instance-backed state fresh instead.
- **G14 — Client writes to Humanoid properties do not replicate, and live servers validate motion against the server's copy of `WalkSpeed`.** Anything moving a character faster than the server's `WalkSpeed` is rejected on a published build and rubber-bands. Studio does not run this validation at all, so **it looks perfect in Studio and fails live.** This is why `CharacterMovementService` is server-side and stays booted on both places. The budget is `walk-or-sprint × 1.15`; the headroom absorbs slopes, knockback and client accel-lerp overshoot and is too small to spend as a second sprint.
- **G15 — `UIBuilder.CreateScreenGui` returns ScreenGuis with `Enabled = false`.** Every caller opts in. Forgetting it renders nothing regardless of `Visible`, with no error — it looks exactly like the script never ran.
- **G16 — `TouchGui.TouchControlFrame.DynamicThumbstickFrame` is a ~420×322 region covering the whole bottom-left.** Any touch UI there must outrank `TouchGui` (`DisplayOrder` 0) — pick a value from the registry in `UIBuilder.CreateScreenGui`'s comment, never reuse one. `ThumbstickStart` is present and visible **even at rest**, so it cannot signal "is the player touching the stick" — use move-vector magnitude. It also stays wherever the last touch landed, so it is not a reliable home position after the first drag.
- **G17 — Stick *displacement* is only available from `ControlModule:GetMoveVector()`** (magnitude scales 0..1, capped at 1). `Humanoid.MoveDirection` is normalized — identical at a nudge and at full stretch.
- **G18 — MCP input automation lands in Studio-window coordinates, not the emulated viewport's.** Measured: a click sent at `x=66` arrived in-game at `x=19` (~47px X offset; Y matched). A synthetic tap that "does nothing" is usually missing the target — verify by logging `UserInputService.InputBegan` position first.
- **G19 — `PlayerGui.ScreenOrientation` written once at client start silently loses.** Measured: the write appears to succeed, then reads back as `Sensor` seconds later with no error — a StarterPlayerScripts LocalScript runs before the engine finishes seeding PlayerGui from StarterGui. A later write holds and survives respawn, so it is a startup race. Re-apply via `GetPropertyChangedSignal("ScreenOrientation")`. Setting `StarterGui.ScreenOrientation` does **not** update an existing PlayerGui.
- **G20 — Roblox does not guarantee the order of multiple handlers connected to one event.** G9 is about Script execution; this is `Connect` order on a single signal, and it is *not* reliable registration order. Measured: a listener connected *after* `MatchClock`'s read `GetEndingDeadline()` in the same `StateChanged` batch and got `nil`. **Never let one handler depend on another handler of the same event having already run.** Fixes that work: compute-on-first-request, or publish a distinct signal (`MatchTimeService.Started`/`Stopped` exist for this). A value fired deferred *from inside* a handler does resolve in a later batch.
- **G21 — `guardNonReservedServer()` stops the whole Game-place boot in Studio** (`game.PrivateServerId == ""`), so `GameBoot`'s ordered list never runs and no match starts. To exercise the real boot list in Studio, temporarily comment the `if guardNonReservedServer() then return end` block and point `MatchConfig.Modes.Default.ScheduleId` at `"Debug"` — **then revert both**; grep for leftover markers before committing.

## Reference tables

**File suffix → Roblox class:** `Foo.luau` = ModuleScript · `Foo.local.luau` = LocalScript · `Foo.legacy.luau` = server `Script` (RunContext Legacy) · `init.luau` = folder-as-module.
`.legacy.luau` files are **live and running**, not dead code.

**Folder → service:** `<Place>/<Service>/` maps 1:1 to Roblox services. No Rojo project file; both places live-sync via disk.

| Attribute | On | Meaning |
|---|---|---|
| `IsCameraTool` / `CameraId` | Tool | Camera identity. **Never use `Tool.Name`** — overwritten to `"Camera"` at purchase/swap |
| `IsMonster` / `IsObjective` | Model or Part | Capture targets. Owned by `Reward/CaptureTargets.luau`; never hardcode elsewhere |
| `ObjectiveType` / `ObjectiveState` | Objective instance | Type registry key / shared state |
| `IsEmpty` | Tool | Placeholder slot — `IsA("Tool")` alone can't tell empty from filled |
| `IsCameraShelf` | Part | Shelf identity (not `part.Name`) |
| `KeepDuringCamera` | ScreenGui | Exempt from `CameraSession.hideOtherGuis`. Roblox's `TouchGui` is exempted by name separately — hiding it breaks camera look on touch |
| `KitGiven` | Player | Server-only. Set **last**, after the grant succeeds |
| `CurrentCamera` | Player | Server-set by `CameraInventory`. **Never write from client** |
| `Stamina` / `Sprinting` | Player | Server-written by `CharacterMovementService`, observability only. Nothing reads them — the HUD goes through `StaminaSync`. Not written on the Lobby |
| `QueuePadSize` | the pad's `Zone` Part | Queue pad capacity (1/2/4). Owned by `QueuePadService` |
| `QueuePadLabel` | a Part inside the pad model | Marks which descendant carries the display `BillboardGui`/`TextLabel` |
| `QueuePadCount` / `QueuePadCapacity` / `QueuePadEndsAt` | the pad's `Zone` Part | Server-written display state. `QueuePadEndsAt` is `0` when idle, else a `GetServerTimeNow()` deadline |
| `MatchState` | `ReplicatedStorage.MatchInfo` Folder | Current `MatchStates` name. Written by `MatchReplicator` |
| `LoadingReadyCount` / `LoadingReadyTotal` | same Folder | `MatchLoadingGate`'s ready ledger. **Nil outside `Loading`** |
| `MatchScheduleId`, `MatchTimeStartedAt`, `MatchTimeEndsAt`, `MatchTimeAnchorAt`, `MatchTimeAnchorHour` | same Folder | Match clock anchors, written by `MatchTimeReplicator`. **All nil outside `Playing`** — absent must read as "no match time", never hour 0 |
| `IsMonsterSpawn` | Part or Model, Workspace | Hand-placed spawn point. Optional `MonsterId` (default `Monster1`) and `Stage` (default 1) |
| `MonsterId` / `Stage` | spawned monster Model | `Stage` here is the **effective** stage, rewritten on every re-stage — the authored floor lives on the spawn point |
| `EvolutionTier` / `AIState` / `AggressionLevel` | spawned monster Model | Replicated for client reads; `AggressionLevel` is a quantised band (`Low`/`Medium`/`High`), not the raw scalar |
| `IsPatrolPoint` / `IsSearchPoint` | invisible Part, Workspace | Patrol network node / secondary investigation spot. Optional `MonsterId`. **None placed yet** |
| `IsPickup` / `PickupType` | Model or Part, Workspace | Pickup identity. Owned by `Pickup/PickupTypes.luau` |
| `PickupAmount` | same instance | Optional per-instance override of a Cash pickup's `Params.Amount` |

**ScreenGui DisplayOrder registry.** `ReplicatedStorage/Modules/UI/UIBuilder.luau`'s
comment on `UIBuilder.CreateScreenGui` **is** the registry — there is no runtime
table, and no copy of it belongs here. A duplicate list drifts (it already had:
missing `HudLeftGui`, `ExitCountdownGui`, `ShopGui`, `PurchaseNotificationGui`),
which is an active collision hazard for a registry whose whole point is "pick a
gap, never an existing value." Read `UIBuilder.luau` directly.

**Asset paths** (tree structure differs — don't assume parity):
- `ReplicatedStorage.Assets.Tool.SupportItem`
- `...SupportItem.ItemRemotes.{CompactSpeakerRemotes, PortableCCTVTablet}` — **post-use replacement tools, not shop stock.** The shop grants the plain Tool; using it places the world object and swaps the held Tool for the matching one here (`ShopCatalog.ReplaceWith`). Both have `Enabled = false` catalog rows so they resolve an asset but can never be bought
- `...SupportItem.PlacedItem.{PlacedMotionSensor, PlacedCompactSpeaker, PlacedPortableCCTV}` — `PlacedPortableCCTV` needs a child Part named `Lens` (falls back to `PrimaryPart`). Missing asset degrades to a `"Failed"` ItemUseResult, no hard error
- `ReplicatedStorage.Assets.Tool.Camera.Camera1`
- `ReplicatedStorage.Assets.Pickup.Cash` — Studio-authored, Anchored, `PrimaryPart` set if a Model
- `ReplicatedStorage.Sounds.Tool.FlashLightSound`
- `ReplicatedStorage.Sounds.Tool.CompactSpeakerSound` — cloned onto the placed speaker, looped for the active window. Missing clip = a silent but functional lure (warn only)

**Security boundary:** `CameraSessionTracker`'s InCamera flag is client-reported — UX guard only, never a security check.
