# MAINHANDOFF — current state

Agent-facing. Current phase only, no history. Git has the changelog.
Module behavior lives in the code and `graphify-out/GRAPH_REPORT.md` — not here.

## Phase

Two published places, live-syncing to disk independently: `Lobby/` (Lobby
server) and `Map0_Test/` (reserved Game server, teleported to via
matchmaking). Both trees are kept **byte-identical on every shared path** —
verify with `diff -rq Lobby Map0_Test` after any cross-cutting change; there
is no Rojo project file and no automated drift check beyond that diff.

What exists and works end to end: move → buy camera → photograph
monsters/objectives → earn XP/Score → queue on a lobby pad → teleport into a
reserved match server → match runs to completion → return to Lobby with XP
persisted. Loadout (camera choice) survives both a teleport and a plain
rejoin. Reward persistence is on ProfileStore with a real per-session lock.

**Known-broken and half-built items are their own sections below** — this
paragraph is the only narrative allowed in this file. For how any of this was
built, or what it used to be, see `git log`.

### Queue pads (lobby matchmaking entry point)

One queue **per physical lobby pad** (`Workspace.Queue1/2/4`), not a global
queue. A player enters by standing on a pad — sensed server-side from
character position by `QueuePadService`, polled at ~5 Hz against each pad's
`Zone` part volume. There is **no client-initiated queue request** and
nothing to rate-limit: a client cannot assert that it is queued, only stand
somewhere.

- **Pad capacity is a roster cap, not a requirement.** 2 players standing on
  the 4-capacity pad launch a 2-player match.
- **Countdown starts when the first unit enters an empty pad**, does not
  reset when more players join, and cancels only when the pad empties
  (`QueueService.luau`'s `arm`/`disarm`).
- **The `QueuePadSize` attribute lives on the pad's `Zone` part, not the
  Model.** A Model bounding box would swallow the floating `DisplayLabel`
  above the pad and make the trigger volume several times taller than the
  area a player can see they're standing in.
- **Teleport lock.** A launched roster is still physically standing on the
  pad while `TeleportAsync` is in flight; `QueueService` holds a `teleporting`
  set so the sensor's retry path doesn't re-admit them and arm a phantom
  countdown. Released via `LaunchGate.RegisterOnLaunchAborted` if the launch
  is ultimately abandoned.
- **Display is attribute-driven, not remoted.** `QueuePadService` writes
  `QueuePadCount` / `QueuePadCapacity` / `QueuePadEndsAt` onto each pad
  instance; every player sees every pad's state via
  `QueuePadDisplay.luau`, whether queued or not. `QueueResult` is the only
  remaining queue remote — one-player-directed result messages only.
- Display strings live in `Queue/QueuePadLabels.luau`; queue/launch result
  codes live in `Shared/QueueResultCodes.luau` (covers both pad rejections and
  `MatchLauncher`'s launch-failure reasons — one codes module, one remote).

### Party system — server-only, inert by design

`Lobby/PartyService.luau` exists (`GetLeader`/`IsLeader`/`GetParty`/`Join`/
`Leave`/`Changed`) and `QueueService` already treats a party as one atomic
queue unit. But it has **no client surface at all** — no remotes, no UI, no
boot-wired controller — and nothing anywhere calls `Join`/`Leave`. Consequence:
`PartyService.IsLeader` is always `true`, `GetParty` always returns a single
player, and three codes in `QueueResultCodes` (`AlreadyQueued`,
`PartyTooLarge`, `NotPartyLeader`) are intentionally unreachable until a party
client surface ships. Do not delete them as dead code — they activate with no
further change the moment invites exist.

Latent bug, harmless today: `PartyService`'s `PlayerRemoving` path does not
fire `Changed`, unlike `Join`/`Leave`. No current subscriber, so nothing
breaks — but the first thing that subscribes to `Changed` will see it.

## Architecture invariants

Rules that outlive any single file. Violating one is a bug even if it works.

- **Config in data tables, not logic.** `CameraStats`, `MonsterStats`, `RewardTypes`, `CaptureTargets`, `ObjectiveTypes`, `MatchConfig`. Adding a camera/monster/reward/target/mode = one table row, no new script.
- **Enum as data.** States are rows with flags (`ObjectiveStates`, `MatchStates`, `PlayerStates`). Never branch on a state *name*; read its flag. Predicates fail closed on unknown states.
- **Replication split.** Shared state → Instance attribute (auto-replicates). Per-player state → RemoteEvent + snapshot on join/`CharacterAdded`. Attributes cannot express per-player values.
- **RemoteEvents only.** Zero RemoteFunctions in the repo. Client fires a request; server replies on a separate `*Result`/`*Feedback` remote with a **code string**; a shared `*ResultCodes` module maps code → message. Some flows (queue pads) have no client-initiated request at all — server-sensed state replicates via attributes instead, and the remote exists only for one-off result messages.
- **All remotes registered** in `Remotes.ALL_NAMES`; `Remotes.Init()` provisions them (server, from `Bootstrap.legacy.luau`). Never `WaitForChild` a remote by hand.
- **Ownership is symmetric.** Whoever acquires a GUI/effect/connection releases it, by reference, via a `Trove` — never by name lookup.
- **No reward amount ever crosses a remote.** `RewardService` is the only sink.
- **Server reads attributes off the server-observed instance**, never client-declared identity.
- **Defaults are for display, never persistence.** If you can't distinguish "no data" from "couldn't read data", do not write.
- **Identity by attribute, never by `.Name`.** `IsMonster`/`IsObjective`/`QueuePadSize`/etc. — a rename or a "Camera" collision must not change behavior.
- No `--!strict`. No circular dependencies (graph currently reports **zero** import cycles — protect that).

## Systems

| System | Status | Notes |
|---|---|---|
| Movement / stamina / FOV / camera tilt | works | `LinearVelocity`, asymmetric smoothing |
| HUD (stamina) | works | `StarterPlayerScripts`, **not** `StarterGui` — see G1 |
| Inventory slots + shop | works | server-authoritative buy; empty slots tagged `IsEmpty` |
| Currency UI | works | remote-driven |
| Camera framework | works | client session/viewfinder/touch HUD + shelf; one `Trove` per session |
| Photo capture → reward | works | 5×5 spread raycast → `CaptureTargets.Resolve` → `RewardService` |
| XP persistence | works | ProfileStore (`RewardStore_v2`), real session lock. `RewardStore_v1` is a legacy read path only — see Tracked sunset conditions |
| Monsters | works | `Monster/EncounterDirector.luau` gives `MonsterService.Spawn` a real caller |
| Objectives | works | registry/service/replicator + client visuals |
| Flash | works | client `FlashSignal` → screen + world-light renderers; server `FlashEvents` has a publisher, still zero subscribers |
| Matchmaking (queue pads) | works | see Phase section above |
| Party | server-only | see Phase section above — no client surface |
| Loadout persistence | works | camera choice survives teleport and rejoin |

## Half-built / not wired

- **`RewardModifiers`** — registry exists, zero entries. The Combo/Streak/Event seam, unproven.
- **`FlashEvents`** (server) — has a publisher (`CameraShotHandler.legacy.luau`), zero subscribers. Reserved for monster perception.
- **`SoundIds.luau`** — TODO stub.
- **Party client surface** — see Phase section above.

## Known broken / deferred (accepted)

| Issue | Impact | Why deferred |
|---|---|---|
| `origin` is client-supplied | Spoofable shot origin | `CaptureGuard.ValidateShot` 10-stud proximity check is a mitigation; server-derived origin is a larger change |

## Tracked sunset conditions

Decisions waiting on data, not files nobody dares touch.

- **`RewardStore_v1` legacy read (`RewardStore.luau`: `legacyBackend`, `attemptLegacyRead`, the `RobloxMetaData.MigratedFromV1` migration block in `Load`).** Temporary by design — every real player's XP was confirmed migrated to `RewardStore_v2` as of Phase 12.5 (swept via `Tools/CheckXpMigration.luau`, `SWEEP_ALL_V1 = true`). New joins only need this path if an account played before Phase 12 and has never joined since. **Sunset condition:** once `RewardStoreDiagnostics`/`RewardStore.Load`'s own migration logging shows zero migrations across a full retention window (suggest: 90 days from whenever this is next checked), delete `legacyBackend`, `attemptLegacyRead`, and the migration block in `Load`. Re-run the sweep tool first to confirm zero `STILL EXPOSED` accounts before deleting.

## Environment & tooling gotchas

Non-derivable from code. These will burn a session if forgotten.

- **G1 — `StarterGui` LocalScripts re-run on every respawn.** They get re-copied per spawn, stacking duplicate GUIs and duplicate listeners. Put persistent UI in `StarterPlayerScripts` with `ResetOnSpawn = false`. `CoreGuiController` also disables the default Health CoreGui (overlaps the stamina bar).
- **G2 — Local files are live-synced with the open Studio session, both directions.** Never hand-edit a file *and* push the same content via a Studio tool call in one turn — it appends instead of replacing.
- **G3 — `execute_luau` runs in an isolated `require()` cache** from real Scripts/LocalScripts (plugin identity), on **both** Client and Server datamodels. A module's internal Lua state (tables, closures) populated by a real script is invisible to it — looks exactly like a hung async call, with no error. Verify via shared Instances (properties/attributes/leaderstats) only. *Tell: a real script's background op "never completes" with zero errors → suspect isolation before a hang.*
- **G4 — Play datamodel clones from Edit at Play-start, and file sync is async.** Editing locally then immediately hitting Play can silently run the **old** code. Confirm the Edit datamodel has the new source before Play. *Tell: `script_grep` finds nothing for something you definitely just wrote.*
- **G5 — `execute_luau` is misleadingly permissive.** It has plugin capability; real Scripts don't. `Instance:GetDebugId()` passes every `execute_luau` check and errors the instant a real player hits it. **Always do one end-to-end pass firing the real remote from a Client context** before calling a feature done.
- **G6 — Studio "Play Solo" reports `TouchEnabled` *and* `KeyboardEnabled` true.** Any `TouchEnabled and not KeyboardEnabled` gate (`CameraTouchHud`) stays hidden there. Use **Test → Device** emulation to see touch-only UI.
- **G7 — Studio API Services off** ⇒ every join lands in `RewardStore` state `Failed`: XP shows 0 and *nothing is written*. Real data stays intact. Not a bug.
- **G8 — `ServerScriptService` modules are unreachable from clients.** Shared code must live in `ReplicatedStorage`.
- **G9 — Roblox does not guarantee Script execution order.** `Bootstrap.legacy.luau` is a decoupling point, *not* an ordered bootstrap. Boot order for a place's services comes from the ordered list in its `Boot/*Boot.luau` `Start()` call, not require order.
- **G10 — `ReserveServer`/`TeleportAsync` return HTTP 403 in Studio Play/Test, even against a published place.** `GetAsync`/`SetAsync` and other DataStore calls **do** work in Studio Play with API Services on (see G7) — don't conflate the two. Matchmaking's launch step (`MatchLauncher`) can only be verified end-to-end on a published two-place build, never in Studio.
- **G11 — `Signal:Fire` (the shared `BindableEvent` wrapper) is deferred.** A synchronous read of an attribute or state immediately after the `Set`/`Fire` that changed it sees the *previous* value. Needs a `task.wait()` between the write and the read whenever testing from the command bar or a test script.
- **G12 — `Camera.CameraSubject = nil` does not clear it**, and `CameraType` must be `Scriptable`, not `Custom` (`Custom` is Roblox's interactive default and its built-in scripts fight for `CameraSubject` every frame). A free-camera fallback needs a real anchored Part to point at, not `nil`.
- **G13 — `get_console_output` (Studio MCP) can return a stale buffer across a Play stop/restart.** Don't trust it as a liveness signal for a running script; re-read Instance-backed state (attributes, `leaderstats`) fresh instead.

## Reference tables

**File suffix → Roblox class:** `Foo.luau` = ModuleScript · `Foo.local.luau` = LocalScript · `Foo.legacy.luau` = server `Script` (RunContext Legacy) · `init.luau` = folder-as-module.
`.legacy.luau` files are **live and running**, not dead code.

**Folder → service:** `<Place>/<Service>/` — `Lobby/` and `Map0_Test/` are the two places, each with its own `ReplicatedStorage`/`ServerScriptService`/`StarterPlayerScripts`/etc. mapping 1:1 to Roblox services underneath. No Rojo project file; both places live-sync via disk. Keep the two trees byte-identical on every shared path — verify with `diff -rq Lobby Map0_Test`.

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
| `QueuePadSize` | the pad's `Zone` Part | Queue pad capacity (1/2/4). Owned by `QueuePadService` |
| `QueuePadLabel` | a Part inside the pad model | Marks which descendant carries the display `BillboardGui`/`TextLabel` |
| `QueuePadCount` / `QueuePadCapacity` / `QueuePadEndsAt` | the pad's `Zone` Part | Server-written, read-only display state. `QueuePadEndsAt` is `0` when idle, else a `workspace:GetServerTimeNow()` deadline |

**Asset paths** (tree structure differs — don't assume parity):
- `ReplicatedStorage.Assets.Tool.SupportItem`
- `ReplicatedStorage.Assets.Tool.Camera.Camera1`

**Security boundary:** `CameraSessionTracker`'s InCamera flag is client-reported — UX guard only, never a security check.
