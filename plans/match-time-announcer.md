# Blueprint — Match Time Announcer (countdown + 3 AM enrage)

Status: **Plan only. Nothing implemented.**
Mode: Planning (read-only). Audit performed 2026-08-11.
Companion doc: `plans/responsive-hud.md` (the HUD scaling system this reuses — referenced, not restated).

---

## Context

The HUD currently shows a match-time bar with the current in-game hour, and nothing else
time-related. Two moments in the match have no UI at all:

- **The opening hour (6 PM → 7 PM)** is the fastest segment on the schedule — 60 real
  seconds versus 75 s/hr for everything after — and it is the window before monsters turn
  aggressive (`MatchPhases.Night` at hour 19 flips `MonstersAggressive` true). Players get
  no signal that the grace period is ending.
- **3 AM (hour 27)** is when `MonsterEvolution` applies the `Witching` tier: stage-2
  WalkSpeed goes 24 → 31.2, deliberately un-clamped so the monster outruns a sprinting
  player, and `PatrolPauseChance` drops to 0 permanently. Today the only cue is the time
  bar turning red — a colour change most players will not read as "the monster just got
  faster than you."

This adds a single Announcer text line directly beneath the time bar covering both. The
hard constraint: **it must not introduce a second clock.** The match clock is a
sample-don't-accumulate design (server and client run identical `MatchTimeMath` over the
same replicated anchors, so they provably cannot drift), and the announcer must be one
more sample of that same clock, never an independent timer.

Three decisions were confirmed before writing this:

1. **3 AM message duration** — timed banner, ~6 real seconds, then blank.
2. **Font** — `Enum.Font.SpecialElite` (distressed typewriter).
3. **Trigger** — client-derived from the existing replicated anchors; no new remote, no
   new server event.

---

## 1. Existing time-cycle architecture — findings

### 1.1 The clock is derived, not streamed

`MatchTimeReplicator` writes **five attributes once** on `ReplicatedStorage.MatchInfo` at
match start and clears them at match end:

```
MatchScheduleId, MatchTimeStartedAt, MatchTimeEndsAt, MatchTimeAnchorAt, MatchTimeAnchorHour
```

There is **zero per-second network traffic**. `MatchTimeClient` subtracts locally against
`workspace:GetServerTimeNow()`. This is the single most important property for this
feature: **anything derivable from those anchors is free, exact, and automatically correct
for late-joiners and rejoins** — a player who joins at 6:30 PM computes the same countdown
value as everyone else, with no catch-up logic.

### 1.2 Hours are a continuous unwrapped scale

18 = 6 PM, 19 = 7 PM, 24 = midnight, **27 = 3 AM**, 30 = 6 AM. `% 24` is legal in exactly
two places (`MatchTimeMath.FormatHour`, `MatchTimeLighting`). `GetHour()` returns a
**float** on that scale, or **`nil`** when the clock is not running — `nil` is the
contract and must never be coerced to 0.

### 1.3 Seconds-per-hour is per-segment, not global

`MatchSchedule.Schedules.Default`:

```lua
StartHour = 18, EndHour = 30,
Segments = {
    { UntilHour = 19, SecondsPerHour = 60 },  -- 6 PM -> 7 PM
    { UntilHour = 30, SecondsPerHour = 75 },  -- 7 PM -> 6 AM
}
```

Total 60 + 825 = **885 real seconds**. `Debug` is a single 3 s/hr segment (36 s total).
Which one runs comes from `MatchConfig.Get(modeId).ScheduleId`, currently `"Default"`.

**This is what makes the countdown configurable for free**: the 6 PM → 7 PM window is
exactly `MatchTimeMath.HourToReal(schedule, 19)` real seconds. Retune `SecondsPerHour` and
the countdown duration follows with no code change.

### 1.4 The conversion primitives already exist and are pure

`MatchTimeMath` (stateless, shared verbatim by server and client):

```lua
MatchTimeMath.TotalRealSeconds(schedule): number
MatchTimeMath.RealToHour(schedule, realSeconds): number  -- clamps to [StartHour, EndHour]
MatchTimeMath.HourToReal(schedule, hour): number         -- inverse; clamps to [0, Total]
MatchTimeMath.FormatHour(hour): string                   -- "3 AM"; the only legal % 24
```

`HourToReal` is the whole feature. There is **no `MM:SS` formatter** anywhere, but none is
needed — the countdown is a bare integer.

### 1.5 The client already ticks; it does not need a new loop

`MatchTimeHudController` runs a `Heartbeat` accumulator at `TICK_INTERVAL = 0.1`, gates on
`MatchStates.ShowsMatchTime(state)` (true for `Playing` only), reads
`GetProgress`/`GetHourText`/`GetHour`, and calls `MatchTimeHud.Update(...)` or
`MatchTimeHud.Hide()`. **Everything client-side polls; there is no client hour-change
event and no MatchTime entry in `Remotes.ALL_NAMES`.**

The announcer rides this existing tick. That satisfies "no second timer" literally — no
new `Heartbeat`, `RunService`, `task.delay`, or `while` loop is introduced anywhere.

### 1.6 `MatchTimeEvents` exists but is server-only

A real monotonic-cursor hour dispatcher (`Register(name, atHour, fn)` / `Dispatch` /
`Reset`), with `ServerRole.AssertGameServer()`. **The only registration in the repo is
`MonsterEvolution` at hour 27.** It has no client leg.

Deliberately not used here: routing 3 AM through it would need a new remote in
`Remotes.ALL_NAMES` plus a fire-and-forget broadcast that a late-joiner misses. Deriving
from hour ≥ 27 client-side costs nothing and is correct for every join timing. Both paths
read the same clock, so the announcer and `MonsterEvolution` stay synchronised by
construction — they are two samples of one clock, not two schedules to keep in step.

### 1.7 Existing enrage semantics

There is no "Enrage"/"Rage" system by that name. The mechanical event is
`Configs/Monster1.luau`:

```lua
Evolution = { Tiers = { Witching = { AtHour = 27, Stats = {...}, Stacks = false } } }
```

Applied by `MonsterEvolution` / `Components/Evolution.luau`, which sets the replicated
model attribute `EvolutionTier` and fires `instance.bus:Fire("Evolved", ...)`. **It is
never removed** — the enraged state runs 3 AM → match end. `plans/EvolutionPlan.md` is
marked PARKED but the Stats-only half shipped and is live.

**No display duration for it exists anywhere.** That was the flagged decision; resolved as
a ~6 s banner (§6).

### 1.8 Related UI facts

- `UIBuilder.CreateScreenGui`'s comment block **is** the DisplayOrder registry.
  `MatchTimeGui` is 20. **This plan adds no ScreenGui, so the registry is untouched.**
- `MatchTimeGui` sets `KeepDuringCamera = true`, exempting it from `CameraSession`'s
  `hideOtherGuis` sweep. The announcer inherits this by living in the same ScreenGui —
  correct, since a camera-raised player is exactly who needs to know the monster sped up.
- Only four fonts exist repo-wide: `GothamBold`, `GothamMedium`, `Gotham`, `Code`. No
  `FontFace`, no `Font.new`, no RichText.
- `UITheme.Colors.Danger = RGB(255, 92, 92)` exists. There is no dark red.
- The one transient-message precedent is `Shop/PurchaseNotification.luau` (build, tween,
  destroy). Not reused — it self-destructs per message and builds its own ScreenGui, the
  opposite of a persistent dirty-checked HUD line.

---

## 2. Announcer state / transition logic

One **pure function** in a new `MatchAnnouncerState.luau`, mirroring `MatchTimeMath`'s
stateless/testable role. It owns no instances, reads no services, and holds no state:

```
MatchAnnouncerState.Resolve(schedule, elapsedReal: number) -> (text: string?, color: Color3?, font: Enum.Font?)
```

Returning `nil` means blank. Constants live at the top of that module:

```lua
local COUNTDOWN_TO_HOUR   = 19   -- 7 PM
local ENRAGE_HOUR         = 27   -- 3 AM
local ENRAGE_TEXT         = "The Creature is Enraged"
local ENRAGE_SECONDS      = 6    -- real seconds the banner stays up
local RED_THRESHOLD       = 10   -- countdown value at/below which text turns red
```

Resolution order:

1. `countdownEnd = HourToReal(schedule, COUNTDOWN_TO_HOUR)`
   If `elapsedReal < countdownEnd`:
   `remaining = math.ceil(countdownEnd - elapsedReal)` → text `tostring(remaining)`,
   colour `Danger` if `remaining <= RED_THRESHOLD` else `Text`, font Gotham Bold.
2. `enrageStart = HourToReal(schedule, ENRAGE_HOUR)`
   If `enrageStart <= elapsedReal < enrageStart + ENRAGE_SECONDS`:
   text `ENRAGE_TEXT`, colour `DangerDeep`, font `SpecialElite`.
3. Otherwise `nil` — blank.

**The banner window is derived, not timed.** Because it is expressed as a real-seconds
range against `elapsedReal`, no `task.delay` is needed, a player joining 4 s after 3 AM
correctly sees the final 2 s, and the window survives a schedule retune.

`ENRAGE_TEXT` being a module constant satisfies "keep the exact text configurable" — the
string changes without touching any logic.

## 3. Exact 6 PM → 7 PM countdown behaviour

`displayed = math.ceil(countdownEnd - elapsedReal)`, blank once it reaches 0.

Let `E` = elapsed real seconds since match start, `D` = `HourToReal(schedule, 19)` = 60 on
Default. At 60 s/hr, one game minute is exactly one real second, which is why the request's
game-clock examples and a real-seconds countdown coincide.

| E (real s) | In-game | `D - E` | `ceil` | Shown | Colour |
|---|---|---|---|---|---|
| 0 | 6:00 PM | 60.0 | 60 | `60` | normal |
| 0 < E < 1 | 6:00 PM | 59.x | 60 | `60` | normal |
| 1 | 6:01 PM | 59.0 | 59 | `59` | normal |
| 49 | 6:49 PM | 11.0 | 11 | `11` | normal |
| **50** | **6:50 PM** | **10.0** | **10** | **`10`** | **red** |
| 59 | 6:59 PM | 1.0 | 1 | `1` | red |
| 59 < E < 60 | 6:59 PM | 0.x | 1 | `1` | red |
| **60** | **7:00 PM** | **0.0** | **0** | **blank** | — |

**Off-by-one resolution.** `ceil` is the correct rounding, and the boundaries are
half-open: each integer is displayed for exactly one real second, `[E, E+1)`. `60` appears
at the instant of 6:00 PM and `1` vanishes at the instant of 7:00 PM, giving exactly 60
distinct values over exactly 60 seconds. `floor` would show `59` first and stick on `0` for
a second; rounding would halve the first and last steps. Blank is `ceil <= 0`, i.e. the
countdown is gone the moment `elapsedReal` reaches `countdownEnd`, not one tick later.

The 0.1 s tick samples this ~10× per displayed value; a dirty-check on the integer means
the label is written **once per second** (§9).

**Configurability.** The start value is `ceil(HourToReal(schedule, 19))`, so it is 60 on
Default and 3 on Debug automatically. Nothing hardcodes 60.

## 4. Final-10-second red state

Purely a property of the already-computed integer: `remaining <= RED_THRESHOLD`. No second
timer, no separate threshold clock, no extra branch in the tick — the colour is returned by
the same `Resolve` call that returns the text. Red is `UITheme.Colors.Danger`
(RGB 255, 92, 92), which already exists and reads as a warning against the dark HUD.

Presentation before that is unchanged: `UITheme.Colors.Text` (white), Gotham Bold.

**Accepted consequence on fast schedules:** under `Debug` (3 s/hr) the countdown is only 3
values long, so all of them are ≤ 10 and the whole countdown renders red. This is correct
under the stated rule ("the final 10 seconds"), not a bug — if the countdown is shorter
than 10 s, every second of it *is* a final second. Flagged so it is not mistaken for one
during testing.

## 5. 7 PM → 3 AM blank behaviour

`Resolve` returns `nil` for this entire span. The announcer sets `Visible = false` and
**writes nothing else**.

Three properties the request asked for, each structurally guaranteed rather than
maintained by discipline:

- **No placeholder text** — `Visible = false`, not `Text = ""`.
- **No stale countdown** — the countdown branch is a pure function of `elapsedReal`, so
  there is no retained last-value to go stale.
- **No unnecessary updates while blank** — the dirty-check (§9) compares against the last
  *applied* state, so across the ~500 real seconds from 7 PM to 3 AM the label receives
  exactly **one** property write (the `Visible = false` at 7 PM) despite ~5000 ticks.

Because the announcer is inside a `UIListLayout` (§7), `Visible = false` also **collapses
its row entirely** — the blank announcer occupies zero vertical pixels rather than
reserving dead space under the bar.

## 6. 3 AM "The Creature is Enraged"

- **Trigger:** `elapsedReal >= HourToReal(schedule, 27)`. Same clock as
  `MonsterEvolution`'s hour-27 registration, so the message and the stat change land
  together by construction.
- **Duration:** `ENRAGE_SECONDS = 6` real seconds, then blank. This was the flagged
  planning decision — the mechanical enrage is *permanent* (3 AM → 6 AM, ~225 s), so a
  status-line reading would pin dark red text under the bar for a quarter of the match.
  Confirmed as an announcement, not a status indicator.
- **Text:** `ENRAGE_TEXT` constant.
- **Font:** `Enum.Font.SpecialElite` — the first non-Gotham display font in the repo.
- **Colour:** a new additive `UITheme.Colors.DangerDeep` (suggested RGB 138, 18, 18).
  Adding a token is precedented: `UITheme`'s own comment records the DeathScreen additions
  as *"Purely additive -- the three values above are untouched, so nothing that already
  reads them changes look."* This is the same move and does **not** touch the palette
  sign-off blocker in `docs/Planned.md:141`, which concerns *re-colouring existing UI*.
- **Legibility:** `TextStrokeTransparency = 0.5`, matching `Hudcontroller`'s bar labels.
  Dark red on a dark night scene needs the stroke.

**Visual collision to be aware of:** `MatchPhases.BarColors.Dawn` already turns the bar
red at hour 27, so at 3 AM the bar and the announcer both go red simultaneously. Whether
that reads as cohesive emphasis or as muddy is a judgement call best made in Studio —
`DangerDeep` is deliberately much darker than the bar's RGB(224, 74, 74) to keep them
distinguishable.

## 7. UI hierarchy / layout changes

The announcer must sit beneath the bar **and stay there at every scale**. Rather than
computing its position from the bar's scaled height, make the layout structural.

**Current:**
```
MatchTimeGui  (DisplayOrder 20, KeepDuringCamera)
└─ MatchTimeHolder   [UIScale attached here]
   ├─ UICorner, UIStroke, Fill, Hour (+UITextSizeConstraint)
```

**Proposed:**
```
MatchTimeGui  (DisplayOrder 20, KeepDuringCamera)   -- unchanged
└─ MatchTimeColumn (Frame)                     [NEW]
   ├─ UIScale                                  [MOVED here from MatchTimeHolder]
   ├─ UIListLayout (Vertical, Center, Padding 6)[NEW]
   ├─ MatchTimeHolder (LayoutOrder 1)          -- contents unchanged
   │  ├─ UICorner, UIStroke, Fill, Hour
   └─ AnnouncerLabel (LayoutOrder 2)           [NEW]
      └─ UITextSizeConstraint                  [NEW]
```

`MatchTimeColumn` takes over the holder's anchoring: `AnchorPoint = (0.5, 0)`, the existing
`Position`, `BackgroundTransparency = 1`, `AutomaticSize = Y`, `Size = fromOffset(BAR_WIDTH, 0)`.
`MatchTimeHolder` keeps `Size = fromOffset(BAR_WIDTH, BAR_HEIGHT)` and drops its own
anchor/position (the layout places it).

Why this shape:

- **One `UIScale` covers both.** Moving the attach from `MatchTimeHolder` to
  `MatchTimeColumn` is a **required** edit — leaving it on the holder would scale the bar
  and not the announcer.
- **The 6 px gap is inside the `UIScale`**, so the spacing scales with everything else.
  "Beneath the bar at every resolution" becomes a structural property, not arithmetic that
  can drift.
- **`UIListLayout` skips non-visible children**, so a blank announcer costs zero vertical
  space (§5).
- The column grows **downward** from the anchor, so adding the announcer never moves the
  bar.

`AnnouncerLabel`: `Size = fromOffset(BAR_WIDTH, 20)`, `BackgroundTransparency = 1` (no
panel — saves vertical space and keeps gameplay visible), `TextSize = 20`,
`TextStrokeTransparency = 0.5`, `UITextSizeConstraint` Min 10 / Max 24.

## 8. Responsive sizing / positioning

No new responsive machinery. The announcer inherits the system in
`plans/responsive-hud.md` wholesale:

- **Scaling** — inherits `MatchTimeColumn`'s single `UIScale`, driven by
  `UIScaleController` (`clamp(min(vx/1920, vy/1080) × densityFactor, minScale, MAX_SCALE)`;
  `MIN_SCALE_POINTER = 1.0`, `MIN_SCALE_TOUCH = 0.62`, `MAX_SCALE = 1.35`).
  **`UIScaleController.Attach` is not called again** — one attach on the column covers the
  whole widget, so bar and announcer can never scale differently.
- **Mobile** — 0.62× → ~12 px announcer text, floored by `UITextSizeConstraint.MinTextSize = 10`.
  A single line with no background panel is the cheapest possible vertical footprint, and
  it collapses to zero height for the ~500 s it is blank.
- **PC** — 1.0× floor, so it never renders below the authored 20 px.
- **Aspect ratios** — `UIScale` cannot distort proportions, and the column is centre-anchored
  like the bar, so ultrawide/16:10/tablet all inherit the bar's existing behaviour.
- **Safe area** — the announcer is inside `MatchTimeGui`, which uses the implicit
  `CoreUISafeInsets`. See §12 for the interaction with the current negative Y offset.

## 9. Event / data flow

```
MatchTimeService (server, 0.25s sample)
  └─ MatchTimeReplicator: writes 5 anchor attributes ONCE at match start
         │  (no per-second traffic; cleared at match end)
         ▼
ReplicatedStorage.MatchInfo  ── attributes ──▶  MatchTimeClient (read-only)
                                                   │ GetElapsedReal()  [NEW]
                                                   │ GetSchedule()     [NEW]
                                                   ▼
MatchTimeHudController  (EXISTING 0.1s Heartbeat tick — no new loop)
   ├─ MatchTimeHud.Update(progress, hourText, hour)        (unchanged)
   └─ MatchAnnouncerState.Resolve(schedule, elapsedReal)   [NEW, pure]
            └─▶ MatchTimeAnnouncer.Update(text, color, font) | .Hide()
```

`MatchTimeClient` gains two read-only accessors, the natural home since both are pure
functions of the anchors it already reads:

```lua
function MatchTimeClient.GetElapsedReal(): number?   -- anchorReal + (GetServerTimeNow() - anchorAt)
function MatchTimeClient.GetSchedule()               -- MatchSchedule.Get(anchors.scheduleId)
```

Both return `nil` with no anchors, matching every existing getter's contract.

*Optional, not required:* `GetHour()` could then be expressed as
`RealToHour(schedule, GetElapsedReal())`, deduplicating three lines and making the two
provably consistent. Called out as a judgement call, not folded into scope.

**Dirty-checking** mirrors `MatchTimeHud`'s existing pattern (it already dirty-checks hour
text and fill colour). `MatchTimeAnnouncer` retains `lastText` / `lastColor` / `lastFont`
and writes only on change: ~60 writes during the countdown, 1 at 7 PM, 1 at 3 AM, 1 six
seconds later. Roughly **63 property writes across an entire 885-second match**, against
~8850 ticks.

## 10. Files expected to change

Mirrored across **both places** — the repo treats `diff -rq Lobby Map0_Test` as a health
check, and every MatchTime file is currently byte-identical except `MatchTimeHud.luau`'s
`holder.Position` (see §15 #3).

**New (×2):**
- `{Lobby,Map0_Test}/ReplicatedStorage/Modules/MatchTime/MatchAnnouncerState.luau` — pure `Resolve`
- `{Lobby,Map0_Test}/ReplicatedStorage/Modules/MatchTime/MatchTimeAnnouncer.luau` — pure UI, `Update`/`Hide`/`Attach`

**Modified (×2 each):**
- `.../MatchTime/MatchTimeClient.luau` — add `GetElapsedReal()`, `GetSchedule()`
- `.../MatchTime/MatchTimeHud.luau` — insert `MatchTimeColumn` + `UIListLayout`, **move the
  `UIScaleController.Attach` call from the holder to the column**, mount the announcer via
  `MatchTimeAnnouncer.Attach(column)` in `ensureBuilt()`
- `.../MatchTime/MatchTimeHudController.luau` — drive the announcer in the existing tick,
  including the two early-return paths (not `Playing`, anchors absent) which must hide it
- `.../Modules/UI/UITheme.luau` — one additive `Colors.DangerDeep`

**Not modified:** every server file (`MatchTimeService`, `MatchTimeEvents`,
`MatchTimeReplicator`, `MatchTimeLighting`, `SunriseEndHook`), `MatchSchedule`,
`MatchTimeMath`, `MatchPhases`, `MonsterEvolution`, `Components/Evolution.luau`,
`Monster1.luau`, `Remotes.luau`, `UIBuilder.luau`.

**No new ScreenGui**, so `UIBuilder`'s DisplayOrder comment-registry is untouched.

## 11. Dependencies

- `MatchTimeMath.HourToReal` — the core primitive. Pure, already shared server/client.
- `MatchTimeClient.GetAnchors` — the `nil`-when-not-running contract must be honoured.
- `MatchSchedule.Get` — falls back to `Default` with a warn on an unknown id.
- `UIScaleController.Attach` (`plans/responsive-hud.md`) — one call, on the column.
- `UITheme.Colors.Danger` (exists) / `.DangerDeep` (new) / `.Text`, `UITheme.Fonts.Bold`.
- `Enum.Font.SpecialElite` — built-in, no asset upload, no `FontFace` needed.
- **Load order:** all new modules are `ReplicatedStorage` ModuleScripts reached through
  `MatchTimeHudController`, which `ClientBootstrap.local.luau:36` requires **only in the
  `GameServer` branch**. The Lobby therefore never builds an announcer — the files are
  mirrored for `diff` parity but are inert there, exactly like the rest of MatchTime.

## 12. Edge cases

1. **Boundary/off-by-one** — resolved in §3. Half-open intervals, `ceil`, blank at
   `ceil <= 0`. Exactly 60 values over exactly 60 s.
2. **Late join mid-countdown** — anchors are static attributes, so `elapsedReal` is exact
   on arrival; the countdown resumes at the right number with no catch-up. Free consequence
   of deriving rather than broadcasting.
3. **Late join during the 6 s banner** — sees the remainder (join at +4 s → 2 s of banner).
   Also free.
4. **Late join after the banner expired** — sees nothing. Accepted consequence of the
   timed-banner decision; the persistent-status option was explicitly declined.
5. **Match ends / anchors cleared** — `GetElapsedReal()` returns `nil`; the controller's
   existing early-return path must call `MatchTimeAnnouncer.Hide()` alongside
   `MatchTimeHud.Hide()`. Easy to miss — there are **two** such paths.
6. **Not `Playing`** — same, gated by `MatchStates.ShowsMatchTime`.
7. **Past 6 AM** — `RealToHour` clamps at `EndHour`, but `elapsedReal` is **not** clamped
   and keeps growing. All comparisons use `elapsedReal` directly, so the long-past banner
   window stays false. No saturation bug. (Note `HourToReal` clamps its *input hour*, which
   is a constant here, so that clamp never bites.)
8. **`Debug` schedule (3 s/hr)** — countdown is 3 values, all red (§4). The 6 s banner
   spans two game hours. Both correct; called out so they aren't misread as bugs.
9. **`SecondsPerHour` retuned** — countdown duration and banner position both follow
   automatically; nothing hardcodes 60 or 885.
10. **Segment boundaries moved** — `HourToReal(19)` interpolates *inside* whichever segment
    contains hour 19, so the countdown stays correct even if the first boundary is no longer
    19.
11. **`StartHour` changed above 19** — `HourToReal(19)` returns 0, so the countdown is
    simply never shown. Degrades silently rather than showing a negative number.
12. **Negative Y offset vs safe area** — `MatchTimeGui` uses `CoreUISafeInsets`, and
    `MatchTimeHolder.Position` is currently `(0.5, 0, 0, -40)` in Map0_Test, putting the bar
    *above* the safe-area top. The announcer sits ~30 px below the bar's top, so it lands
    near the safe-area boundary — on a phone with a taller inset it may tuck under the
    topbar. **Verify case 13 specifically.**
13. **Camera raised** — the announcer inherits `KeepDuringCamera = true` and stays visible,
    which is intended.
14. **Both go red at 3 AM** — bar (`BarColors.Dawn`, hour 27) and announcer simultaneously.
    §6.

## 13. Studio verification checklist

No test runner exists. Manual, in `Map0_Test` (the Lobby never builds this).

**Countdown cases use the `Default` schedule. 3 AM cases are far faster on `Debug`** —
set `MatchConfig.Get(modeId).ScheduleId` to `"Debug"` (3 s/hr → whole match 36 s, 3 AM at
+27 s), then set it back.

| # | Test | Do | Expect |
|---|---|---|---|
| 1 | **Countdown starts at 6 PM** | Start a match, watch the first frame the bar appears | `60` beneath the bar, white |
| 2 | Counts down correctly | Watch 6:00 → 6:10 PM | `60, 59, …, 50` — one value per real second, none skipped or repeated |
| 3 | **Reaches 10 correctly** | Watch to 6:50 PM | Shows exactly `10`, not `11` or `9` |
| 4 | **Red begins at 10** | Watch the 11 → 10 transition | White at `11`, red the instant it reads `10`; stays red `10 … 1` |
| 5 | **Disappears exactly at 7 PM** | Watch the last second | `1` is the final value; blank at 7 PM. **No `0` frame** |
| 6 | **Blank 7 PM → 2 AM** | Idle through several game hours | Nothing beneath the bar; row fully collapsed, no reserved gap |
| 7 | **Appears exactly at 3 AM** | Watch hour 27 (Debug) | `The Creature is Enraged`, dark red, SpecialElite, appears as the bar turns red |
| 8 | Banner clears | Wait ~6 s after 3 AM | Blanks and stays blank to match end |
| 9 | **Config change doesn't desync** | Run on `Debug` | Countdown starts at `3` (not 60) and hits 0 exactly at hour 19 |
| 10 | **No duplicate timers** | Play → end → play again | Countdown restarts at the top; no doubled/flickering values, no second label |
| 11 | **No stale state** | End a match mid-countdown | Announcer hides with the bar immediately; nothing lingers |
| 12 | Late join | Join a match already at ~6:30 PM | Countdown shows the correct value immediately, no jump or catch-up |
| 13 | **Mobile / safe area** | Phone landscape emulation | Announcer scales with the bar, gap proportional, text legible; **check it isn't under the topbar** (§12 #12) |
| 14 | Resolutions | 1280×720, 1920×1080, 2560×1440, ultrawide | Announcer stays centred directly beneath the bar; gap scales; never drifts |
| 15 | Camera raised | Raise the camera at 3 AM | Both bar and announcer remain visible |
| 16 | Perf | Console during the blank stretch | No per-tick warnings; confirm the label isn't being rewritten while blank |

Also check `get_console_output` for `MatchPhases.Validate` / `MatchSchedule.Validate`
assertions at boot — both run from GameBoot and would surface a schedule mistake early.

## 14. Deviations from the request

1. **"Update the existing blueprint/plan only."** No announcer blueprint existed. `plans/`
   holds `EvolutionPlan.md`, `phase-12.5-profilestore-hardening.md`, and `responsive-hud.md`.
   This is a **new** document; it should land at `plans/match-time-announcer.md`. It
   *references* `responsive-hud.md` for the scaling system rather than restating it, per
   the project's "a plan file references, it does not restate" rule.
2. **"Prefer event-driven updates for hour transitions."** Partially declined, deliberately.
   `MatchTimeEvents` is server-only with no client leg, so genuinely event-driving 3 AM
   means a new remote plus late-joiner catch-up. The announcer instead rides
   `MatchTimeHudController`'s **existing** 0.1 s tick — no new timer or loop is created, and
   dirty-checking makes the update rate effectively event-driven (~63 writes per match).
   The spirit of the constraint is met; the letter is not.
3. **Countdown is in real seconds, not game minutes.** The request's examples
   (6:00 PM → 60, 6:59 PM → 1) are consistent with both readings, because at 60 s/hr one
   game minute *is* one real second. "Make the countdown duration automatically respect the
   configurable seconds-per-game-hour setting" resolves it to real seconds — under `Debug`
   the countdown is 3 values, not 60 faster ones. This is also the only reading that keeps
   "the final 10 seconds" meaningful on a fast schedule.
4. **`UITheme` gains one colour.** Strictly this is outside "don't modify the time-cycle
   system", but there is no dark red token and the additive precedent is documented in
   `UITheme`'s own header.
5. **No `MM:SS` formatter.** The countdown is a bare integer per the request's examples, so
   the absent formatter (§1.4) never becomes a gap.

## 15. Found, not fixed

1. **`MatchPhases` phase/colour tables still reference 4 PM.** `Phases.Dusk.StartHour = 16`
   and `BarColors.Evening.StartHour = 16`, but `MatchSchedule.Default.StartHour = 18` is the
   confirmed real start. `MatchPhases.Validate()` only asserts the *first* colour band
   matches the *first* phase, so this passes silently. Carried over from
   `plans/responsive-hud.md`; still unfixed, still out of scope.
2. **`MatchTimeClient.GetProgress` is linear in real time, not game hours** (documented at
   its lines 64-67), while `Default` has variable per-hour rates. The hour label does not
   advance at a constant distance along the bar. Pre-existing, cosmetic.
3. **`MatchTimeHud.luau` is the one MatchTime file that differs between places** —
   `holder.Position` is `(0.5, 0, 0, -8)` in Lobby and `(0.5, 0, 0, -40)` in Map0_Test, from
   a recent intentional edit. The repo otherwise relies on `diff -rq` parity. The hierarchy
   change in §7 should preserve each place's own offset rather than silently reconciling
   them — but the divergence is worth an explicit decision.
4. **The negative Y offset pushes the bar above the `CoreUISafeInsets` boundary** (§12 #12).
   Pre-existing for the bar; the announcer inherits the risk. Setting
   `ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets` on `MatchTimeGui` would make the
   intent explicit, but that is the same change `plans/responsive-hud.md` §14 already
   deferred.
5. **`plans/EvolutionPlan.md` is marked PARKED but its Stats-only half is live in
   production** via `Monster1.luau`'s `Evolution` block. A reader trusting the PARKED label
   would not expect a real 3 AM speed change. Documentation drift, not a code bug.
6. **`Components/Evolution.luau` warns on unimplemented tier fields**
   (`Capabilities, States, Aggression, Perception, Abilities`). If any are ever added to a
   tier config they will warn at runtime rather than fail at boot. Pre-existing.
