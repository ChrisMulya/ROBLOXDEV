# Reward System

Design contract for XP and Score. Supersedes the scoring numbers in `PHOTO_SCORING.md`. No implementation yet — this is what the build is written against.

## The core idea

This is a **reward system, not a photo-scoring system**. The camera reports four facts — player, subject, shot quality, distance — and knows nothing else. Everything downstream is the reward system's business, and every future reward source (missions, objectives, achievements, events) pays out through the same sink without touching the calculator.

| What varies | Lives in | Adding to it costs |
|---|---|---|
| **The stud↔meter constant** | `Shared/Units` | one number |
| **Base reward per shot quality** | `XPRewardCurve` / `ScoreRewardCurve` | one table row |
| **How distance scales rewards** | `DistanceMultiplierCurve` spec | one field |
| **Bonuses** (combo, streak, event, premium, prestige…) | `RewardModifiers.Register` | one module, no signature change |
| **Which currencies exist** | `RewardTypes.All` | one table row |
| **Where numbers land** | `RewardLedger` | nothing — driven by `RewardTypes` |

Each mirrors a pattern already proven here: `Shared/Trove` and `Shared/Cooldown` for the util, `CameraStats.Stats` and `MonsterStats.Stats` for the data table, `sessionTrove:Add(...)` for the additive list, `CameraInventory.Give` for the single owner. No new concepts.

---

## Architecture

Six layers, dependencies flowing strictly downward. No layer knows about the one above it.

```
  SOURCES        CameraShotHandler   [future: Missions, Objectives, Achievements]
                          |                          |
                          v                          v
  ROUTING                  RewardService.Grant  <-- the single sink
                          |            |
                          v            v
  CALCULATION      RewardCalculator   RewardModifiers (registry)
                          |
                          v
  CURVES          DistanceMultiplierCurve · XPRewardCurve · ScoreRewardCurve
                          |                                (all expose :Evaluate)
                          v
  CONFIG          RewardTypes · curve tables · DistanceBandLabels   (pure data)

  LEDGER          RewardLedger  ->  RewardStore (DataStore, XP only)
```

**Two shapes flow through the system.** Everything else is plumbing.

| Shape | Produced by | Contents |
|---|---|---|
| `CaptureContext` | a reward source | `{ player, subject, shotQuality, distanceStuds, cameraId }` |
| `RewardResult` | `RewardCalculator` | `{ meters, bandLabel, amounts = { XP = n, Score = n }, breakdown }` |

**Placement.** Curves, config, calculator and types live in `ReplicatedStorage/Modules/Reward/` for the same reason `CameraStats` does: the client needs band labels to render results, and later will want curve shapes for "closer = more XP" preview hints. Routing, ledger and persistence live in `ServerScriptService/GameService/Reward/`, unreachable from the client.

**The server is authoritative** — it computes and applies; the client renders what it is told. **No remote ever accepts a reward amount.**

### The decision that makes this expandable

Every curve is a module exposing the same `:Evaluate(input) -> number` interface, and every optional bonus is an entry in `RewardModifiers`. The calculator therefore never learns a new branch when balance changes.

`XPRewardCurve` and `ScoreRewardCurve` are structurally identical lookups, so they are **thin instances of a shared `CurveFactory`**, not two copies of the same logic — separately configurable, no duplicated code.

---

## Modules

### `ReplicatedStorage/Modules/Reward/` — shared, pure

| Module | Sole responsibility |
|---|---|
| `RewardTypes.luau` | What a reward type *is*: display name, leaderstat name, persistence flag, reset-on-run-end flag, rounding rule. The reason adding a currency is a config edit. |
| `Curves/CurveFactory.luau` | Builds curves. `LookupCurve(table, default)` for key→value maps; `SteppedCurve(spec)` for the distance falloff. Owns the shared `:Evaluate` contract so no curve reimplements it. |
| `Curves/DistanceMultiplierCurve.luau` | meters → multiplier. Owns *only* the falloff shape. |
| `Curves/XPRewardCurve.luau` | shotQuality → base XP. |
| `Curves/ScoreRewardCurve.luau` | shotQuality → base Score. |
| `Curves/DistanceBandLabels.luau` | meters → display label. **Presentation only** — never multiplied into any number. |
| `RewardModifiers.luau` | Registry + evaluation of bonuses. Ships **empty**; the seam exists from day one so adding one later is not a refactor. |
| `RewardCalculator.luau` | `Calculate(context) -> RewardResult`. Pure. Combines curves and modifiers. Contains **zero reward values**. |

### `ServerScriptService/GameService/Reward/` — server, authoritative

| Module | Sole responsibility |
|---|---|
| `RewardService.luau` | The single sink. `Grant` applies amounts; `AwardFromCapture` is the capture-shaped wrapper over it. The only module sources ever talk to. |
| `RewardLedger.luau` | Owns the numbers per player. Creates leaderstat values from `RewardTypes`, adds, reads, resets run-scoped types. |
| `RewardStore.luau` | DataStore wrapper for persistent types. Load on join, save on leave, `BindToClose`, autosave, `pcall` + retry with backoff. **A session is not savable until a load definitively completes** — see the persistence rule below. |
| `CaptureGuard.luau` | Capture-specific anti-exploit validation. Keeps `CameraShotHandler` a thin adapter. |

### Modified

| File | Change |
|---|---|
| `GameService/Camera/CameraShotHandler.legacy.luau` | Stops computing meters. Validates via `CaptureGuard`, builds a `CaptureContext`, calls `RewardService.AwardFromCapture`, forwards the `RewardResult` in `ShotFeedback`. |
| `GameService/Player/PlayerCurrency.legacy.luau` | Delegates leaderstat creation to `RewardLedger` instead of hand-building `Cash` alone. |
| `GameService/Player/EndGame.luau` | Replaces the hardcoded `cash.Value = 0` with `RewardLedger.ResetRunScoped(player)`. |
| `Modules/Camera/FloatingShotText.luau` | Multi-line body, so the popup can show label + meters + amounts. |
| `StarterPlayerScripts/ShotFeedbackHandler` | Renders the new payload. |

> `ShotFeedbackHandler` is a `StarterPlayer` LocalScript — **no local file mirror**, must be edited via Studio tooling. See lesson 11 in `MAINHANDOFF.md`.

`ReplicatedStorage/Modules/Shared/Units.luau` is reused as-is — no changes.

---

## Calculation pipeline

```
CaptureContext { player, subject, shotQuality, distanceStuds, cameraId }
  1. meters   = Units.StudsToMeters(distanceStuds)          -- the ONLY conversion point
  2. distMul  = DistanceMultiplierCurve:Evaluate(meters)
  3. for each enabled type in RewardTypes:
       base   = BaseCurveFor(type):Evaluate(shotQuality)
       mods   = RewardModifiers.Collect(context, type)       -- currently returns {}
       flat   = sum of Additive-stage mods
       mult   = product of Multiplicative-stage mods
       amount = math.round((base + flat) * distMul * mult)
  4. bandLabel = DistanceBandLabels:Evaluate(meters)         -- display only
  -> RewardResult { meters, bandLabel, amounts, breakdown }
```

`breakdown` records base, `distMul`, and each modifier's name and value — so balancing is inspectable in the console, and a future "+250 XP · Combo ×1.5" UI needs no new server work.

### Distance multiplier

`SteppedCurve { StepMeters = 15, StartValue = 1.0, StepDelta = -0.1, MinValue = 0.5 }`:

```
tier       = math.floor(meters / StepMeters)
multiplier = math.max(MinValue, StartValue + StepDelta * tier)
```

| Quality | Meters | tier | mult | XP | Score |
|---|---|---|---|---|---|
| Strong | 10 | 0 | 1.0 | 1000 | 200 |
| Strong | 22 | 1 | 0.9 | 900 | 180 |
| Weak | 47 | 3 | 0.7 | 420 | 70 |
| Strong | 120 | 8 | 0.2 → **0.5** | 500 | 100 |

Two details, both silent bugs if missed:

- **The boundary is exclusive at the top.** `floor` puts exactly 15.0 m in tier 1 (×0.9), not ×1.0. The "0–15 m = 1.0 / 15–30 m = 0.9" phrasing is ambiguous at the seam; this is the resolution.
- **Round with `math.round`, never `math.floor`.** `1.0 + (-0.1 * 3)` is `0.7000000000000001` in floating point, so `600 * 0.7` lands on `419.99999999999994`. Flooring pays **419** instead of 420, and only at some tiers.

### Known bias: distance is measured to the hit point

`PhotoCapture.Fire` measures `(result.Position - origin).Magnitude` — the **raycast hit surface**, not the creature's center.

> A large monster's near face scores closer than its far face, so **physically bigger creatures are systematically easier to score on**, and shooting an outstretched limb beats shooting the body.

Harmless for the current single 4×4×4 GreyCube. Revisit when monster sizes vary. The fix is one line confined to `PhotoCapture.Fire` — measure to `subject:GetPivot().Position` — and `GetPivot()` works on both a `Model` and a lone `BasePart`.

### Balance note: the curve's tail is currently unreachable

The ×0.5 floor engages at 75 m = 225 studs, but the longest camera range is Camera2's Strong at **200 studs ≈ 66.7 m**, capping the worst achievable multiplier at ×0.6. The 120 m example above cannot occur in-game today. Revisit step size or camera ranges after playtesting; nothing needs to change to ship.

---

## Data flow: Camera → Reward System

```
CLIENT   CameraSession.Capture
           fires WeakCameraShot | StrongCameraShot (origin: Vector3, direction: Vector3)
--------------------------------------------------------------------------------
SERVER   CameraShotHandler.handleShot
           - existing: type-check args, resolve equipped tool, CameraStats settings, Cooldown
           - NEW: CaptureGuard.Validate(player, origin, shotQuality) -> ok, resolvedQuality
           - PhotoCapture.Fire(...) -> { subject, hitPosition, distanceStuds } | nil
           - miss -> ShotFeedback { hit = false }, no award, return
           - hit  -> RewardService.AwardFromCapture(player, {
                       player, subject, shotQuality = resolvedQuality,
                       distanceStuds, cameraId })
                       |
                       +-> RewardCalculator.Calculate -> RewardResult
                       +-> RewardService.Grant(player, result.amounts, meta)
                       |     +-> RewardLedger.Add per type (leaderstat + profile)
                       +-> returns RewardResult
           - ShotFeedback:FireClient(player, { hit = true, position, ...RewardResult })
--------------------------------------------------------------------------------
CLIENT   ShotFeedbackHandler renders label + meters + amounts; FloatingShotText at position
```

The camera passes **studs, not meters** — the camera domain has no concept of meters, and conversion stays at the reward boundary. `shotType` ("Strong"/"Weak") is passed as `shotQuality`: a one-line vocabulary mapping at the seam, so each domain keeps its own term.

---

## Public API

```
-- ReplicatedStorage/Modules/Reward
RewardTypes.All          : { [string]: TypeDef }
RewardTypes.Get(name)    -> TypeDef
RewardTypes.Persistent() -> { string }
RewardTypes.RunScoped()  -> { string }

Curve:Evaluate(input: number | string) -> number     -- every curve module
CurveFactory.LookupCurve(table, default) -> Curve
CurveFactory.SteppedCurve(spec)          -> Curve

RewardModifiers.Register(modifier)                   -- { Name, Stage, AppliesTo?, Applies, GetValue }
RewardModifiers.Collect(context, rewardType) -> { AppliedModifier }

RewardCalculator.Calculate(context) -> RewardResult  -- pure, no side effects

-- ServerScriptService/GameService/Reward
RewardService.AwardFromCapture(player, captureContext) -> RewardResult?
RewardService.Grant(player, amounts, meta) -> boolean -- THE sink; meta = { Source, SourceId }

RewardLedger.Add(player, rewardType, amount) -> number
RewardLedger.Get(player, rewardType) -> number
RewardLedger.ResetRunScoped(player)
RewardLedger.SetupPlayer(player) / TeardownPlayer(player)

RewardStore.Load(player) / Save(player) / SaveAll()

CaptureGuard.Validate(player, origin, requestedQuality) -> ok: boolean, resolvedQuality: string
```

A future mission system needs one line:

```
RewardService.Grant(player, { XP = 2500 }, { Source = "Mission", SourceId = "NightOne" })
```

---

## Configuration

```
RewardTypes.All = {
  XP    = { DisplayName = "XP",    LeaderstatName = "XP",    Persistent = true,
            ResetOnRunEnd = false, BaseCurve = "XPRewardCurve",    Round = "nearest" },
  Score = { DisplayName = "Score", LeaderstatName = "Score", Persistent = false,
            ResetOnRunEnd = true,  BaseCurve = "ScoreRewardCurve", Round = "nearest" },
}

XPRewardCurve    = LookupCurve({ Strong = 1000, Weak = 600 }, 0)
ScoreRewardCurve = LookupCurve({ Strong = 200,  Weak = 100 }, 0)

DistanceMultiplierCurve = SteppedCurve {
  StepMeters = 15, StartValue = 1.0, StepDelta = -0.1, MinValue = 0.5,
}

DistanceBandLabels = { { Max = 15, "POINT BLANK" }, { Max = 30, "CLOSE" },
                       { Max = 45, "MID" },         { Max = 60, "FAR" },
                       Default = "DISTANT" }

RewardRules = {
  SubjectCooldownSeconds  = 8,   -- per (player, subject) anti-farm window
  MaxOriginDeviationStuds = 10,  -- anti-spoof tolerance
}
```

**XP persists** across sessions; **Score is run-scoped** and resets alongside `Cash` in `EndGame`. `EndGame` calls `RewardLedger.ResetRunScoped(player)` — never per-currency code.

---

## Extension points

| Future feature | Where it plugs in | Cost |
|---|---|---|
| Combo · Streak · Event · Global XP · Premium · Prestige · Seasonal | `RewardModifiers.Register` | one module each, no calculator change |
| Camera upgrades | modifier reading `context.cameraId` (already in context) | one modifier |
| Entity-specific rewards / rarity | modifier reading `context.subject` attributes, or a `PhotoValue` field in `MonsterStats` | one modifier |
| Objectives · Missions · Daily Challenges · Achievements | call `RewardService.Grant` with flat amounts | no reward-system change at all |
| Multiple currencies | one row in `RewardTypes` + one base curve module | config edit |
| Levels from XP | new `XPLevelCurve` + a listener on `RewardLedger` | additive |
| Score → Cash end-of-night quota | `EndGame`, reading `RewardLedger.Get(player, "Score")` | the seam already exists |
| Continuous falloff instead of steps | swap `SteppedCurve` for a new factory kind | one module, zero callers |
| `Behavior.OnPhotographed` (`MONSTERS.md`) | `AwardFromCapture` already resolves subject + result | hook fires with the full `RewardResult` |

**Optional later migration:** `Cash` is a natural third `RewardType` (`Persistent = false, ResetOnRunEnd = true`), which would delete the last hardcoded currency handling in `EndGame` and `PlayerCurrency`. Out of scope here — the shop reads `Cash` directly and that path should be migrated on its own.

---

## ⚠ Anti-exploit — this lands before the payout

Distance and shot quality now carry money. Every item below is an **economy** exploit, not a cosmetic one.

1. **Client-supplied `origin` (critical).** `CameraSession.Capture` sends `workspace.CurrentCamera.CFrame.Position` and the server trusts it as the raycast start. A modified client reports an origin one stud from the monster and farms ×1.0 from across the map. **Fix:** reject if `origin` is further than `MaxOriginDeviationStuds` (~10) from the character's `Head` (R15 rig, confirmed present).
2. **Client-chosen shot quality (critical, newly weaponized).** Strong and Weak are *two separate remotes* — the client picks its own 1000-vs-600 payout tier and can always fire the Strong one. **Fix:** the server verifies stability itself (root-part velocity / `MoveDirection` against the `CameraStats.Stability` thresholds) and **downgrades** Strong→Weak when it disagrees. `CameraSessionTracker` is the natural home for the per-player state.
3. **Same-subject farming.** Nothing stops standing still and photographing one target forever; the per-shot `Cooldown` limits rate, not repetition. Anti-farm exists as `CaptureGuard.CheckRepeatPolicy`, driven by each `CaptureTargets.Types[name].RepeatPolicy` — **but every shipped type currently sets `RepeatPolicy = "Unlimited"`, by explicit design decision**, so this protection is off. Re-enabling it for a given target type is a one-line config flip (`RepeatPolicy = "Cooldown"`), not a re-implementation. Accepted tradeoff, not an oversight: a Strong shot every 0.5s on one target is ~120,000 XP/min.
4. **No remote accepts an amount.** `RewardService` lives in `ServerScriptService`, unreachable from the client. `ShotFeedback` is strictly outbound.
5. **Argument sanity.** `origin` and `direction` must be finite; reject NaN/inf before raycasting.
6. **Subject validity.** `RewardService.AwardFromCapture` re-resolves the subject via `CaptureTargets.Resolve` (not trusting the caller's `targetType`) and confirms it's still a descendant of `workspace`, closing the raycast-to-award race where a subject is destroyed or detagged in between.
7. **Roll integrity (Objective payouts).** The `0.3–0.4` multiplier is generated server-side in `RewardCalculator`'s `FlatRoll` strategy and only ever reported to the client, never accepted from it.
8. **Persistence integrity.** `RewardStore` tracks a per-player session state (`Loading` / `Ready` / `Failed`) and **refuses to save anything but a `Ready` session**. A failed read is therefore never mistaken for a new player, so a DataStore outage can't overwrite stored totals with zeros. Writes use `UpdateAsync`, merging into the stored record rather than replacing it. Save on leave, on autosave, *and* `BindToClose` (concurrently, to fit the shutdown budget).
   **Known gap — no session locking.** Two servers holding the same player (fast rejoin / server hop) can still clobber each other last-write-wins. The destructive failure mode is closed; this one is not. Doing locking properly (job-id ownership, staleness/steal thresholds, heartbeat) is its own task, and adopting a proven library beats hand-rolling it.
9. **Anomaly logging.** `RewardService.Grant` warns above a per-minute XP threshold — cheap, and the first signal that something above is wrong. Retune this threshold now that unlimited repeat farming is a legal, accepted posture, or it becomes noise.

---

## Build order

| # | Milestone | Verifiable by |
|---|---|---|
| **0** | This document | review |
| **1** | `RewardTypes` + `CurveFactory` + three curves + `DistanceBandLabels`. Pure data and pure functions, zero wiring. | `execute_luau` |
| **2** | `RewardCalculator` + empty `RewardModifiers` registry | `execute_luau`, all spec examples exact |
| **3** | `RewardLedger` + leaderstats; `PlayerCurrency` and `EndGame` delegate to it. **No award path yet.** | join, inspect `leaderstats`; run `EndGame` |
| **4** | `CaptureGuard` — origin check, quality downgrade, per-subject cooldown. **Hardening before any payout.** | spoofed-origin call must be rejected |
| **5** | Wire `CameraShotHandler` → `RewardService.AwardFromCapture`; richer `ShotFeedback` payload | in-game shot, leaderstats increment |
| **6** | Client display: `ShotFeedbackHandler` + `FloatingShotText` | Play mode, screenshot |
| **7** | `RewardStore` — XP persists across rejoin; Score does not | rejoin test |
| **8** | *(later)* first real modifier, to prove the seam | — |

Phases 1–3 change nothing a player can see. Step 4 precedes step 5 deliberately.

---

## Verification

**Curves and calculator in isolation** (`execute_luau`, before any wiring):

| Quality | Meters | Expected mult | XP | Score | Why this case |
|---|---|---|---|---|---|
| Strong | 10 | 1.0 | 1000 | 200 | spec example |
| Strong | 22 | 0.9 | 900 | 180 | spec example |
| Weak | 47 | 0.7 | 420 | 70 | spec example — **catches the `math.floor` 419 bug** |
| Strong | 120 | 0.5 | 500 | 100 | spec example, clamp active |
| Strong | 0 | 1.0 | 1000 | 200 | zero-distance edge |
| Strong | 15 | 0.9 | 900 | 180 | **the ambiguous boundary** — exclusive upper bound |
| Strong | 14.999 | 1.0 | 1000 | 200 | just inside tier 0 |
| Strong | 75 | 0.5 | 500 | 100 | exact point the clamp engages |
| Weak | 1000 | 0.5 | 300 | 50 | far beyond clamp |

**Leaderstats (phase 3):** join → `XP` and `Score` exist at 0 next to `Cash`. Run `EndGame.ClearPlayerTools` → `Score` and `Cash` reset to 0, `XP` **unchanged**.

**Anti-exploit (phase 4)** — all must be rejected or downgraded:
- `StrongCameraShot` with an origin next to the GreyCube while the character stands 100 studs away → rejected
- `StrongCameraShot` while the character is visibly moving → awarded at **Weak** rates
- same GreyCube photographed twice inside `SubjectCooldownSeconds` → second shot awards nothing
- `direction` of NaN → rejected, no error spam

**End-to-end (phases 5–6):** spawn the GreyCube via `Workspace.GreyCubeSpawnButton`, photograph from inside 15 m and from ~25 m, and confirm the on-screen label, meters, XP and Score agree with the table — and that leaderstats increase by *exactly* the displayed amounts.

**Regression:** the miss path still shows "Missed", awards nothing, and writes no ledger entry.

**Persistence (phase 7):** earn XP, leave, rejoin → XP restored, Score at 0. Requires Studio API Services enabled for DataStore access.
