# MAINHANDOFF — current state

Agent-facing. Current phase only, no history. Git has the changelog.
Module behavior lives in the code and `graphify-out/GRAPH_REPORT.md` — not here.

## Phase

Single-server vertical slice, feature-complete enough to play: move → buy camera →
photograph monsters/objectives → earn XP+Score. XP persists.

**Next:** rearchitecting to Lobby Server + reserved Game Server (matchmaking, match state
machine, player state machine, death/spectate, end-match teleport). Blueprint approved and
written to `~/.claude/plans/planning-mode-do-not-rustling-firefly.md`. **No code started.**
That plan is the spec; if it disagrees with disk, disk wins.

## Architecture invariants

Rules that outlive any single file. Violating one is a bug even if it works.

- **Config in data tables, not logic.** `CameraStats`, `MonsterStats`, `RewardTypes`, `CaptureTargets`, `ObjectiveTypes`. Adding a camera/monster/reward/target = one table row, no new script.
- **Enum as data.** States are rows with flags (`ObjectiveStates`). Never branch on a state *name*; read its flag. Predicates fail closed on unknown states.
- **Replication split.** Shared state → Instance attribute (auto-replicates). Per-player state → RemoteEvent + snapshot on join/`CharacterAdded`. Attributes cannot express per-player values.
- **RemoteEvents only.** Zero RemoteFunctions in the repo. Client fires a request; server replies on a separate `*Result`/`*Feedback` remote with a **code string**; a shared `*ResultCodes` module maps code → message.
- **All remotes registered** in `Remotes.ALL_NAMES`; `Remotes.Init()` provisions them (server, from `Bootstrap.legacy.luau`). Never `WaitForChild` a remote by hand.
- **Ownership is symmetric.** Whoever acquires a GUI/effect/connection releases it, by reference, via a `Trove` — never by name lookup.
- **No reward amount ever crosses a remote.** `RewardService` is the only sink.
- **Server reads attributes off the server-observed instance**, never client-declared identity.
- **Defaults are for display, never persistence.** If you can't distinguish "no data" from "couldn't read data", do not write.
- No `--!strict`. No circular dependencies (graph currently reports **zero** import cycles — protect that).

## Systems

| System | Status | Notes |
|---|---|---|
| Movement / stamina / FOV / camera tilt | works | `LinearVelocity`, asymmetric smoothing |
| HUD (stamina) | works | `StarterPlayerScripts`, **not** `StarterGui` — see G1 |
| Inventory slots + shop | works | server-authoritative buy; empty slots tagged `IsEmpty` |
| Currency UI | works | remote-driven; leaks connections on Show/Hide (deferred) |
| Camera framework | works | client session/viewfinder/touch HUD + shelf; one `Trove` per session |
| Photo capture → reward | works | 5×5 spread raycast → `CaptureTargets.Resolve` → `RewardService` |
| XP persistence | works | `RewardStore_v1`, verified round trip. Score is run-scoped, Cash is not a RewardType |
| Monsters | works | spawn/damage; **player-triggered** via a `Workspace` ProximityPrompt, no director |
| Objectives | works, uncommitted | registry/service/replicator + client visuals |
| Flash | works, uncommitted | client `FlashSignal` → screen + world-light renderers |

## Half-built / not wired

- **`StartGame` / `EndGame` have no in-code caller.** Both fire only from Studio ProximityPrompts (`Workspace.TestButton.InventorySlot.StartGame.Script`). They are *inventory* functions despite the names — kit grant and kit teardown, not match lifecycle. The match rearchitecture makes them a real caller's job.
- **`UITheme` / `UIBuilder` adopted by `CurrencyUI` only.** Six divergent "dark grey" values remain across five files. Blocked on palette sign-off. Use them in all new UI.
- **`RewardModifiers`** — registry exists, zero entries. The Combo/Streak/Event seam, unproven.
- **`FlashEvents`** (server) — bare Signal, zero subscribers. Reserved for monster perception.
- **`SoundIds.luau`** — TODO stub.
- **No encounter director.** `MonsterBootstrap` was deleted, not replaced.

## Known broken / deferred (accepted)

| Issue | Impact | Why deferred |
|---|---|---|
| `RepeatPolicy = "Unlimited"` on both capture targets | Holding aim on one target ≈ 120k XP/min | Anti-farm logic (`CaptureGuard.CheckRepeatPolicy` → `"Cooldown"`) exists and is one table edit from live |
| No DataStore session locking | Fast rejoin / server hop = last-write-wins clobber | Prefer a proven library over hand-rolling. Destructive outage-zeroing case is already closed |
| `origin` is client-supplied | Spoofable shot origin | `CaptureGuard.ValidateShot` 10-stud proximity check is a mitigation; server-derived origin is a larger change |
| `CurrencyUI` Show/Hide connection leak | Slow growth | Fix is a `Trove`, same pattern as `CameraSession` |
| Death resets `KitGiven` but skips `EndGame.ClearPlayerTools` | Cash/Score/objectives survive death | Unmade design decision, not a bug |

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
- **G9 — Roblox does not guarantee Script execution order.** `Bootstrap.legacy.luau` is a decoupling point, *not* an ordered bootstrap. Safe today only because nothing subscribes to anything at boot — that stops being true the moment the match rearchitecture lands.

## Reference tables

**File suffix → Roblox class:** `Foo.luau` = ModuleScript · `Foo.local.luau` = LocalScript · `Foo.legacy.luau` = server `Script` (RunContext Legacy) · `init.luau` = folder-as-module.
`.legacy.luau` files are **live and running**, not dead code.

**Folder → service:** folder names at repo root map 1:1 to Roblox services. No Rojo project file; sync is via Studio MCP. `StarterPlayerScripts/` **does** have a local mirror (11 LocalScripts) — it did not historically.

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

**Asset paths** (tree structure differs — don't assume parity):
- `ReplicatedStorage.Assets.Tool.SupportItem`
- `ReplicatedStorage.Assets.Model.Tool.Camera.Camera1`

**Security boundary:** `CameraSessionTracker`'s InCamera flag is client-reported — UX guard only, never a security check.

## Uncommitted since `v0.1` (d311d04)

Everything below is on disk and working but not committed. Commit before starting the match rearchitecture.

- **New:** `Modules/Objective/` + `GameService/Objective/` (full objective system) · `Modules/Flash/` + `GameService/Flash/` · `Shared/Signal.luau` · `Modules/UI/` · `Modules/Shop/` · `PlayerRuntimeStats.luau` · `Bootstrap.legacy.luau` · `StarterPlayerScripts/` (now disk-mirrored)
- **Deleted:** `CameraFlashEffect.luau` (→ `Modules/Flash/`) · `ShopItems.luau` · `MonsterBootstrap.legacy.luau`
- **Reworked:** `Remotes.luau` → `ALL_NAMES` + `Init()` · `PlayerStats` split (shared tunables stay; mutable per-player state → `PlayerRuntimeStats`, because `PlayerStats` is a server+client singleton and `Stamina` was one value shared by every player) · `CaptureTargets`/`CaptureRules`/`ShotResultCodes` extended for objectives
- `graphify-out/` is stale relative to this — run `graphify update`.
