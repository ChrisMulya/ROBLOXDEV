# Blueprint — Responsive HUD Scaling (Cash / Match Time / Stamina)

Status: **Implemented.**
Audit performed 2026-08-11.

---

## Context

The three persistent HUD elements — Cash, the match-time cycle bar, and Stamina — are
built entirely from **raw pixel offsets**. Every dimension in all three is a literal
number of pixels (`BAR_WIDTH = 220`, `UDim2.new(0, 150, 0, 40)`, `TextSize = 12`).
Roblox renders those offsets 1:1 against `ViewportSize`, so the HUD occupies a
*fixed pixel* footprint that becomes a *large fraction* of the screen on a phone and a
*small* one on a high-resolution monitor.

The concrete symptom: on a phone in landscape the stamina bar plus the time bar plus the
cash label consume a visually dominant strip across the top of the screen, covering
gameplay in a game whose whole loop is looking at monsters through a camera. On a 1440p
or ultrawide monitor the same elements read as undersized.

The intended outcome: **one shared scale factor**, derived from available screen space and
input density, applied through a single `UIScale` per HUD root. The designed geometry,
colors, anchors and hierarchy stay exactly as they are — only the magnification changes.

Three decisions were confirmed with the user before writing this:

1. **Mechanism** — `UIScale` on each HUD root. Not a `UDim2.fromScale` rewrite.
2. **Density** — reuse the repo's existing `TouchSession.IsActive()` as a single
   multiplier folded into the scale formula, not as a branch that picks sizes.
3. **Stamina placement** — stays top-right. Scale only, no repositioning.

The match-time schedule intentionally starts at 6 PM (`MatchSchedule.Default.StartHour = 18`).
The 4 PM references in `MatchPhases`/`BarColors` are a pre-existing, separate mismatch
(see `Found, not fixed` #1) — confirmed out of scope, not touched.

---

## 1. Current UI architecture — audit findings

### 1.1 Everything is built in code

There are **no `.rbxmx` / `.rbxl` / model files anywhere** in the repo. Every GUI is
constructed with `Instance.new` at runtime. There are zero `script.Parent` GUI references
and zero `PlayerGui:WaitForChild("<StudioGui>")` lookups — `PlayerGui` is only ever a
parent target. **This is the single most important finding**: there is no Studio-instance
tree to reconcile, so the whole change is a code change, and a `UIScale` can be inserted
by the same constructor that builds the frame.

### 1.2 The three elements, side by side

| | Cash | Match Time | Stamina |
|---|---|---|---|
| File | `StarterPlayerScripts/CurrencyUI.local.luau` | `ReplicatedStorage/Modules/MatchTime/MatchTimeHud.luau` | `StarterPlayerScripts/Hudcontroller.local.luau` |
| ScreenGui | `CashGui` via `UIBuilder` | `MatchTimeGui` via `UIBuilder`, DisplayOrder 20 | `HUD`, hand-rolled `Instance.new` |
| Root object | `TextLabel` directly under ScreenGui (no frame) | `Frame` "MatchTimeHolder" | `Frame` "StatsContainer" |
| Anchor / position | none / `UDim2.new(0,10,0,10)` — top-left | `(0.5,0)` / `UDim2.new(0.5,0,0,12)` — top-centre | `(1,0)` / `UDim2.new(1,-24,0,24)` — top-right |
| Size | `UDim2.new(0,150,0,40)` | `UDim2.fromOffset(300,24)` Map0\_Test · `(320,34)` Lobby | `UDim2.new(0,220,0,26)` (18+8 spacing) |
| Text sizing | `TextScaled = true` | `TextSize = 18` fixed | `TextSize = 12` fixed, two labels |
| Inset handling | not set → `CoreUISafeInsets` (sits below topbar) | not set → `CoreUISafeInsets` | `IgnoreGuiInset = true` → `DeviceSafeInsets` |
| Theme | `UITheme` + `UIBuilder` | `UITheme` + `UIBuilder` | hardcoded colors, predates both |
| `KeepDuringCamera` | no | **yes** | **no** |

### 1.3 Responsive mechanisms currently in use

**None.** Verified absent across the entire repo:

- no `UIScale` anywhere
- no `UIAspectRatioConstraint`
- no `UITextSizeConstraint`
- no `UISizeConstraint`
- no `AutomaticSize`
- no `SafeAreaCompatibility` / explicit `ScreenInsets`
- no `GetPropertyChangedSignal("ViewportSize")` listener anywhere

The only scaling affordance in the entire HUD is `TextScaled = true` on the Cash label.
`UIPadding` / `UIListLayout` exist only in the modal panels (`DeathScreen`,
`MatchReceipt`, `CameraShelfGui`, `PlayerShop`), never in the HUD.

### 1.4 Resolution / device infrastructure that *does* exist and should be reused

| Thing | Where | Reuse as |
|---|---|---|
| `TouchSession.IsActive()` | `ReplicatedStorage/Modules/Shared/TouchSession.luau` | **the canonical device check.** Header warns: never cache the result; `TouchEnabled and not KeyboardEnabled` is wrong. `MAINHANDOFF.md` G6 is the authoritative writeup. |
| `workspace.CurrentCamera.ViewportSize` | `MobileSprintButton.local.luau:233-235`, `Modules/Camera/CameraTouchHud.luau`, `CameraViewfinder.luau` | the viewport source for the scale formula |
| `GuiService:GetGuiInset()` | `MobileSprintButton.local.luau:253` — the only use in the repo | reference only; the plan prefers `ScreenInsets` over manual inset math |
| Landscape lock | `StarterPlayerScripts/ScreenOrientationController.local.luau` — `LandscapeSensor`, re-applied via `GetPropertyChangedSignal` | **constrains scope**: phone *portrait* is not a shipping configuration |
| DisplayOrder registry | the comment block at `UIBuilder.luau:27-39` — "this comment IS the registry" | must be respected; this plan adds no new ScreenGui, so no new entry is needed |
| `UITheme` / `UIBuilder` | `ReplicatedStorage/Modules/UI/` | the existing UI framework. **Extend it. Do not create a second one.** |

### 1.5 Adoption state and its constraint on scope

`docs/Planned.md:141` — *"`UITheme`/`UIBuilder` adopted by `CurrencyUI` only … Six divergent
greys across five files … Blocked on palette sign-off. All new UI uses them from line one."*

**Consequence for this plan:** `Hudcontroller` (stamina) must consume the new scale module,
but must **not** be migrated to `UITheme` colors in this change. That migration is blocked on
a palette sign-off and would visibly recolor the bar — a visual redesign, which is explicitly
out of scope.

---

## 2. Responsive sizing strategy

### 2.1 Why `UIScale`, specifically

The three HUD elements are **fixed-proportion composites**: a bar with text overlaid, an
icon-and-value pill. Their internal proportions are the design. `UIScale` multiplies the
*rendered* size of a GuiObject and its entire descendant tree, including `TextSize`,
uniformly. Aspect ratio is structurally impossible to distort. The existing offset
geometry is kept verbatim, so the diff is "insert one instance + one attach call per HUD"
rather than "rewrite every UDim2".

### 2.2 The scale formula

`Modules/UI/UIScaleController.luau` owns one number.

```
DESIGN_BASIS   = Vector2.new(1920, 1080)   -- the resolution the current offsets were authored at
viewportFactor = min(viewport.X / 1920, viewport.Y / 1080)
isTouch        = TouchSession.IsActive()
densityFactor  = isTouch and TOUCH_DENSITY or 1.0
minScale       = isTouch and MIN_SCALE_TOUCH or MIN_SCALE_POINTER
scale          = clamp(viewportFactor * densityFactor, minScale, MAX_SCALE)
```

- **`min` of the two axis ratios** — makes ultrawide behave (height-driven, no horizontal
  balloon) and degrades any unusually tall viewport gracefully.
- **`densityFactor`** — Roblox reports the same `ViewportSize` for a 1080p phone and a
  1080p monitor, so physical size/viewing distance must come from somewhere else. One
  multiplier folded into one formula, not an `if mobile then sizeA else sizeB` branch.
  `TOUCH_DENSITY = 0.78`.
- **Two floors, not one.** `ViewportSize` is the render *window*, not the monitor — a
  windowed client, or a Studio play session with the Explorer/Properties docks open,
  reports far less than the physical resolution. A single low floor shrank a perfectly
  correct desktop HUD (caught in Studio testing at 1080p/720p). So
  `MIN_SCALE_POINTER = 1.0`: pointer clients never render below the authored pixel sizes,
  which were designed to read at 1:1, and the viewport ratio only ever scales *up*.
  `MIN_SCALE_TOUCH = 0.62` keeps the low floor where shrinking is the whole point, paired
  with each label's `UITextSizeConstraint.MinTextSize`.
- **`MAX_SCALE = 1.35`** stops 4K from rendering an oversized HUD.

### 2.3 Module surface (implemented)

```
UIScaleController.Attach(root: GuiObject) -> UIScale   -- idempotent per root
UIScaleController.Detach(root: GuiObject)
UIScaleController.Get() -> number
UIScaleController.Changed : Signal (fires on factor change)
```

Recomputation triggers, all connected in the module at load time:

- `workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")`
- `workspace:GetPropertyChangedSignal("CurrentCamera")` — reconnects the ViewportSize
  listener to the new camera on every respawn (the classic failure mode this guards
  against: scaling works until the first respawn, then goes stale).
- `UserInputService.LastInputTypeChanged` — re-evaluates `TouchSession.IsActive()` per its
  no-caching contract.

Registered roots are swept for liveness (`if not root.Parent then unregister`) on each
recompute rather than held in a weak table, since all three HUDs disable rather than
destroy their ScreenGui.

---

## 3. Hierarchy / layout changes

**Cash needed a root frame.** `UIScale` scales a GuiObject's *descendants*, so it must sit
under a container, not next to the object it scales. `CashLabel` was previously parented
directly to `CashGui` with no intervening frame. A transparent `CashHolder` Frame was
inserted carrying the anchor/position, with `CashLabel` as its child at
`UDim2.fromScale(1,1)` — matching the shape `MatchTimeHolder` and `StatsContainer` already
have. This is the only new instance in the whole change.

Anchor points stay on the same corners they were already on — `(0,0)`, `(0.5,0)`, `(1,0)` —
so `UIScale` (which scales size, not position offset) shrinks each element inward from its
existing corner/edge, which is the desired behavior for all three.

Resulting trees:

```
CashGui                          MatchTimeGui                  HUD
└─ CashHolder (Frame) [NEW]      └─ MatchTimeHolder            └─ StatsContainer
   ├─ UIScale        [NEW]          ├─ UIScale     [NEW]          ├─ UIScale   [NEW]
   ├─ UIPadding      [NEW]          ├─ UICorner                   └─ StaminaRow
   └─ CashLabel                     ├─ UIStroke                      └─ Background
                                    ├─ Fill                             ├─ Fill
                                    └─ Hour                             ├─ Label
                                                                        └─ Value
```

No ScreenGui was added or removed, so the `UIBuilder.luau:27-39` DisplayOrder registry is
untouched.

---

## 4. Cash UI changes

File: `StarterPlayerScripts/CurrencyUI.local.luau` (Lobby + Map0_Test, kept identical).

- Inserted `CashHolder` frame (§3), `BackgroundTransparency = 1`, `AnchorPoint = (0,0)`,
  `Position = UDim2.new(0, 10, 0, 10)`, `Size = UDim2.fromOffset(150, 40)`.
- `CashLabel` moved under it, `Size = UDim2.fromScale(1, 1)`, `Position = UDim2.new()`.
- `UIScaleController.Attach(cashHolder)` called inside `ensureBuilt()` — the existing
  build-once guard, so attach happens exactly once across Show/Hide cycles (preserves the
  documented fix for the double-`CashGui`/double-connection leak).
- Replaced `TextScaled = true` with a fixed `TextSize = 22` plus a `UITextSizeConstraint`
  (`MinTextSize = 12`, `MaxTextSize = 26`). `TextScaled` made glyph height a function of
  *string length* (`$7` huge, `$142850` small); a fixed size under `UIScale` scales
  uniformly, and the constraint is the floor/ceiling safety net.
- Added `UIPadding` (6px horizontal) so text doesn't touch the pill edge now that the
  background isn't sized by the text.
- No change to `showCurrencyUI`, `HideCurrencyUI`, the `leaderstats.Cash` subscription, or
  any currency logic.

## 5. Time UI changes

File: `ReplicatedStorage/Modules/MatchTime/MatchTimeHud.luau` (Lobby + Map0_Test).

- `UIScaleController.Attach(holder)` inside `ensureBuilt()`.
- Reconciled `BAR_WIDTH`/`BAR_HEIGHT` — both places now `300 × 24` (previously Lobby was
  `320 × 34`). Picked Map0_Test's value since it's the in-match place players actually see
  it in. Without this the shared scale factor produced two differently-sized HUDs depending
  on which place the player was in.
- Added `UITextSizeConstraint` to `hourLabel` (`MinTextSize = 10`, `MaxTextSize = 22`).
- `TextSize = 18` stays as the design-basis value.
- No change to `Update()`, `Hide()`, the progress/fill math, `MatchPhases` color-band
  lookup, the dirty-check pattern, `MatchTimeClient`, `MatchTimeService`, or `MatchSchedule`.
- `KeepDuringCamera = true` preserved.

## 6. Stamina UI changes

File: `StarterPlayerScripts/Hudcontroller.local.luau` (Lobby + Map0_Test, kept identical).

- `UIScaleController.Attach(container)` called immediately after `StatsContainer` is built
  (top-level script body, runs once).
- Added `UITextSizeConstraint` to both `Label` and `Value` (`MinTextSize = 9`,
  `MaxTextSize = 16`). This floor is what sets `MIN_SCALE = 0.62` — the two are tuned
  together.
- `BAR_WIDTH`/`BAR_HEIGHT`/`BAR_SPACING` stay as the design basis; `BAR_CONFIG` loop
  untouched.
- Position stays top-right at `(1, -24, 0, 24)` — preserves the `CoreGuiController`
  rationale (Roblox Health CoreGui disabled specifically because it overlapped this spot).
- Did not migrate to `UITheme` colors — blocked on palette sign-off per
  `docs/Planned.md:141`; would be a visual redesign.
- No change to `updateBar`, `PlayerRuntimeStats.Changed`, the `animated = false` decision,
  or drain/regen.

---

## 7. Mobile behavior

With `TOUCH_DENSITY = 0.78`, a phone landscape viewport of ~1280×720 yields
`min(0.67, 0.67) × 0.78 = 0.52` → clamped up to `MIN_SCALE = 0.62`.

- Stamina bar renders ≈136 × 11 px instead of 220 × 18 (~38% of former screen area).
- Time bar ≈186 × 15 instead of 300 × 24.
- Cash pill ≈93 × 25 instead of 150 × 40.

Readability is protected by `MIN_SCALE` plus each label's `UITextSizeConstraint.MinTextSize`
so text stops shrinking before the frames do.

All three elements are display-only (no `TextButton`, no `Activated`), so there are no
touch targets to preserve. The interactive touch HUDs (`MobileSprintButton`,
`CameraTouchHud`, `MobileFlashlightButton`) were **not** attached to `UIScaleController` —
shrinking a thumb target would be a regression.

Portrait is not a shipping configuration (`ScreenOrientationController` locks
`LandscapeSensor`); the formula degrades gracefully if it ever occurs but wasn't a
verification target.

## 8. PC behavior

Pointer clients scale **up only** — `MIN_SCALE_POINTER = 1.0` means the HUD is never
smaller than the authored pixel sizes, at any window size.

- **1920×1080** — factor 1.00, pixel-identical to pre-change baseline.
- **1366×768, 1280×720, any small/windowed viewport** — floored at 1.00, i.e. unchanged
  from pre-change behavior. (An earlier revision let these shrink to ~0.67–0.71 and read
  as too small in Studio; that was the bug the split floor fixes.)
- **2560×1440** — ~1.33×.
- **3840×2160** — clamped to `MAX_SCALE = 1.35`, not 2.0×.

## 9. Aspect-ratio handling

`min(vx/1920, vy/1080)` is the entire strategy; `UIScale` cannot distort proportions.
Ultrawide/super-ultrawide are height-driven (1.33× at 1440p height, same as 21:9) so the
HUD never balloons horizontally. Ultrawide horizontal *spread* between the three
independently-anchored elements is a layout concern, not scaling, and was left alone
(see Deviations).

## 10. Safe-area handling

- `CashGui`, `MatchTimeGui` — left on implicit `CoreUISafeInsets` default (unchanged).
- `HUD` (stamina) — kept `IgnoreGuiInset = true` (behaviorally equivalent to
  `DeviceSafeInsets`); renaming to the explicit enum was flagged as optional and not applied,
  to keep the diff scoped to scaling. See Deviations.
- Corner margins (`-24`, `+24`, `+10`, `+12`) were left as fixed offsets rather than scaled
  — a physical edge gap should stay roughly constant regardless of content size, and scaling
  them down would push HUD elements closer to notches on mobile.

---

## 11. Files changed

**New:**
- `Lobby/ReplicatedStorage/Modules/UI/UIScaleController.luau`
- `Map0_Test/ReplicatedStorage/Modules/UI/UIScaleController.luau`

**Modified:**
- `Lobby/StarterPlayerScripts/CurrencyUI.local.luau` + `Map0_Test/` twin
- `Lobby/StarterPlayerScripts/Hudcontroller.local.luau` + `Map0_Test/` twin
- `Lobby/ReplicatedStorage/Modules/MatchTime/MatchTimeHud.luau` + `Map0_Test/` twin

**Not modified (deviation from original blueprint):** `UIBuilder.luau` — the optional
`screenInsets` parameter was not added; stamina's `IgnoreGuiInset = true` was left in place
rather than renamed to the `ScreenInsets` enum. Pure rename with no behavior change, cut to
keep the diff scoped to scaling. See Deviations below.

**Explicitly not modified:** `UITheme.luau`, `TouchSession.luau`,
`ScreenOrientationController`, `CoreGuiController`, `MobileSprintButton`, `CameraTouchHud`,
`MobileFlashlightButton`, `FirstPersonCrosshair`, `DeathScreen`, `MatchReceipt`, and
everything under `ServerScriptService/GameService/MatchTime/`.

## 12. Studio verification checklist

No test runner exists in this project. Verification is manual in Studio.

**Setup:** open `Map0_Test` (the only place that runs all three HUDs), start a match so
`ShowCurrencyUI` fires and `MatchTimeHudController` ticks.

| # | Device / resolution | Do | Expect |
|---|---|---|---|
| 1 | Desktop 1920×1080 | Play, observe all three HUDs | Pixel-identical to pre-change baseline |
| 2 | Desktop 1366×768 | Play | ~0.71×, legible, no clipping |
| 3 | Desktop 2560×1440 | Play | ~1.33×, proportions unchanged |
| 4 | Desktop 3840×2160 | Play | Clamped at 1.35×, not 2.0× |
| 5 | Ultrawide 3440×1440 | Play | Scales by height, not stretched horizontally |
| 6 | Phone landscape | Play | Top strip visibly thinner than desktop, text readable |
| 7 | Tablet landscape | Play | Between phone and desktop |
| 8 | Any — resize window live | Drag viewport mid-play | HUD rescales live, no restart |
| 9 | Any — die and respawn, then resize | | HUD still rescales (`CurrentCamera` reconnection — highest-risk case) |
| 10 | Phone landscape | Sprint stamina to 0 and regen | Fill animates full scaled width; value text readable |
| 11 | Phone landscape | Run/scrub match time | Fill spans scaled width; hour text + color bands update |
| 12 | Phone landscape | Raise camera | Time bar stays visible; stamina + cash hide (unchanged) |
| 13 | Any | Earn cash $0 → $100000 | Text stays constant size, no overflow |
| 14 | Both places | Compare Lobby vs Map0_Test at same resolution | Cash/Stamina/Time all render at identical size |
| 15 | Touch-capable device, if available | Tap then use mouse | Scale shifts between touch/pointer density |

## 13. Performance considerations

- Recompute is event-driven only (`ViewportSize` change, `CurrentCamera` change,
  `LastInputTypeChanged`) — no `Heartbeat`/`RenderStepped` connection.
- The factor is dirty-checked before writing `UIScale.Scale`, since a write re-lays-out the
  whole subtree.
- Three `UIScale` instances total; negligible cost.
- The `TextScaled` → fixed `TextSize` change on Cash is a small win: `TextScaled` forced a
  text-measure pass on every string change (every cash pickup).

## 14. Deviations from the original blueprint

1. `UIBuilder.CreateScreenGui`'s optional `screenInsets` parameter (original §10) was not
   added, and stamina's `IgnoreGuiInset = true` was left as-is rather than renamed to
   `Enum.ScreenInsets.DeviceSafeInsets`. Behaviorally identical either way; skipped to keep
   the change scoped to scaling rather than touching a shared builder used by five other
   ScreenGuis.
2. Cash has no icon — `CurrencyUI` is a single `TextLabel`. Nothing to size responsively
   there.
3. Ultrawide horizontal spread between the three independently-anchored elements was not
   addressed — re-anchoring them closer together on 32:9 is a layout redesign, out of scope
   for a scaling change.
4. Phone portrait was not a verification target — `ScreenOrientationController` hard-locks
   landscape.

## 15. Found, not fixed

1. `MatchPhases.Phases.Dusk.StartHour = 16` and `BarColors.Evening.StartHour = 16` are
   written for a 4 PM start, but `MatchSchedule.Default.StartHour = 18` (6 PM) is the
   actual, intended start time (confirmed). The phase/color tables reference the wrong
   hour; `MatchPhases.Validate()` doesn't catch it since it only checks the first band.
   Not touched — out of scope for this HUD-scaling change.
2. `MatchTimeClient.GetProgress` is linear in real time, not game hours, while
   `MatchSchedule` has variable per-hour rates — the hour label doesn't advance at a
   constant distance along the bar. Cosmetic, pre-existing.
3. The stamina `HUD` ScreenGui has no `KeepDuringCamera` attribute, so it hides whenever
   the player raises the camera. Whether intended is a design call, not touched.
4. Cash and Stamina disagree about the Roblox topbar inset by construction (Cash respects
   it, Stamina ignores it via `IgnoreGuiInset`), so the two top corners sit at different
   effective heights. Not changed — see Deviation #1.
5. `Hudcontroller` predates `UITheme`/`UIBuilder` and hardcodes six colors. Migration
   blocked on palette sign-off per `docs/Planned.md:141`.
