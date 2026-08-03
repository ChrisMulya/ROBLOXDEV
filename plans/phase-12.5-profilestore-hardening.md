# Phase 12.5 — Close the Phase 12 deviations

## Context

Phase 12 (`189ce8a`) migrated reward persistence from raw `DataStoreService` to
ProfileStore. It shipped with four deviations from the roadmap, each a judgment call made
mid-implementation because the roadmap specified Phase 12 as one line ("ProfileStore
migration") and left the design to implementation time.

Reviewing them against the code afterwards, they are not equal: **two are latent
data-integrity bugs**, one is a drift hazard, one is a robustness gap. There is also one
genuinely outstanding "found, not fixed" from that session — repeatedly observed, never
addressed.

12.5 closes all of them before Phase 13. It adds no gameplay. Every item below is either a
correctness fix or an observability seam that makes a correctness claim checkable.

**Note on the Phase 12 "found, not fixed" entry:** the leftover
`ServerStorage/ProfileStore.luau` was cleaned up inside that same commit — it is resolved,
not outstanding. The real outstanding item is #5 below.

---

## 1. The v1 migration gate is one-shot — live data-loss path

**Severity: highest. This one can permanently orphan a real player's XP.**

`RewardStore.Load` gates the legacy `RewardStore_v1` read on `profile.SessionLoadCount == 1`.

The failure sequence:
1. A pre-Phase-12 player joins. ProfileStore creates their v2 profile (`SessionLoadCount == 1`).
2. The legacy `GetAsync` fails all 3 attempts — a transient outage, throttle, anything.
3. `legacyOk` is false, nothing is copied. The profile keeps its template zeros and is
   marked active/Ready. The player plays and saves to v2 normally.
4. They rejoin. `SessionLoadCount == 2`. **The fallback never runs again.** Their real v1
   total is orphaned with no code path left that reads it.

### Fix

Replace the `SessionLoadCount` gate with a durable marker in `profile.RobloxMetaData`
(ProfileStore saves that table automatically):

- Gate on `not profile.RobloxMetaData.MigratedFromV1`.
- Set `MigratedFromV1 = true` **only when the legacy read definitively succeeded** —
  `legacyOk == true`, whether or not it found data. A "new player, nothing stored" result is
  a successful migration; a failed read is not, and must retry on the next join.
- Log every migration (userId, values copied, or "no legacy data") so the sunset below is
  decidable from evidence rather than guessed.

**Constraint — why `RobloxMetaData`, not `Profile.Data`:** `zeroedBaseline()` in
`RewardStore.luau` does double duty as the ProfileStore template *and* as the failure-shape
returned to `RewardLedger.SetupPlayer`, which iterates `pairs(baseline)` and calls
`getValue()` per key. A non-reward-type key in that table triggers `RewardLedger`'s "unknown
reward type" warning on every player load. `RobloxMetaData` never enters that loop.

### Sunset

The v1 path is temporary, not permanent. Once the migration log shows no migrations for a
full retention window, delete the legacy read, `legacyBackend`, and `attemptLegacyRead`.
Record the sunset condition in `MAINHANDOFF.md` so it is a decision waiting on data, not a
file nobody dares touch.

---

## 2. `OnLaunched` fires on request-accepted, not arrival — roadmap R-3, resurfaced

**Severity: high. Strands a player's session with no recovery path.**

`LaunchGate.OnLaunched` → `RewardLaunchHook` → `RewardStore.ClearSession` →
`Profile:EndSession()` fires the instant `MatchLauncher.Launch` returns true.

`TeleportAsync` returning true means **the request was accepted**, not that anyone arrived.
The teleport can still fail asynchronously via `TeleportService.TeleportInitFailed`. When it
does, that player is sitting on the Lobby with their ProfileStore session already released —
every subsequent write refused until they rejoin.

This is exactly roadmap risk R-3. Phase 10's `LaunchGate.Rollback` covered it. Phase 12
removed `Rollback` on the reasoning that "the session stays active until `OnLaunched`" —
which is true, but `OnLaunched` turned out to be the wrong event.

**Supporting evidence:** `Lobby/MatchLauncher.luau` has no `TeleportInitFailed` handler at
all, while `Match/ReturnToLobbyService.luau` — the inbound leg — has a proven one
(`handleInitFailed`, capped backoff `{2, 5, 10}`, then kick). The outbound leg was simply
never given the same treatment.

### Fix

| Change | File |
|---|---|
| `TeleportInitFailed` handler mirroring `ReturnToLobbyService.handleInitFailed`; filter on `placeId == PlaceIds.Game`, same capped-backoff shape | `Lobby/MatchLauncher.luau` |
| New `RegisterOnLaunchAborted` / `OnLaunchAborted(players)` — symmetric with the existing `OnLaunched` registry | `Lobby/LaunchGate.luau` |
| Register an abort handler that calls a new `RewardStore.Reacquire` per player | `Reward/RewardLaunchHook.luau` |
| New `Reacquire(player)` — starts a fresh session, leaves leaderstat IntValues untouched | `Reward/RewardStore.luau` |
| New `TeleportInitFailed` row | `Shared/MatchLaunchResultCodes.luau` |

**Hard constraint on `Reacquire` — do not route it through `RewardLedger.SetupPlayer`.**
`SetupPlayer` *adds* the baseline into existing IntValues (deliberately — see its own comment
on surviving an award earned mid-load). Calling it on a player whose IntValues already hold
the correct total double-counts. Roadmap R-3 names this hazard explicitly and it already bit
once in Phase 7.5.

Leaving the IntValues untouched is correct here: `OnLaunched` only fires after
`LaunchGate.Check` already forced a confirmed save, so stored == live at the moment of
release. `Reacquire` re-establishes the lock, nothing else.

**Do not auto-requeue on abort.** Roadmap §4.3 already ruled on the sibling case ("No
automatic retry on `ReserveFailed` — fall back to the grace timer so a Roblox-side outage
isn't hammered"). Same reasoning. Fire the existing `QueueResultCodes.LaunchFailed` to the
client and let them re-queue by hand.

---

## 3. The two save-timeout constants are coupled but nothing enforces it

`RewardStore.SAVE_CONFIRM_TIMEOUT_SECONDS = 8` and `MatchCleanup.STEP_TIMEOUT_SECONDS = 10`
are independent `local`s in different files that must maintain `SAVE_CONFIRM < STEP_TIMEOUT`,
or `RewardCleanupHook`'s save step gets abandoned mid-write on every single Cleanup.

Roadmap R-6 calls sizing this relationship a design task inside Phase 12. Phase 12 sized it
correctly and wrote the reasoning in a comment — but a comment is not a constraint, and
either number can be changed by someone who never reads the other file.

### Fix

Export both as real module fields and assert the relationship at boot in
`RewardCleanupHook.Start()` — it already requires both modules, so the dependency direction
stays legal. A violation should `warn` loudly with both values named. Cheap, and converts
silent drift into a boot-time complaint.

---

## 4. Progression precondition fails the whole batch over one departed player

`checkProgression` in `RewardLaunchHook` calls `RewardStore.IsReady` then `RewardStore.Save`
for every candidate. A player who disconnects mid-check has no active session, so `Save`
warns and returns false → `ProgressionSaveFailed` → **the entire launch is aborted for
everyone still present**, who then sit in the queue waiting on the grace timer again.

`LaunchGate`'s `Roster` precondition (registered by `QueueService`) exists precisely to own
"did the roster change", and runs after Progression.

### Fix

Skip `player.Parent == nil` candidates in both loops in `checkProgression`, and let `Roster`
remain the single authority on roster changes. First-failure-wins semantics are unchanged;
one leaver stops denying the whole queue.

---

## 5. `CameraSessionTracker` module-scope side effects — the real "found, not fixed"

`GameService/Camera/CameraSessionTracker.luau` does all three of these at module scope:

- `Remotes.Get("CameraSessionChanged")` (line 11) — a `WaitForChild`, so a require before
  `Remotes.Init()` hangs
- `CameraSessionChanged.OnServerEvent:Connect` (line 17)
- `Players.PlayerRemoving:Connect` (line 21)

This is the same debt class (#21) Phase 12 just eliminated for `RewardLedger`, and it is what
broke require-based verification of `CameraShelfSwap` in **both** Phase 11 and Phase 12 — it
was worked around twice and never fixed.

There is already an established repo precedent: Phase 8.5 moved `Remotes.Get` out of module
scope in `StartGame`/`EndGame` for exactly this reason.

### Fix

Give it a `Start()`, move all three side effects into it, and add it to **both** `GameBoot`
and `LobbyBoot`.

**Risk to respect:** it currently self-wires via require from `CameraShelfSwap`. Converting
to `Start()` means that if either boot list is missed, the connection is never made and
`IsInCamera` silently returns false forever — the shelf would then happily destroy a camera
out from under a player mid-session, which is the exact cascade this module exists to
prevent. Both boot lists must land in the same change, and verification must confirm the
connection actually fires at runtime, not merely that the module compiles.

---

## 6. ProfileStore's diagnostic surface has zero readers; Mock is unused

Phase 12 wired none of ProfileStore's observability: `OnError`, `OnOverwrite`,
`OnCriticalToggle`, and `DataStoreState` all have zero subscribers repo-wide (confirmed by
grep). Phase 8.1's entire thesis was that a save failure and a save success must not be
observationally identical — this is that same gap, reintroduced one layer down.

`OnOverwrite` matters specifically for item 1: it fires when a key held data that wasn't a
ProfileStore profile — i.e. precisely the v1-format-detected case. Without it, a botched
migration and a brand-new player look the same.

### Fix

**New `Reward/RewardStoreDiagnostics.luau`** — the fourth instance of the
`RewardCleanupHook` pattern (registers/subscribes from its own `Start()`, booted from a
list). Subscribes to `OnError`, `OnOverwrite`, `OnCriticalToggle`; logs with enough context
(store name, profile key) to identify the affected player. Added to both boot lists.

**Mock backend for Studio.** Route through `ProfileStore.Backend.Mock` when the real
DataStore isn't reachable, making the whole persistence path exercisable in Studio despite
G7. Two constraints:

- **Never silent.** Selecting Mock must `warn` unmistakably. A Studio test that looks like it
  saved but wrote to a mock store is worse than one that fails loudly.
- **Not resolvable at module scope.** `ProfileStore.DataStoreState` starts as `"NotReady"`
  and resolves asynchronously, so reading it where `RewardStore.Backend` is currently
  assigned would always pick Mock. Resolve the active store lazily via a small
  `activeStore()` helper called inside `Load`/`Save` — `Backend` stays the real store object,
  and `Backend.Mock` is the reflection, so this is a selector, not a second store.

---

## Verification

No test runner exists in this project. Verification is Studio + live DataStore, and several
items are only meaningful against real stored data.

**Item 1 (migration) — the one that must not be skipped:**
1. On an account with real v1 XP that has *not* yet joined post-Phase-12: join, confirm the
   total carries over and the migration log fires once.
2. Rejoin. Confirm the log does *not* fire again and the total is stable (marker persisted).
3. Simulate the failure path: temporarily point `legacyBackend` at a nonexistent store name
   so the read fails, join with a fresh test profile, confirm the marker is **not** set and
   the migration is retried on the next join. Revert the store name after.

**Item 2 (launch abort):** hardest to trigger naturally. Drive it by calling
`LaunchGate.OnLaunchAborted({player})` directly from the command bar after a successful
launch-and-release, then confirm `RewardStore.IsReady(player)` returns true again and a
subsequent award both persists and reads back — and specifically confirm the XP total did
**not** double.

**Item 3:** set `SAVE_CONFIRM_TIMEOUT_SECONDS` above `STEP_TIMEOUT_SECONDS`, boot, confirm
the warning names both values. Revert.

**Item 4:** queue two players, disconnect one during the grace window, confirm the other
still launches instead of getting `ProgressionSaveFailed`.

**Item 5:** on the Lobby, equip a camera, enter a camera session, then attempt a shelf swap —
confirm it is refused with `InCameraSession`. This exercises the connection made in `Start()`,
which a compile check cannot. Repeat on the Game place.

**Item 6:** with API Services off in Studio, confirm the Mock warning appears and a
save/load round trip still completes. With them on, confirm it does not appear.

**Every item:** `graphify update` (zero import cycles), byte-identity check between `Lobby/`
and `Map0_Test/`, live-sync confirmed on both places by reading `Source` directly —
`require()` from the command bar caches failures for the datamodel's lifetime and is not
trustworthy after any module in the chain has errored once in a session.

---

## Non-goals

Explicitly out of scope, so they don't creep in:

- Phase 13 (early leave / forfeit) — still blocked on a policy decision that doesn't exist.
- Debt #25 (`RewardService.RegisterContextProvider` takes no `name`) — cosmetic, fix
  opportunistically.
- Debt #6 (`UITheme`/`UIBuilder` retrofit) — still blocked on palette sign-off.
- Any change to `Vendor/ProfileStore.luau`. It is third-party code; if it needs changing, the
  wrapper is wrong.
