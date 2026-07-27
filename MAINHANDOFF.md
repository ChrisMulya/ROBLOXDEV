# Roblox Game — Project Handoff

## Philosophy
Modular, expandable architecture. Config/tunable values live in dedicated ModuleScripts, not scattered in logic. No `--!strict`.

## Confirmed Working Systems

### Player Stats & Movement
- Centralized `PlayerStats` ModuleScript at `ReplicatedStorage/Modules/`
  - Require path: `ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerStats")`
- `LinearVelocity`-based movement, asymmetric smoothing
- Sprint/stamina system
- FOV pull on sprint, camera roll tilt
- Reduced jump height
- Reactive HUD driven via `BindableEvent`

### Inventory & Shop
- Slot-based inventory; empty slots tagged with `IsEmpty` (Boolean attribute) — `IsA("Tool")` alone can't distinguish empty vs filled
- `StartGame` / `EndGame` lifecycle modules
  - `EndGame` must reset `KitGiven` player attribute to `false` to allow re-triggering
- `ShopFillSlot` + `BuyHandler` — server-authoritative purchases
- Proximity-triggered shop GUI, with movement lock + mouse unlock handling
  - On close, must restore `Enum.MouseBehavior.Default` (NOT `LockCenter` — persists incorrectly in third-person)

### Currency UI
- Remote-event-driven display (not spawn-based)
- Known minor issue: connection leak from repeated Show/Hide cycles — **deferred intentionally**, not yet fixed

### Camera Framework (comprehensive, multi-module)
Rebuilt for modularity in a later pass — was previously one god-object (`CameraState`) plus a duplicated per-template equip script. Now split by concern, each with exactly one owner. All modules under `ReplicatedStorage/Modules/Camera/` (including `CameraStats`) unless noted.

**Client:**
- **`CameraState`** — pure state cell only: InCamera/Stable flags + listeners (`OnChanged`/`OnStableChanged`, both return a disconnect fn) + walk speed multiplier. Owns zero Instances. `InCamera`/`Stable` are private upvalues, not public fields — mutate only via `SetInCamera`/`SetStable`.
- **`CameraSession`** — the orchestrator; owns ONE `Trove` per session. `Enter(tool)` acquires the viewfinder, Lighting effects, `CameraMode`, mouse icon, and tool transparency, registering each one's undo in the Trove immediately. `Exit()` is just `trove:Clean()`. `Toggle(tool)` is the shared "scope button" semantics (enter if inactive, exit if active) — both the desktop right-click binding and the mobile Open/Close touch button call this so the two input paths can't drift apart. This is the module to touch when adding a new per-camera effect — one more `sessionTrove:Add(...)` pair, no signature changes elsewhere. Also reports `IsInCamera` to the server via the `CameraSessionChanged` remote (UX guard only, not security).
- **`CameraEffects`** — Lighting-level `BlurEffect` + `ColorCorrectionEffect` lifecycle and blur math; own internal Trove.
- **`CameraViewfinder`** — the letterbox/bracket/reticle/scanline/grain/vignette overlay. Built **once** and reused via `Show`/`Hide` (not rebuilt every camera-enter); only the scanline count is regenerated per `Show`, sized from `workspace.CurrentCamera.ViewportSize.Y`. `SetBlurAlpha(alpha)` drives the reticle ghost-ring.
- **`ViewfinderTheme`** — layout/chrome constants that are NOT per-camera (bar height, bracket size/margins, label font). Per-camera flavor text (`RecLabel`, `SettingsLabel`) lives in `CameraStats.<id>.Viewfinder` instead.
- **`CameraStability`** — pure `IsMoving(humanoid, rootPart, thresholds)`; thresholds come from `CameraStats.<id>.Stability`.
- **`CameraToolController`** — input binding only (MouseButton1/2 while equipped), delegates everything to `CameraSession`. `Init(tool)` is idempotent (weak-table guard) and returns a destructor. Also the single source of truth for "which camera tool is currently equipped": `GetEquipped(): Tool?` and `OnEquippedChanged(callback): disconnectFn` (fires `(tool)` on equip, `(nil)` on unequip) — `CameraTouchHud`'s driver reads this instead of running a second equip watcher.
- **`CameraFlashEffect`** + **`FloatingShotText`** — visual feedback, unchanged.
- **`CameraClient`** (LocalScript, `StarterPlayerScripts`) — replaces the old `CameraStateWatcher`. One `RenderStepped` loop drives blur + stability, reading root velocity exactly once (previously updated twice per tick — smoothed at ~2x the configured rate). Checks `IsCameraTool` specifically, not "holding any Tool."
- **`CameraToolWatcher`** (LocalScript, `StarterPlayerScripts`) — binds `CameraToolController` to any Backpack/Character Tool tagged `IsCameraTool`. Replaces the per-template `CameraEquipScript` copy — **adding a camera no longer requires a script, only a `CameraStats` entry + model.**
- **`CameraTouchHud`** — touch-only camera controls: an "Open"/"Close" scope button (middle-right, above the jump button) and a "Photo" button (middle-left, above the thumbstick, visible only while InCamera). Pure UI — `Init(onOpenPressed, onPhotoPressed)` takes callbacks, same shape as `CameraShelfGui.Build(onClose)`. Gated to touch devices via `UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled`; on desktop (or a hybrid device with a keyboard) `Init`/`Show` are no-ops and no Instances are created. Built once, toggled via `.Enabled`, same persistent-singleton pattern as `CameraViewfinder`.
- **`CameraTouchHudClient`** (LocalScript, `StarterPlayerScripts`) — wires `CameraTouchHud` to the real systems: `CameraToolController.OnEquippedChanged` → `Show`/`Hide`, `CameraState.OnChanged` → `SetInCamera`, Open button → `CameraSession.Toggle(GetEquipped())`, Photo button → `CameraSession.Capture()`. Kept as its own script rather than folded into `CameraToolWatcher` — that script's job is binding input to tools, not owning UI lifecycle.

**Server:**
- **`CameraShotHandler`** — thin remote adapter: validates the equipped tool, checks cooldown, delegates the raycast to `PhotoCapture`.
- **`PhotoCapture`** (`ServerScriptService/GameService/Camera/`) — the 5×5 spread raycast + `CanCapture` resolution, returns `{ subject, hitPosition, distance }` or `nil`. Offset table is precomputed once at module load, genuinely center-out by radius. This is the seam for future photo scoring / `MonsterBehavior.OnPhotographed` hooks (see `MONSTERS.md`). Misses now also fire `ShotFeedback` (client shows a brief "Missed" label).
- **`CameraSessionTracker`** — tracks client-reported InCamera state per player (UX guard for the shelf, not anti-cheat).

**Camera Shelf** (`Modules/CameraShelf/` client, `GameService/CameraShelf/` server):
- **`CameraShelfGui`** — built from small named-element builders (`buildPanel`, `buildCameraRow`, ...). Iterates `CameraStats.GetOrderedIds()` (stable `ShelfOrder`, not `pairs()` — button order used to be random per session). Shows `DisplayName`/`Description`, highlights the currently-held camera, renders messages via `ShelfResultCodes`.
- **`ShelfResultCodes`** — shared reason-code → display-string table, used by both the client GUI and (implicitly) the server's returned codes.
- **`CameraInventory`** (server) — single owner of "give player camera X" (template lookup, clone, rename to `"Camera"`, set `CurrentCamera` attribute). `StartGame` and `CameraShelfSwap` both call this instead of duplicating the logic.
- **`CameraShelfSwap`** (server) — policy only: refuses if `CameraSessionTracker.IsInCamera(player)` (don't destroy an equipped active camera), returns `AlreadyHolding` as **success** (informational, not an error), delegates the actual grant to `CameraInventory`.
- **`CameraShelfHandler`** (server) — identifies the shelf part via an `IsCameraShelf` attribute (not `part.Name == "CameraShelf"`), re-validates the player's distance to the shelf on every `TakeCameraRequest` (previously only checked at prompt-open time — could be exploited by walking away), uses `Shared/Cooldown` instead of a hand-rolled table.
- `PlayerStats.CurrentCamera` was **removed** — `CurrentCamera` is a per-player fact, not a shared tunable, and now lives only as a `Player` attribute set server-side by `CameraInventory`. Read it client-side via `player:GetAttribute("CurrentCamera")`, never write it from the client.

**Shared utilities** (`ReplicatedStorage/Modules/Shared/`) — reusable outside the camera system too:
- **`Trove`** — `:Add(connection|Instance|function)`, `:Clean()` (reverse order). The fix for the leaked-connections/GUIs-destroyed-by-name-lookup bug class. **Convention: one Trove per "session" or "owner" object; acquire-then-immediately-register the undo, never batch cleanup separately from setup.** This is exactly the pattern that would also fix the deferred `CurrencyUI` Show/Hide connection leak (see below) whenever that gets picked up.
- **`Cooldown`** — `Cooldown.new(seconds?)`, `:Check(key, secondsOverride?)`, auto-clears on `PlayerRemoving`. Pass `secondsOverride` when the window varies per call (e.g. shot cooldown differs by camera + shot type).
- **`Remotes`** — `Remotes.Get(name)`, resolves `ReplicatedStorage.Remotes` once instead of repeating `WaitForChild` boilerplate.

**GUI attribute:**
- `KeepDuringCamera` (Boolean, on a `ScreenGui`) — exempts that GUI from `CameraSession.hideOtherGuis`. Set on `CameraViewfinderGui` and `CameraTouchHud`. Roblox's own `TouchGui` (joystick/jump) is exempted separately by name, since it's engine-owned, gets recreated on control-scheme changes, and can't reliably carry a custom attribute — hiding it previously also broke camera look on touch devices, since `CameraModule/CameraInput` reads `TouchGui.TouchControlFrame` and early-outs when `TouchGui` is disabled.

**Camera tool template attributes:**
- `IsCameraTool` (Boolean)
- `CameraId` (String) — must exactly match a key in `CameraStats.Stats`
  - Do NOT use `Tool.Name` for identification — it gets overwritten at purchase/shelf-swap time by the slot name `"Camera"`

**Target attributes:**
- `CanCapture` (Boolean) — on capturable target Model roots

**Security:** Server always reads attributes from the server-observed tool instance, never trusts client-declared identity. Exception: `CameraSessionTracker`'s InCamera flag is client-reported and is a UX guard only — never treat it as a security boundary.

**Known gap (intentionally out of scope):** the client picks Strong vs Weak shot by choosing which of two remotes to fire, so an exploiter can always get Strong range/cooldown. `PhotoCapture` is structured so fixing this later (server derives stability itself) is a one-module change, but it hasn't been done.

## Confirmed Asset Paths
- Support items: `ReplicatedStorage.Assets.Tool.SupportItem` (no `.Model` in path)
- Camera 1: `ReplicatedStorage.Assets.Model.Tool.Camera.Camera1` (different tree structure from support items — don't assume parity)

## Hard-Won Debugging Lessons
1. `IsEmpty` attribute on placeholder Tools is mandatory
2. LocalScripts silently do nothing outside valid containers (PlayerGui, Backpack, StarterPlayerScripts, etc.)
3. Shop close must restore `Enum.MouseBehavior.Default`, not `LockCenter`
4. Cleanup code inside a Tool destroyed in the same cascade won't run reliably — state ownership must live in a persistent module (`CameraSession` + `CameraClient`), not the Tool itself
5. Use `CameraId` attribute, not `Tool.Name`, for camera type identification
6. Roblox's default camera module spuriously consumes `MouseButton2 InputEnded` — zoom was scrapped in favor of first-person mode (`player.CameraMode = Enum.CameraMode.LockFirstPerson`)
7. `KitGiven` must be reset by `EndGame` or re-triggering breaks
8. ModuleScripts in `ServerScriptService` are inaccessible to clients — only `ReplicatedStorage` modules can be `require`d from LocalScripts
9. Ownership of a resource (GUI, Lighting effect, connection) must be symmetric — whatever module *acquires* it should be the one that *releases* it, via the same reference. Destroying-by-name-lookup instead of by-reference is how teardown silently drifts from setup over time (this is what a `Trove` per owner object prevents).
10. A duplicated block (e.g. the same update call twice in one tick) is easy to miss in review but doubles the effective rate of anything time-based (smoothing factors, cooldowns) — worth specifically re-reading loop bodies line-by-line, not just skimming for "does this look right."
11. This project's local filesystem (`ReplicatedStorage/`, `ServerScriptService/`, `ServerStorage/`) is **live-synced with the open Roblox Studio session** in both directions — editing/creating/deleting a local `.luau` file applies directly to the corresponding Studio Instance, and vice versa. Do not both hand-edit a file locally AND push the same content via a separate Studio-side tool call in the same turn — that appends/duplicates the source instead of replacing it. `StarterPlayer` scripts (LocalScripts under `StarterPlayerScripts`/`StarterCharacterScripts`) have **no local mirror** — those must be read/edited directly via Studio tooling.
12. Luau injected via the Studio MCP `execute_luau` tool runs in an **isolated `require()` cache from the real game's LocalScripts** (it executes under the Studio plugin's identity, not a normal `LocalScript`/`Script` capability level). Module-level state changes made by real running scripts (e.g. `CameraToolController`'s `equippedTool`, set by the live `CameraToolWatcher`) are invisible to a separate `execute_luau` call requiring the same module — even though `game.*` paths and existing Instances are the same shared DataModel. State *does* persist correctly across multiple `execute_luau` calls (they share a cache with each other), just not with real LocalScripts. To test cross-script module wiring, either drive the whole chain from a single `execute_luau` call (manually invoking the same functions the real scripts would call, e.g. calling `CameraToolController.Init(tool)` yourself before equipping) or verify via observable side effects in the DataModel (Instances created, properties changed) rather than trusting a second module require to reflect the first script's state.
13. Studio's plain "Play Solo" reports `UserInputService.TouchEnabled = true` **and** `KeyboardEnabled = true` simultaneously (touch controls render on-screen for testing, while the host PC's real keyboard is also present) — any touch-only gate written as `TouchEnabled and not KeyboardEnabled` (used by `CameraTouchHud`) will treat Play Solo as a non-touch device and stay hidden. This is correct for a real phone (`KeyboardEnabled` is genuinely false there) but means touch-only UI can't be eyeballed under plain Play Solo — use Studio's **Test → Device** emulation (a specific phone/tablet profile), which sets `KeyboardEnabled = false` for real, to see it live.

## Next Priority (as of last session)
Currency deduction logic in `ShopFillSlot` — not yet implemented.

## Working Style Notes (for continuity)
- Debugging: share exact error messages + Output window logs
- Explorer hierarchy screenshots used to resolve path ambiguities
- Willing to change scope mid-build for a simpler fix (e.g., zoom → first-person)
- Prefers centralized ModuleScript configs with clear keys