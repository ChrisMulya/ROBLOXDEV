# Photo Scoring Blueprint

Design/architecture plan for distance-in-meters and the photo points system. No implementation yet — this is the contract the build is written against.

## The core idea

Distance already exists, is already computed server-side, and is already sent to the client. What's missing is a **unit**, a **score**, and a **place for the score to land**. Keep those three in three different places, or every future scoring factor (rarity, framing, night-time) means editing the shot handler again.

| What varies | Lives in | Adding to it costs |
|---|---|---|
| **The stud↔meter constant** | `Shared/Units` | one number |
| **How distance becomes points** | `PhotoScoring.Config` band table | one table row |
| **Extra score factors** (rarity, framing…) | `result.multipliers` list | one entry, no signature change |
| **Where points land** (Score/XP/Cash) | `PlayerRewards.Award` | one branch, in one file |

Each of these mirrors a pattern already proven in this codebase — `Shared/Trove` and `Shared/Cooldown` for the util, `CameraStats.Stats` and `MonsterStats.Stats` for the data table, `sessionTrove:Add(...)` for the additive list, `CameraInventory.Give` for the single owner. No new concepts.

---

## Contract 1 — Units

```lua
Units.STUDS_PER_METER = 3
function Units.StudsToMeters(studs: number): number   -- TODO
```

**The rule: convert at the boundary, never at the source.** Roblox raycasts, `Humanoid.WalkSpeed`, and every `MonsterStats` field (`DetectRadius`, `LoseInterestDist`, `AttackReach`) are studs and must stay studs. Meters appear in exactly two places:

1. What a player reads on screen.
2. What a designer authors in the scoring band table.

Converting any earlier silently corrupts physics and monster tuning.

**Naming convention — enforce this.** Every distance variable carries its unit: `distanceStuds`, `distanceMeters`. The current bare `distance` in `PhotoCapture.luau` is precisely how unit bugs get in, and it gets renamed in step 1.

*(For the record: Roblox's own rough convention is ~0.28 m/stud, i.e. ≈3.57 studs/m. This project uses a clean 3:1 because it's easier to reason about. The point of centralizing the constant is that switching is a one-line change.)*

---

## Contract 2 — Scoring

`ReplicatedStorage/Modules/Camera/PhotoScoring.luau` — in `ReplicatedStorage`, not `ServerScriptService`, for the same reason `CameraStats` is: the client needs the band labels to render results. **The server stays authoritative** — it computes the award; the client only renders what it is told.

```lua
PhotoScoring.Score(context) -> result
    context = { distanceStuds, subject, shotType, cameraId }
    result  = {
        meters,        -- number, for display
        band,          -- { Label = "Point Blank", ... }
        basePoints,    -- from the band, before multipliers
        multipliers,   -- { { Name = "ShotType", Value = 0.5 }, ... }
        totalPoints,   -- basePoints * product(multipliers), rounded
    }

function PhotoScoring.ResolveBand(meters: number)  -- TODO
function PhotoScoring.Score(context)               -- TODO
```

Bands authored in **meters**, nearest-first. Upper bound is **inclusive** — a shot at exactly 9 studs is 3.0 m and scores Point Blank, not Close.

| Band | Max meters | Max studs | Points |
|---|---|---|---|
| Point Blank | 3 | 9 | 100 |
| Close | 6 | 18 | 60 |
| Mid | 12 | 36 | 30 |
| Far | 25 | 75 | 10 |
| *(beyond)* | — | — | `MinPoints` = 5 |

```lua
PhotoScoring.Config.ShotTypeMultiplier = { Strong = 1.0, Weak = 0.5 }
```

Weak shots are the ones taken while moving (see `CameraStability`), so they pay half. This is what finally gives the existing stability system economic teeth — right now Strong vs Weak only changes raycast range.

**Why discrete bands, not a continuous falloff curve:** in a photography game the *rating label* is itself the feedback — "POINT BLANK!" landing on screen is the reward, not just the number. Bands also tune by feel rather than by fiddling with exponents. Keep the lookup isolated in `ResolveBand(meters)` so swapping in a curve later replaces one function and touches no callers.

### Known bias: distance is measured to the hit point

`PhotoCapture.Fire` measures `(result.Position - origin).Magnitude` — the **raycast hit surface**, not the creature's center. Deliberate choice, but it has a consequence worth recording:

> A large monster's near face scores closer than its far face, so **physically bigger creatures are systematically easier to score on**, and shooting an outstretched limb beats shooting the body.

Harmless for the current single 4×4×4 GreyCube. Revisit when monster sizes actually vary. The fix is one line confined to `PhotoCapture.Fire` — measure to `subject:GetPivot().Position` instead — and `GetPivot()` works on both a `Model` and a lone `BasePart`, so it stays correct wherever `CanCapture` ends up being tagged.

---

## Contract 3 — Reward routing

```lua
PlayerRewards.Award(player, { Score = n })   -- TODO
```

The single sink where "which stat does this number land in" is decided. Adding XP later is one branch here, not an edit to the shot handler.

`Score` is a new `IntValue` created alongside `Cash` in `PlayerCurrency.legacy.luau`'s `onPlayerAdded`. **`Cash` stays purely the shop currency** (spent by `ShopFillSlot.PurchaseItem`, seeded to `PlayerStats.StartingCash` by `StartGame`).

**Open design question, deliberately deferred:** `EndGame.ClearPlayerTools` currently zeroes `Cash`. That function is the natural seam for a future end-of-night **Score → Cash quota conversion** (the night-clock framing in `MONSTERS.md`). Until that exists, `Score` simply resets there alongside `Cash`.

---

## ⚠ Security — this must land before the payout

`origin` is **client-supplied**. `CameraSession.Capture` sends `workspace.CurrentCamera.CFrame.Position` over `StrongCameraShot`/`WeakCameraShot`, and `CameraShotHandler.handleShot` trusts it as the raycast start.

Today that is a cosmetic exploit. **The moment distance drives points it becomes an economy exploit** — a modified client reports an origin one stud from the monster and farms Point Blank from across the map. Same family as the already-documented Strong/Weak remote-choice gap, but now with money attached.

**Minimum fix:** server-side, reject the shot if `origin` is further than ~10 studs from the character's `Head` (R15 rig, confirmed present). Cheap, no gameplay change, closes the worst of it. The full fix — deriving `origin` server-side entirely — is a larger change that slightly desyncs from the true first-person camera and isn't required yet.

**Order matters: this ships before or with the reward wiring, never after.** Shipping scoring first and hardening later means shipping a live exploit.

---

## Files

**New**
| File | Job |
|---|---|
| `ReplicatedStorage/Modules/Shared/Units.luau` | the stud↔meter constant, one function |
| `ReplicatedStorage/Modules/Camera/PhotoScoring.luau` | band table + `Score()` |
| `ServerScriptService/GameService/Player/PlayerRewards.luau` | the single reward sink |

**Modified**
| File | Change |
|---|---|
| `GameService/Camera/PhotoCapture.luau` | rename `distance` → `distanceStuds` |
| `GameService/Camera/CameraShotHandler.legacy.luau` | origin check, scoring call, award, richer `ShotFeedback` payload |
| `GameService/Player/PlayerCurrency.legacy.luau` | add the `Score` IntValue |
| `Modules/Camera/FloatingShotText.luau` | room for the score line |
| `StarterPlayerScripts/ShotFeedbackHandler` | render `POINT BLANK · 4.2m · +100` |

> `ShotFeedbackHandler` is a `StarterPlayer` LocalScript — it has **no local file mirror** and must be read/edited directly via Studio tooling. See lesson 11 in `MAINHANDOFF.md`.

---

## Build order

1. **`Shared/Units` + rename `distance` → `distanceStuds`.** Pure refactor, zero behavior change.
2. **`PhotoScoring` standalone.** No wiring — unit-testable in isolation immediately.
3. **Origin validation in `CameraShotHandler`.** The hardening, before any payout exists.
4. **Wire scoring into the handler.** Payload gains `meters`, `points`, `band`.
5. **Client display.** First visible result — meters and score on screen.
6. **`PlayerRewards` + `Score` leaderstat.** The actual payout.

Steps 1–2 are verifiable before anything player-facing changes. Step 3 precedes step 6 deliberately.

---

## Verification

**Scoring in isolation** (`execute_luau`) — feed known stud values, assert meters and points:

| Input | Expected meters | Expected band |
|---|---|---|
| 0 studs | 0.0 m | Point Blank |
| 9 studs | 3.0 m | Point Blank *(inclusive boundary)* |
| 10 studs | 3.33 m | Close |
| 30 studs | 10.0 m | Mid |
| 300 studs | 100.0 m | *(beyond)* → `MinPoints` |

**Shot type:** same distance, still vs moving, must differ by exactly the `ShotTypeMultiplier` ratio.

**In-game:** spawn the GreyCube via `Workspace.GreyCubeSpawnButton`, photograph from each band, and confirm the band label, the meters, and the points all agree — and that `Score` increments by *exactly* the number displayed.

**Exploit check:** fire `StrongCameraShot` via `execute_luau` with a spoofed origin next to the monster while the character stands far away. Must be rejected.

**Regression:** the miss path still shows "Missed" and awards nothing.

---

## What this unlocks

- **`MonsterStats` gains a `PhotoValue`/`Rarity` field** — drops straight into `result.multipliers` with no change to `Score()`'s signature or any caller.
- **`Behavior.OnPhotographed` finally gets implemented.** `MONSTERS.md` specifies it as `OnPhotographed(agent, player, shotType)`; this work should widen it to carry the full `scoreResult`, since the scoring call has already resolved the subject and its agent. A Screamer that alerts the map when photographed becomes a few lines in `Behaviors/`.
