# Planned — current project snapshot

Snapshot of where development stopped and what happens next.
Source of truth: `MAINHANDOFF.md`. Roadmap: `~/.claude/plans/before-phase-8-perform-scalable-mochi.md`.
Architecture invariants and environment gotchas (G1–G10) live in MAINHANDOFF — not repeated here.

---

# Development Summary

Work over the past 4 days, grouped by system. Only what still exists today.

**Two-place rearchitecture (Phases 0–8).**
- Lobby (`PlaceId 91205326584169`) and reserved Game Server (`PlaceId 100171816233157`),
  same universe (`GameId 10535406765`) so `RewardStore_v1` is shared.
- `ServerRole` resolves the role from `game.PlaceId`; `LobbyBoot`/`GameBoot` are ordered
  `Start()` lists. Every service is booted from a list, never self-wired.
- Full teleport round trip built: `MatchLauncher` → `ReserveServer`/`TeleportAsync` →
  `MatchArrival` → match → `ReturnToLobbyService` → `ArrivalService`.

**Match lifecycle.**
- `MatchStates`/`PlayerStates`/`MatchConfig` as flag-bearing data tables with `Validate()`.
- `MatchManager` (single guarded `RequestTransition`), `MatchParticipants`,
  `MatchEndCondition`, `MatchClock` (countdown, `MatchDuration = 300`, `Ending → Cleanup` hold),
  `MatchCleanup` (save-step + teardown-step registries), `MatchReplicator`, `MatchResultBuilder`.

**Participant onboarding (8.5).**
- `MatchSpawner` loads characters — the first-ever subscriber to `MatchParticipants.Joined`.
- `KitLifecycleHook` grants the kit on `CharacterAdded`, gated by the `MatchStates.KitGranted`
  flag, and registers `"KitTeardown"` into `MatchCleanup`.
- `LoadoutService.GetCameraId` façade in front of the `CurrentCamera` attribute.
- `PlayerStateHandler.legacy.luau` deleted; its behavior split into `KitLifecycleHook` (Game)
  and `LobbyDeathPolicy` (Lobby).

**Death / spectate.**
- `DeathService` (Game, state-gated), `LobbyDeathPolicy` (Lobby, instant respawn),
  `SpectateService`/`SpectateTargets` + client camera controller and HUD.

**Observability (8.1).**
- `RewardStore.SaveAll` returns `(successCount, total)`; the Cleanup save step returns a
  real boolean instead of unconditional `true`.
- `MatchResultBuilder` freezes its `perPlayer` snapshot at `Ending`; `RewardResultHook` is
  its first contributor.
- `MatchResultSync` finally has a client listener on both places (`MatchReceipt` + controller).

**Game-place mirror tooling (superseded, deleted).** A prior session built
`Tools/GenerateGameMirror.ps1` + `Tools/mirror-chunks/chunk-01..10.luau` + `check.luau` to
generate-and-paste the Game place's content. The repo reorg into `Lobby/`/`Map0_Test/` (both
live-syncing) made this whole workflow unnecessary; it and `Tools/InstallGameMirror.luau`/
`Tools/CheckGameMirror.luau` are deleted. Kept only as a historical note — the FNV-1a
overflow fix it made no longer matters since there's no mirror hash to compute.

---

# Current Architecture

Stable seams that future work depends on.

- **Boot lists own lifecycle.** Module scope only defines the table. Role is asserted inside
  `Start()`. Adding a service = one line in `GameBoot`/`LobbyBoot`.
  `MatchArrival` must stay **last** in `GameBoot` — it fires the first real transition.
- **Extension registries, not edits.** `MatchCleanup.RegisterSaveStep`/`RegisterTeardownStep`,
  `MatchResultBuilder.RegisterContributor`, `RewardService.RegisterContextProvider`.
  `RewardCleanupHook` is the canonical thin-hook shape; copy it.
- **Dependency direction.** Requires flow up only; commands down; events up via `Signal`.
  A feature module requiring *down* into Match (e.g. `KitLifecycleHook`) must not live in `Match/`.
- **Enum-as-data.** Never branch on a state name — read a flag column.
  `MatchStates` flags: `GameplayActive`, `AcceptsJoins`, `SpectateAllowed`, `ScoringActive`,
  `MonstersSpawn`, `Terminal`, `KitGranted`.
- **Reward pipeline.** `PhotoCapture` → `CaptureTargets.Resolve` → `CaptureGuard` →
  `RewardService` (the only sink) → `RewardLedger` → `RewardStore_v1`.
- **Remotes only, codes not messages.** Zero RemoteFunctions. Server replies on a separate
  `*Result`/`*Feedback` remote with a code string; a shared `*ResultCodes` module maps it.
- **Two-place sync is now automatic.** `Lobby/` and `Map0_Test/` are separate folders, each
  live-syncing to its own Studio place, the same mechanism the Lobby alone used to have. The
  old generate-and-paste mirror-chunk workflow is deleted. Drift check is a plain recursive
  hash diff between the two trees (they must stay byte-identical except for place-specific
  content) — no `MirrorHash` attribute needed anymore.

---

# Current Verification Status

## Verified
- Phases 1–7: state enums, `PlayerStateService`, `MatchManager`/`MatchParticipants`/
  `MatchReplicator`, death flow, spectate (single-player scenarios), match end/result/cleanup.
  All confirmed via live Play sessions with hand-driven transitions.
- Phase 7.5 content migration — all 10 checklist items pass, including a real-client capture
  (G5 pass) and a live `GetAsync` read-back proving XP persisted.
- `RewardStore_v1` is genuinely shared across both places (same XP total observed on each).
- Game-place mirror is **complete and byte-identical to disk**:
  `checked 126 | missing 0 | wrong class 0 | drifted 0`.
- Zero import cycles (`graphify update`).

## Partially Verified
- **Phase 8.5 onboarding.** The full chain was proven in a Studio Play session by manually
  driving all 17 `GameBoot` services: reached `Countdown`, `KitGiven = true`,
  backpack held `[Camera, Slot 1, Slot 2]`. Not yet observed via a real unattended arrival.
- **Phase 6 spectate.** The `NoTargets` / free-camera path is proven live. "Kill one, confirm
  they spectate the other" and "disconnect the target mid-spectate" need two real clients.

## Not Yet Verified
- **Phase 8 / 8V — the teleport round trip.** Never run. `ReserveServer`/`TeleportAsync`
  return HTTP 403 in Studio (G10), so this needs a published two-place build and a real client.
- **Phase 8.1 fixes in a live DataModel** — the save-failure path (API Services off, G7) and
  the `MatchResultSync` receipt rendering on both places.
- A match ending **on its own** via `MatchDuration`, and the reserved server actually emptying.
- A mid-match respawn regranting the kit.
- `MatchStates.Validate()` failing loudly when `KitGranted` is stripped from a row.

---

# Technical Debt

## Blocking / must clear before 8V

| Item | Why it exists | Impact | Resolution |
|---|---|---|---|
| Both places not republished | Last publish predates all 8.1/8.5/8V work, and the repo reorg | Nothing built recently is live; 8V cannot start | Publish both places |

Resolved since this table was last written: the duplicate `ServerScriptService.Bootstrap`
on the Game place is deleted (confirmed gone on disk and in the live Studio datamodel), and
`05d2e98`/`a3af174` mean the "nothing committed since `ec0b7d8`" row no longer applies.

## Superseded tooling

- `Tools/GenerateGameMirror.ps1`, `Tools/mirror-chunks/`, `Tools/InstallGameMirror.luau`,
  and `Tools/CheckGameMirror.luau` are all **deleted**. The repo reorg into `Lobby/` +
  `Map0_Test/` (both live-syncing) makes the whole generate/install/check mirror workflow
  unnecessary — there is nothing left to mirror by hand.

## Deferred by decision

| Item | Why | Impact | Planned |
|---|---|---|---|
| No DataStore session locking | Prefer a proven library over hand-rolling | Fast rejoin / server hop = last-write-wins clobber | Cheap gate (`IsReady` + confirmed `Save` + `MarkHandedOff`) in Phase 10; library migration is Phase 12 |
| Client-supplied shot `origin` | Server-derived origin is its own phase | Spoofable shot position | Mitigated by `CaptureGuard`'s 10-stud proximity check. Revisit for ranked |
| No encounter director | `MonsterBootstrap` was deleted, not replaced | `MonsterService.Spawn` has zero production callers; monsters are ProximityPrompt-triggered | **Phase 9** — new file + one `GameBoot` line, zero edits to existing files |
| `FlashEvents` server Signal, zero subscribers | Reserved for monster perception | Unexercised seam | Phase 9 is its natural first subscriber |
| `RewardModifiers` registry, zero entries | The first entry should be a designed feature | Unproven Combo/Streak/Event seam | Deferred; right home for a per-mode reward multiplier |
| `UITheme`/`UIBuilder` adopted by `CurrencyUI` only | Retrofit changes shipped screens | Six divergent greys across five files | Blocked on palette sign-off. **All new UI uses them from line one** |
| `DeathScreen.RegisterButton` has zero callers | Needs a forfeit-policy decision that doesn't exist | No "Return to Lobby" button | **Phase 13** — blocked on design |
| `RewardLedger` runs `StartAutosave` + `BindToClose` at module scope | Predates the `Start()` convention | `require` has side effects; breaks Edit-mode requires | **Phase 12** — autosave is one of the writers being tamed |
| `RewardService.RegisterContextProvider` takes no `name` | Inconsistent with the other two registries | Costs a diagnostic string | Fix opportunistically |
| `SoundIds.luau` stub | Orthogonal | Blocks nothing | Deferred |
| Show/HideCurrencyUI are no-ops on the Game place | `CurrencyUI` is Lobby-shaped | Harmless — `FireClient` to a remote with no listener | A real in-match HUD is its own phase |

## Structural risk

- **Retired.** Manual two-place sync used to be the largest standing risk here; the
  `Lobby/`+`Map0_Test/` reorg replaced it with real per-place live sync, no generator step
  involved. Remaining check is a plain recursive hash diff between the two trees — still no
  Rojo, no CI, so genuine drift (someone hand-edits one place's Studio instance without
  touching disk) is still only detectable, not prevented. Not worth a dedicated phase unless
  that actually happens.
- **`MarkHandedOff` can strand XP** (Phase 10): if the save marks handed-off and
  `TeleportAsync` then fails, that player's session refuses all writes until rejoin.
  `Launch` returning false must trigger `ClearSession` + fresh setup — and note
  `RewardLedger.SetupPlayer` *adds* the baseline, so a naive re-setup double-counts.

---

# Current Phase

- **Roadmap phase:** 8V — published-build verification.
- **Milestone:** prove the teleport round trip end to end on a real client.
- **Immediate prerequisite:** publish both places. (The duplicate `Bootstrap` blocker and the
  repo commit are already cleared — see below.)
- **Gate:** 8V is the last remaining unknown-unknown (roadmap R-1). Phases 9, 10, 11 and 12
  all sit behind it. **Do not start new gameplay features until 8V passes** — everything after
  it is Studio-verifiable, so 8V is the only step that can still surprise the design.

---

# Next Session Plan

**Done this session:** repo reorganized into `Lobby/`/`Map0_Test/` (both live-syncing);
duplicate top-level `Bootstrap` deleted and confirmed gone from the live Game-place
datamodel; superseded mirror tooling deleted; reorg committed (`a3af174`); `graphify update`
run against the new paths (zero import cycles); this doc and MAINHANDOFF updated for the new
layout.

1. **Publish both places** with the current code.
2. **Run the 8V checklist** (MAINHANDOFF, Phase 8V): join the Lobby as Creator → `/launch` →
   confirm teleport → character loads with no manual step → camera Tool equipped →
   photograph a target → match self-ends at 300s → server empties → back on the Lobby with
   XP intact.
3. **Ride along with 8V:** the two Phase 6 spectate scenarios, if a second real player is
   available. This is the only context where two real clients exist.
4. **Update MAINHANDOFF** with the 8V result.
5. Only then: **Phase 9 (encounter director)** — subscribe to `MatchManager.StateChanged`,
   read `MatchStates.MonstersSpawn`, call `MonsterService.Spawn`. One new file, one `GameBoot`
   line. Treat a diff that touches any other file as evidence the seam is wrong.

---

# Notes for Future Claude Sessions

- **Studio Play can never exercise the real Game-place match path.** `GameBoot` sets
  `Players.CharacterAutoLoads = false` *before* the non-reserved-server guard, and Studio Play
  always reports `PrivateServerId == ""`. Boot bails, players land in the void. Services must
  be driven by hand — that is expected, not a bug.
- **`ReserveServer`/`TeleportAsync` return HTTP 403 in Studio**, even against a published place.
  Only a real published client exercises the round trip. DataStore calls *do* work in Studio
  (with API Services on) — the two are easy to conflate.
- **G3 is the recurring trap.** `execute_luau` has its own isolated `require()` cache and its
  own `_G`, on both Client and Server datamodels. State populated by a real Script is invisible
  to it and looks exactly like a hang. Verify through shared Instances only — attributes,
  `leaderstats` values — read fresh each call. `get_console_output` is not a liveness signal.
- **`Signal:Fire` is deferred** (BindableEvent). Reading state synchronously after a fire sees
  the *previous* value. This has caused a false failure in three separate phases. It also
  governs boot ordering: publishers go before subscribers, and `MatchArrival` goes last.
- **Client-created instances don't replicate.** `MovementAttachment`/`MovementDrive` and the
  client's `WalkSpeed` writes are invisible from the server datamodel. Reading them server-side
  produces false negatives.
- **Lifecycle ownership.** `StartGame.GivePlayerStarterKit` is the only kit grant, idempotent
  via the `KitGiven` latch. `EndGame` delegates to `RewardLedger.ResetRunScoped` /
  `ObjectiveService.Reset` — it does not hardcode currencies. On the Game place, **death must
  not clear tools**: `KitGiven = false` → respawn → `CharacterAdded` → regrant. Teardown
  happens once, at `Cleanup`.
- **Game vs Lobby.** Match layer is Game-only; the Lobby never sees `MatchState`. Cameras are
  purchased and swapped **only** on the Lobby — Phase 11's read-only-on-Game design depends on
  that staying true.
- **Content migration status.** Code is fully mirrored (126 instances, verified clean).
  Workspace content is **not** part of the mirror and is hand-placed: the spawn point,
  `Phase7_5MonsterTarget`, `Phase7_5ObjectiveTarget`, and the `Assets.Tool.Camera` tree.
  `CameraInventory` survives a missing `Assets` tree (returns `NoCameraAssets`), but every
  match then hands out an empty placeholder.
- **Mirror workflow is gone.** `Lobby/` and `Map0_Test/` both live-sync from disk now — edit
  the file, Studio picks it up, same as it always has for the Lobby. Drift check (should stay
  byte-identical on every shared path, minus known divergences like
  `ObjectiveVisualsController`'s packaging): recursive hash diff between the two folders,
  no installer/checker scripts needed.
- **Graphify workflow.** Cross-file questions only (`graphify query`/`path`/`explain`).
  Run `graphify update` once per completed unit of work. Never read
  `graphify-out/cache/` or `graphify-out/*/graph.json`.
- **File suffix encodes class.** `Foo.luau` = ModuleScript · `Foo.local.luau` = LocalScript ·
  `Foo.legacy.luau` = server Script (RunContext Legacy) · `init.luau` = folder-as-module.
  `.legacy.luau` files are **live and running**, never dead code.
- **No Python on this machine.** PowerShell is the scripting fallback. Watch for
  `$arr[0..-1]`, which returns the whole array rather than an empty one.
