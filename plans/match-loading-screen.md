# Blueprint — Match Loading Screen (Game place)

**Mode: Planning (READ ONLY).** No code written. This document is the spec.

---

## Context

Why this is being built: the Game place currently has **no loading window at all**. `MatchArrival.seedFrom` (`Map0_Test/ServerScriptService/GameService/Match/MatchArrival.luau:78`) fires `Loading → WaitingForPlayers` on the *first* arriving player, synchronously inside `PlayerAdded`. `MatchSpawner` (`Match/MatchSpawner.luau:41-47`) then calls `LoadCharacter()` on that same transition. So a teleporting player lands in the map the instant they arrive — before `ReplicatedStorage.Assets` monster/camera/pickup models are resolved on their client, before `Remotes` has necessarily replicated, and before the other participants of the reserved server have even joined.

`ReplicatedFirst/` is **empty in both place trees**. There is no `ReplicatedFirst:RemoveDefaultLoadingScreen()`, no `SetTeleportGui` on either teleport leg, and zero `ContentProvider:PreloadAsync` calls anywhere in the repo. Players currently see Roblox's default join screen, then get dropped straight into an un-preloaded map.

Intended outcome: a server-gated loading phase. The `Loading` state (which already exists and is already `INITIAL_STATE`) becomes a real phase with a real duration, bounded by a timeout, during which a client-side curtain covers the screen, assets preload, characters spawn hidden, and input is locked. `Loading → WaitingForPlayers` fires only when the server's own init is done *and* every seeded participant has reported client-ready (or the timeout expires).

**Decisions confirmed by the user:** server-gated handshake · character spawns under the curtain · narrow explicit preload manifest · new refcounted `ControlLock`.

---

## 1. Current Game-place initialization architecture

### Server

```
Bootstrap.legacy.luau              (live Script, the real entrypoint)
  :31  Remotes.Init()              provisions every RemoteEvent from ALL_NAMES
  :33  require ObjectiveService    ┐ module-scope bootstrap() — workspace scan
  :34  require ObjectiveReplicator ┘ happens at REQUIRE time, before GameBoot
  :38  ServerRole.Is("LobbyServer") → LobbyBoot.Start()
  :41  ServerRole.Is("GameServer")  → GameBoot.Start()
```

`GameBoot.Start()` (`Boot/GameBoot.luau:57`):

1. `:58` `ServerRole.AssertGameServer()`
2. `:63` **`Players.CharacterAutoLoads = false`**
3. `:65` `guardNonReservedServer()` — teleports arrivals home if `PrivateServerId == ""`. Contains a live `TEMP:DEV-BYPASS` block (`:33-48`) gated on `RunService:IsStudio()`.
4. `:71-80` seven `Validate()` asserts — `MatchStates`, `PlayerStates`, `MatchDifficulty`, `SpawnCategories`, `MatchSchedule`, `MatchPhases`, `ExitConfig`.
5. `:82-255` one ordered array literal of ~55 `require(...)` results.
6. `:257-259` `for _, service in ipairs(services) do service.Start() end` — **sequential, single-threaded, blocking, no `task.spawn`**.

`MatchArrival` is **deliberately last** (`:254`) so every `StateChanged` subscriber is connected before the first transition fires.

**GameBoot signals completion to nobody.** `Start()` just returns. There is no `Started` signal, no attribute, no flag. Each module uses a private `local started = false` latch.

### Client

`StarterPlayerScripts/ClientBootstrap.local.luau` — 45 lines, top-level requires only, no functions.

- `:10-18` place-agnostic: `FlashRenderers`, `ObjectiveVisualsController`, `PickupVisualsController`
- `:27-45` `ServerRole.Is("GameServer")` branch: `DeathScreenController`, `SpectateController`, `MatchReceiptController`, `MatchTimeHudController`, `MissionHudController`, `ExitCountdownController`

**It waits for nothing.** No server-ready handshake. Readiness is pushed into each subsystem: `Remotes.Get` does bare `WaitForChild` (no timeout), and `MatchInfo` readers use nil-tolerant `FindFirstChild`.

### Match state

`ReplicatedStorage/Modules/Shared/MatchStates.luau` — data-only enum. `INITIAL_STATE = "Loading"` (`:13`). Nine `CORE_FLAGS` (`:15-25`). `Transitions` (`:128-136`): `Loading → {WaitingForPlayers, Cleanup}`.

`Match/MatchManager.luau` — sole authority. `RequestTransition(to, reason)` `:46` is the one guarded setter. `StateChanged` Signal `:32` (**deferred fire — gotcha G11; handler order is undefined — G20**).

`Match/MatchReplicator.luau:41-45` mirrors state onto `ReplicatedStorage.MatchInfo` as the `MatchState` **attribute**. This is the client's channel.

`Match/MatchClock.luau` — polling timers for `WaitingForPlayers` (60 s), `Countdown` (5 s), `Ending` hold (60 s). **There is deliberately no `Loading` timer.** Nothing bounds `Loading` today.

### Player state

`PlayerState/PlayerStateService.luau` — first entry in GameBoot's list (`:83`). Seeds every player `Alive`. `PlayerStateReplicator` (`:84`) mirrors to the `PlayerState` Player attribute. Client mirror `Shared/PlayerStateClient.luau` is read-only and self-starts from its consumers.

### Existing UI conventions this must obey

| Convention | Source |
|---|---|
| All UI is `Instance.new("ScreenGui")` at runtime; zero Studio-authored ScreenGuis | repo-wide |
| `XxxHud.luau` = pure UI · `XxxController.luau` = wiring | `MatchTimeHudController.luau:1-5` |
| `UIBuilder.CreateScreenGui` returns **`Enabled = false`** — opt in explicitly (G15) | `UIBuilder.luau:56` |
| DisplayOrder registry is the **comment** at `UIBuilder.luau:30-51`; highest in use is `1000` (`ScreenFlashRenderer`) | `UIBuilder.luau:27-28` |
| `CameraSession.hideOtherGuis` disables every enabled ScreenGui unless named `CameraViewfinderGui`/`TouchGui` or carrying attribute `KeepDuringCamera = true` | `Camera/CameraSession.luau:72-89` |
| Never cache `Workspace.CurrentCamera` — replaced on respawn **and teleport** (G12) | `MAINHANDOFF.md:543`, `UIScaleController.luau:93-99` |
| `UIScaleController.Attach(root)` for responsive HUD scale | `UI/UIScaleController.luau` |
| Both place trees must stay byte-identical on shared paths | `MAINHANDOFF.md:559` |

`ScreenFlashRenderer.luau` (`Modules/Flash/FlashRenderers/`) is the **structural template**: one lazily-built reused ScreenGui, `ShowSolid` / `HideInstant` / `FadeOut(duration)`, every entry point cancelling the in-flight tween first.

---

## 2. Loading Screen lifecycle

```
Client joins Game place (teleport or direct)
  │
  ├─ ReplicatedFirst/LoadingCurtain.local.luau runs
  │     RemoveDefaultLoadingScreen(); build opaque curtain into PlayerGui
  │     Curtain is up before ReplicatedStorage.Modules has replicated.   ← "immediately"
  │
  ├─ Wait for ReplicatedStorage.Modules  →  require LoadingController
  │     If ServerRole.Is("LobbyServer") → FadeOut immediately, done.
  │
  ├─ ControlLock.Acquire("MatchLoading")
  │
  ├─ Stage A: Remotes.Get + MatchInfo folder present        (indeterminate)
  ├─ Stage B: ContentProvider:PreloadAsync(manifest)        (DETERMINATE %)
  ├─ Stage C: local Character + Humanoid + camera settled   (indeterminate)
  │
  ├─ FireServer("MatchClientReady")                          ← client's only claim
  │
  ├─ Stage D: wait for MatchInfo.MatchState ≠ "Loading"      (indeterminate)
  │
  ▼
Curtain FadeOut → ControlLock.Release("MatchLoading") → gameplay
```

Server side, concurrently:

```
GameBoot service list runs to completion
  │
  ├─ MatchLoadingGate.Start()   (new; near-last, BEFORE MatchArrival)
  ├─ MatchArrival.Start()       (last; seeds roster, NO LONGER transitions)
  │     └─ MatchParticipants.Seed(...) → MatchSpawner loads characters NOW
  │
  ├─ MatchLoadingGate evaluates on every input:
  │     serverReady  AND  every present participant reported ready
  │       OR  MatchConfig.LoadingTimeout elapsed
  │
  ▼
MatchManager.RequestTransition("WaitingForPlayers", "<reason>")
```

The curtain lifts on the **replicated state change**, not on the client's own opinion. That is what makes the handshake server-authoritative.

---

## 3. Required vs optional loading

### Required before the curtain lifts

| Item | Owner | Why |
|---|---|---|
| `ReplicatedStorage.Modules` replicated | client | everything else requires it |
| `ReplicatedStorage.Remotes` + every name in `Remotes.ALL_NAMES` the Game place fires | client | `Remotes.Get` is an unbounded `WaitForChild`; a missing one hangs a subsystem silently |
| `ReplicatedStorage.MatchInfo` folder exists | client | the state channel |
| `ClientBootstrap` Game-branch controllers required | client | HUD must not pop in after the curtain |
| Preload manifest (§5) | client | first monster/camera render hitch |
| Local `Character` + `Humanoid` + `HumanoidRootPart` | server spawns, client waits | camera snap and spawn pop-in must happen hidden |
| `Workspace.CurrentCamera` non-nil and subject bound | client | teleport replaces it |
| GameBoot service list finished | server | authoritative init |
| `MatchParticipants` seeded from TeleportData | server | roster |
| `MatchSettings.Capture` done | server | every `WaitingForPlayers` subscriber calls `Get()` which asserts |
| Registries populated: `ExitRegistry`, `ObjectiveRegistry`, `PickupRegistry`, `CaptureRegistry`, `PatrolGraph` | server | all workspace scans; must be complete before gameplay |
| `MatchTimeEvents` registrants landed (`ExitState` registers `ExitAlternateUnlock`) | server | must precede `MatchTimeService` |

### Optional / background — explicitly NOT gated on

| Item | Why it can wait |
|---|---|
| Monster models in-world | `EncounterDirector` spawns at **`Playing`**, after the 5 s countdown. Only the *template* under `Assets/Monster` is preloaded. |
| `SpawnSelection.Apply()` | runs at `WaitingForPlayers`, after the curtain lifts; pickups are hand-placed and already in Workspace |
| `MatchTimeService` clock / lighting | starts at `Playing` |
| `ExitService` dwell sampler | starts at `Playing` |
| `MissionReplicator` attributes | published only during `Playing` |
| Kit grant (`StartGame.giveStarterCamera`) | fires on `CharacterAdded`; see the `KitGranted` note in §7 |
| Shop / lobby-only assets | not on the Game place |
| Map geometry / textures beyond the manifest | engine streams it; blanket-preloading a map is the classic startup-lag trap |
| `SoundIds` entries | stub with a single `nil` TODO |

---

## 4. Client / server responsibilities

**Client owns presentation and client-side readiness only.**
- Builds, animates, and destroys the curtain.
- Runs `ContentProvider:PreloadAsync` and reports determinate progress.
- Acquires/releases the control lock.
- Fires `MatchClientReady` **once**, as a report — never as a command.

**Server owns the gate.**
- `MatchLoadingGate` is the only thing that may call `RequestTransition("WaitingForPlayers", ...)`. `MatchArrival` loses that responsibility (`MatchArrival.luau:75-79` becomes a `Seeded` signal fire instead).
- Readiness ledger is keyed by `UserId`, seeded from `MatchParticipants`, and is **drop-on-leave** so a disconnect during loading cannot stall the gate forever.
- A client that never reports is covered by `MatchConfig.LoadingTimeout` — the match proceeds without them; they are still a participant and still get a character.
- The server never asks the client whether *server* init is done.

**Anti-pattern explicitly avoided:** no second state machine. `MatchLoadingGate` holds a readiness set and one boolean; every phase change still goes through `MatchManager`.

---

## 5. Asset preloading strategy

New `ReplicatedStorage/Modules/Shared/LoadingManifest.luau` — data only, no side effects, mirrors the `MatchStates`/`Remotes.ALL_NAMES` "manifest module" pattern.

`Collect(): {Instance}` resolves, each with `FindFirstChild` and skipping absent entries (the `Assets` tree is hand-placed in Studio and **not guaranteed present** — `ShopCatalog.luau:266` already documents this):

- `ReplicatedStorage.Assets.Monster.*` — every model (currently `Monster1`)
- `ReplicatedStorage.Assets.Tool.Camera.*` — camera tool models
- `ReplicatedStorage.Assets.Pickup.*` — `Cash`, and any document model
- `ReplicatedStorage.Assets.Tool.SupportItem.PlacedItem.*` — deployables render mid-match with no cover
- `ReplicatedStorage.Sounds.Tool.*` — `FlashLightSound`, `CompactSpeakerSound`
- The curtain's own GuiObjects (so the curtain never renders un-textured)

**Excluded on purpose:** `workspace` map geometry, `Assets.Tool.SupportItem.ItemRemotes.*` (tablet UI, only on use), anything Lobby-only.

`ContentProvider:PreloadAsync(list, callback)` is called **once** with the whole list, in one `task.spawn`, from the controller. The per-asset callback increments the completed count → this is the one determinate progress source. `PreloadAsync` yields until every entry resolves or fails; a failed entry invokes the callback with a failure status and does **not** abort the batch. Failures are counted and warned, never fatal.

---

## 6. Loading progress strategy

Four stages, each with an honest indicator. **No fabricated percentages.**

| Stage | Status text | Indicator |
|---|---|---|
| A — replication | `Connecting…` | indeterminate (looping sweep bar) |
| B — assets | `Loading assets…  N / M` | **determinate bar + integer %** from the `PreloadAsync` callback |
| C — character | `Preparing…` | indeterminate |
| D — server handshake | `Waiting for players…` | indeterminate; after `SOFT_WARN_SECONDS`, append `(N of M ready)` from a replicated `MatchInfo.LoadingReadyCount` / `LoadingReadyTotal` attribute pair |

Only stage B has a real denominator, so only stage B gets a percentage. The bar does not interpolate across stages and does not tween toward a guessed target — that is the "fake progress" the request forbids.

The ready-count attributes are written by `MatchReplicator` (the only match module permitted to touch the replication layer) and cleared on leaving `Loading`.

---

## 7. Match State integration

**No new state. No new state machine.**

1. **New `CORE_FLAGS` entry: `ShowsLoadingScreen`.** True for `Loading` only. Follows the `ShowsMatchTime` precedent exactly (`MatchStates.luau:32-39`). `MatchStates.Validate()` asserts every state carries every flag, so this is a one-row-per-state edit across all seven states **plus** the `CORE_FLAGS` list — miss one and `GameBoot` hard-fails at `:71`. Add accessor `MatchStates.ShowsLoadingScreen(state)`.

2. **`MatchArrival` stops transitioning.** `:75-79` becomes: capture `MatchSettings`, then fire a new `MatchArrival.Seeded` Signal. The `advanced` latch stays (it must still fire exactly once). The solo-fallback path (`:61-66`, no `rosterLatched`) is preserved verbatim — it is what keeps Studio Play-test runnable.

3. **New `MatchLoadingGate`** (`GameService/Match/MatchLoadingGate.luau`) owns `Loading → WaitingForPlayers`. Inputs: `MatchArrival.Seeded`, `MatchClientReady` remote, `MatchParticipants.Joined` / player-removing, and a `LoadingTimeout` timer. `evaluate()` is computed on every input and is order-independent (G20). Reasons emitted: `"AllClientsReady"` / `"LoadingTimeout"`.

4. **`MatchClock` gains `runLoading`.** Same polling shape as `runWaitingForPlayers` (`MatchClock.luau:28-53`) — but it must be started from `MatchLoadingGate.Start()` or a `GameBoot` tail call, because `MatchClock` only reacts to `StateChanged` and `Loading` is the *initial* state, which never fires a transition. `Loading → Cleanup` is already a legal edge, but the timeout should target **`WaitingForPlayers`**, not `Cleanup`: a slow client must not kill the match.

5. **`MatchConfig`** gains `LoadingTimeout` (suggest **45**) and `LoadingMinSeconds` (suggest **0.5**, so the curtain never strobes on a fast local join).

6. **`Loading.KitGranted` flips to `true`.** Characters now spawn during `Loading`, and `KitLifecycleHook` grants on `CharacterAdded` gated by `MatchStates.IsKitGranted`. Left `false`, the kit is never granted at all — `CharacterAdded` has already fired by the time `WaitingForPlayers` lands. The camera tool being in the backpack under an opaque curtain with input locked is safe; `GameplayActive` and `ScoringActive` stay `false`.
   *Alternative if flipping the flag is unwanted:* add a `WaitingForPlayers` backfill loop to `KitLifecycleHook` for participants who already have a character. More code, same result. **Flag flip is the recommendation** — it is the data-driven answer this codebase is built around.

7. **`Loading.RespawnsOnDeath` is already `true`** — respawn during loading already works. No change.

8. **`MatchSpawner` reacts to seeding, not to the transition.** `:41-47` (`newState == "WaitingForPlayers"`) is replaced by a `MatchArrival.Seeded` handler. The `MatchParticipants.Joined` backfill at `:54-58` stays but its `AcceptsJoins` guard must additionally admit `Loading` — cleanest as `MatchStates.AcceptsJoins(state) or state == "Loading"` is *wrong* (name-branching is banned by `MatchStates.luau:1-4`); instead **flip `Loading.AcceptsJoins` to `true`**, which is semantically correct — a reserved server is absolutely accepting joins during `Loading`.

---

## 8. Gameplay / input lock behavior

### The pre-existing hazard

`controls:Disable()` / `controls:Enable()` on the `PlayerModule` control switch is currently called by **three unrelated files with no refcount**:
`CameraShelfClient.local.luau:15,23` · `ItemUseClient.local.luau:31,69-75` · `PlayerShop.local.luau:14,141`

`ItemUseClient.luau:64-75` already documents the bug and works around it *locally* with a two-flag `refreshControls()`. Any bare `Enable()` from another file unfreezes the player under someone else's freeze — i.e. under the curtain.

Also note: **zeroing `WalkSpeed` does nothing here.** `Playermovementcontroller.local.luau:102-108` pins local `WalkSpeed = 0` permanently; movement is a `LinearVelocity` named `MovementDrive`.

### The fix

New `ReplicatedStorage/Modules/Shared/ControlLock.luau`:

- `Acquire(reason: string)` / `Release(reason: string)` — a set of string reasons, not a counter, so a double-Acquire from one owner is idempotent and a Release from an owner that never acquired is a warn, not a silent unfreeze.
- Derives the switch: `next(reasons) ~= nil → controls:Disable()` else `controls:Enable()`.
- Resolves `PlayerModule` lazily and caches it. Re-derives on `CharacterAdded` (the control module is rebuilt on respawn).
- Migrate all three existing call sites onto it. `ItemUseClient`'s two local flags become `Acquire("ItemUseHold")` / `Acquire("CCTVView")` and its `refreshControls` disappears.

### What else the curtain locks

- **Curtain ScreenGui**: `DisplayOrder = 2000` (register the row in the `UIBuilder.luau:30-51` comment). Nothing currently sits above `1000`.
- **`SetAttribute("KeepDuringCamera", true)`** on the curtain, or `CameraSession.hideOtherGuis` (`CameraSession.luau:72-89`) will disable it. Bug precedent at `ScreenFlashRenderer.luau:39-49`.
- **`ResetOnSpawn = false`** — mandatory; the character spawns *during* loading and would otherwise wipe the curtain.
- **`IgnoreGuiInset = true`** — `CreateScreenGui` does not set it; set it after the call, as `MobileSprintButton.local.luau:124` does.
- **CoreGui**: extend `CoreGuiController.local.luau`'s existing disable set to include `Backpack` and `Chat` for the duration, restoring after. It already disables `Health` and `PlayerList` with a 5-attempt retry loop.
- **Other HUD ScreenGuis**: no change needed. They are `Enabled = false` by construction (`UIBuilder.luau:56`) and their controllers only enable on data they do not have yet during `Loading` (`MatchInfo` attributes are nil, `ShowsMatchTime` is false). An opaque `DisplayOrder 2000` curtain covers anything that slips through.
- **Camera**: do **not** set `CameraType.Scriptable`. `SpectateCameraController.luau:2-17` documents why that fights Roblox's own respawn reassignment. The opaque curtain is sufficient cover; let the default `CameraModule` settle behind it. Never cache `Workspace.CurrentCamera` (G12).

**Release ordering matters:** `FadeOut` completes → *then* `ControlLock.Release("MatchLoading")` → then CoreGui restore. Releasing first lets a player walk during the fade.

---

## 9. Failure / timeout handling

| Failure | Handling |
|---|---|
| **Asset fails to preload** | `PreloadAsync`'s callback reports per-asset failure; count it, `warn` the asset path, continue. Never fatal — a missing `Assets` subtree is an already-documented normal condition (`ShopCatalog.luau:266`). |
| **A required module errors on require** | Wrap the `ClientBootstrap` Game-branch requires and the manifest resolve in `pcall`. On failure: warn, mark the stage complete, report ready anyway. A broken HUD is better than an infinite curtain. |
| **`Remotes.Get` never resolves** | Stage A runs in a `task.spawn` with its own deadline. On expiry, mark stage A failed-but-complete and continue. This is the one place the unbounded `WaitForChild` is currently dangerous. |
| **Server slow / GameBoot stalls** | `MatchConfig.LoadingTimeout` (45 s) in `MatchClock.runLoading` forces `Loading → WaitingForPlayers` with reason `"LoadingTimeout"`. The match proceeds degraded rather than hanging. |
| **A client never reports ready** | Same timeout. The gate drops them from the required set on `PlayerRemoving`, and the timeout covers a present-but-silent client. |
| **Client disconnects during loading** | `MatchParticipants` already tracks presence; the gate's ledger is drop-on-leave, and `evaluate()` re-runs on removal so the last remaining ready client releases the gate immediately. |
| **Player respawns during loading** | `Loading.RespawnsOnDeath` is already `true`, so `DeathService.luau:43` reloads the character. Curtain survives (`ResetOnSpawn = false`). `ControlLock` re-derives on `CharacterAdded`. |
| **Client watchdog (belt and braces)** | Two client timers, independent of the server: **soft** at 20 s → status text becomes `Still loading… (N of M ready)`; **hard** at `LoadingTimeout + 15` (60 s) → replace the spinner with a failure panel (`UIBuilder.CreatePanel`) reading `Match failed to start` plus a **Return to Lobby** button. |
| **Return-to-lobby escape** | The existing `ReturnToLobbyRequest` remote is gated to `ALLOWED_RETURN_STATES = {Ending, Cleanup, Finished}` (`ReturnToLobbyService.luau:102`). **Add `Loading`** to that set, with the existing 3 s cooldown. Reuses the whole existing teleport-retry + kick path (`:73-85`) — no new lifecycle. |
| **Genuinely fatal server init** | `MatchManager.Abort(reason)` already lands on `Cleanup` from anywhere, which runs `MatchCleanup` (10 s per step) → `Finished` → `ReturnToLobbyService.ReturnAll()` with its 30 s watchdog kick. Nothing new needed. |
| **Non-reserved server** | Unchanged. `guardNonReservedServer()` teleports arrivals home before any service starts, so the curtain simply never gets a state change — the client hard watchdog catches it. |

**Diagnostic path:** every gate decision `warn`s once with the reason and the ready set (`"MatchLoadingGate: released (AllClientsReady) 3/3"`). The failure panel shows the last stage reached, so Output and the player's screen agree.

---

## 10. Expected files / modules affected

Everything under `ReplicatedStorage/`, `ReplicatedFirst/`, and `StarterPlayerScripts/` must land in **both** `Lobby\` and `Map0_Test\` (`MAINHANDOFF.md:559`). Server-only files under `ServerScriptService/GameService/` also exist in both trees today — match that.

### New

| Path | Kind |
|---|---|
| `ReplicatedFirst/LoadingCurtain.local.luau` | LocalScript — instant curtain, `RemoveDefaultLoadingScreen()`, handoff |
| `ReplicatedStorage/Modules/UI/LoadingHud.luau` | pure UI — build/update/fade, no state, no remotes |
| `ReplicatedStorage/Modules/UI/LoadingController.luau` | wiring — stages, preload, handshake, watchdogs |
| `ReplicatedStorage/Modules/Shared/LoadingManifest.luau` | data only |
| `ReplicatedStorage/Modules/Shared/ControlLock.luau` | refcounted control switch |
| `ServerScriptService/GameService/Match/MatchLoadingGate.luau` | the gate |

### Modified

| Path | Change |
|---|---|
| `Modules/Shared/MatchStates.luau` | `+ShowsLoadingScreen` in `CORE_FLAGS` **and all 7 rows**; `Loading.KitGranted → true`; `Loading.AcceptsJoins → true`; `+ShowsLoadingScreen()` accessor |
| `Modules/Shared/MatchConfig.luau` | `+LoadingTimeout`, `+LoadingMinSeconds` |
| `Modules/Shared/Remotes.luau` | `+MatchClientReady` in `ALL_NAMES` (**both trees** — Lobby provisions Game-only remotes by policy) |
| `Modules/UI/UIBuilder.luau` | one line in the DisplayOrder registry comment: `2000  LoadingCurtainGui` |
| `Match/MatchArrival.luau` | `:75-79` — replace `RequestTransition` with a `Seeded` Signal fire |
| `Match/MatchSpawner.luau` | `:41-47` — subscribe to `MatchArrival.Seeded` instead of the `WaitingForPlayers` state change |
| `Match/MatchClock.luau` | `+runLoading`; started explicitly (initial state fires no transition) |
| `Match/MatchReplicator.luau` | publish `LoadingReadyCount` / `LoadingReadyTotal` on `MatchInfo`; clear on leaving `Loading` |
| `Match/ReturnToLobbyService.luau` | `:102` — add `Loading` to `ALLOWED_RETURN_STATES` |
| `Boot/GameBoot.luau` | insert `MatchLoadingGate` immediately **before** `MatchArrival` at `:254` |
| `StarterPlayerScripts/ClientBootstrap.local.luau` | Game branch: `require(...UI.LoadingController)` **first** in the branch |
| `StarterPlayerScripts/CoreGuiController.local.luau` | add `Backpack`/`Chat` to the temporary disable set |
| `StarterPlayerScripts/ItemUseClient.local.luau` | migrate off local `refreshControls` onto `ControlLock` |
| `StarterPlayerScripts/CameraShelfClient.local.luau` | migrate onto `ControlLock` |
| `StarterPlayerScripts/PlayerShop.local.luau` | migrate onto `ControlLock` |
| `MAINHANDOFF.md` | new system row; refresh the stale DisplayOrder table at `:584-596` |

---

## 11. Initialization order

### Server (inside GameBoot's ordered list)

```
 1  PlayerStateService, PlayerStateReplicator            (unchanged, first)
 …  registries: ExitRegistry, ObjectiveRegistry,
    PickupRegistry, CaptureRegistry, PatrolGraph         (unchanged)
 …  MatchManager, MatchParticipants, MatchSettings       (unchanged)
 …  MatchReplicator                                      (unchanged — must precede
                                                          anything that transitions)
 …  MatchSpawner                                          (unchanged position; now
                                                          listens to Seeded)
 …  MatchClock                                            (unchanged position)
 N-1  MatchLoadingGate      ← NEW, must connect before MatchArrival can seed
 N    MatchArrival          ← stays LAST
```

`MatchLoadingGate.Start()` also kicks `MatchClock.runLoading` (or arms its own timer), because `Loading` is the initial state and therefore never arrives via `StateChanged`.

### Client

```
1  ReplicatedFirst/LoadingCurtain.local.luau   — curtain up, default screen removed
2  ReplicatedStorage:WaitForChild("Modules")
3  require ServerRole  → Lobby? fade out, stop.
4  require LoadingController → ControlLock.Acquire("MatchLoading")
5  ClientBootstrap Game-branch requires (LoadingController first)
6  Stage A → B → C  (B and C may overlap; A gates both)
7  FireServer("MatchClientReady")
8  Stage D: MatchInfo.MatchState leaves "Loading"
9  max(elapsed, LoadingMinSeconds) → FadeOut → Release → CoreGui restore
```

---

## 12. Performance considerations

- **One `PreloadAsync` call, one list, one `task.spawn`.** Not per-asset, not per-stage. `PreloadAsync` deduplicates internally; calling it twice on overlapping lists is the "duplicate asset loading" trap.
- **Modules are required once.** Luau caches `require` per-ModuleScript, so `ControlLock` / `LoadingManifest` / `LoadingHud` resolve once regardless of caller count. Do not re-`require` inside loops or per-frame handlers.
- **No polling on the client.** Every stage is event-driven: `WaitForChild` for replication, `PreloadAsync`'s callback for assets, `player.CharacterAdded` for the character, `MatchInfo:GetAttributeChangedSignal("MatchState")` for the gate. The only timers are the two watchdogs (`task.delay`, fired once each) — **zero `RenderStepped`/`Heartbeat` connections**, except the curtain's indeterminate sweep animation, which is a single `TweenService` loop, not a per-frame callback.
- **Server polling is bounded.** `runLoading` uses the existing 1 s `task.wait` shape from `runWaitingForPlayers`; the gate itself is fully event-driven and `runLoading` exists only as the timeout backstop.
- **The curtain is built once and reused**, exactly like `ScreenFlashRenderer` — never rebuilt on respawn (`ResetOnSpawn = false`), never destroyed until the fade completes. Cache the ScreenGui and its labels in module upvalues; cancel any in-flight tween at every entry point.
- **`LoadingMinSeconds` is a floor, not a delay.** It exists so a 0.2 s local join does not flash the curtain; it must not extend a genuinely slow load.
- **The gate's ledger is a `{[number]: true}` set** rebuilt only on membership change — no per-tick recomputation.
- **`ContentProvider` on the manifest, not on `workspace`.** Preloading map geometry is the single largest available regression here and is explicitly out of scope.

---

## 13. Studio verification checklist

No test runner exists in this project. Verify in Studio; `guardNonReservedServer`'s `TEMP:DEV-BYPASS` (`GameBoot.luau:33-48`) is what makes local Play-testing of the Game place possible at all, and `ReserveServer`/`TeleportAsync` return 403 in Studio (G10) — so the full teleport leg needs a **published** build.

| # | Do | Expect |
|---|---|---|
| 1 | Play Solo in `Map0_Test` | Opaque curtain visible on the very first frame; no Roblox default loading screen; no flash of the map |
| 2 | Watch Output during 1 | `MatchLoadingGate: released (AllClientsReady) 1/1`; no `RequestTransition` rejection warnings |
| 3 | During the curtain, mash WASD / space / mouse | No movement, no jump, no camera tool, no ProximityPrompt on any pickup or exit |
| 4 | Watch the progress bar | Only stage B shows a %; A/C/D show a sweep. The % never decreases and never sits at a value with no matching `N / M` |
| 5 | After the curtain fades | Character present, camera settled, WASD + sprint + jump all work; camera tool in Backpack |
| 6 | Check `ReplicatedStorage.MatchInfo` attributes after fade | `MatchState = "WaitingForPlayers"`; `LoadingReadyCount` / `LoadingReadyTotal` are **nil** |
| 7 | Start 2 local players (Test → 2 Players) | Both see a curtain; **both lift at the same instant**, not independently |
| 8 | With 2 players, close one client mid-curtain | The remaining client's curtain lifts promptly (ledger drop-on-leave), not after 45 s |
| 9 | Temporarily set `MatchConfig.LoadingTimeout = 3` and stall a client (breakpoint before `FireServer`) | Curtain lifts at ~3 s, Output shows reason `LoadingTimeout`, match still runnable |
| 10 | Rename `ReplicatedStorage.Assets.Monster` in Studio, Play | Warn per missing asset, curtain still lifts, match still runs |
| 11 | Kill the character during the curtain (`Humanoid.Health = 0` from the command bar) | Character respawns, curtain **still up and unchanged**, input still locked |
| 12 | Open the camera viewfinder immediately after the fade | Curtain is gone; confirm `hideOtherGuis` never disabled it mid-load (attribute `KeepDuringCamera` present on `LoadingCurtainGui`) |
| 13 | Run once as a solo player, once with 2, and check Output for duplicate `Start()` / duplicate spawn logs | Each system starts exactly once; no double `LoadCharacter`, no double `SpawnSelection.Apply` |
| 14 | Device emulator → phone (iPhone/Pixel) | Curtain fills the screen including the top inset (`IgnoreGuiInset`); text legible at `UIScaleController`'s touch density (0.78); thumbstick not visible/usable through the curtain |
| 15 | Device emulator → desktop 1920×1080 and 1280×720 | Bar and text scale, stay centred, no clipping |
| 16 | Force the hard watchdog (breakpoint the gate server-side) | At 60 s the failure panel appears with a working **Return to Lobby** button — verify the button on a **published** build, since teleport 403s in Studio |
| 17 | Published build: queue on a lobby pad → teleport | Curtain covers the whole arrival; player never sees the map before it's ready |
| 18 | `diff -rq Lobby Map0_Test` | No *new* differences beyond the 17 pre-existing ones |
| 19 | Join the **Lobby** place | Curtain appears then fades immediately; lobby is fully interactive; no locked input |

---

## 14. Deviations from the request

1. **"Match Mission data" is not gated.** The request lists it as a candidate. `MissionProgress` is derived on demand from the registries (`MissionProgress.luau:51-71`) and `MissionReplicator` publishes only during `Playing`. There is no mission *generation* step to wait on. Gating on it would be gating on nothing. The registries it derives from **are** gated.
2. **"GameBoot initialization" is gated implicitly, not explicitly.** GameBoot exposes no completion signal, and adding one is a larger change than this feature warrants. Because `MatchLoadingGate` is placed second-to-last in the list, the gate's own `Start()` running *is* the proof that everything before it started. This is the same trick `MatchArrival`'s last-place position already uses (`GameBoot.luau:248-253`).
3. **Two flag flips beyond a pure addition.** `Loading.KitGranted` and `Loading.AcceptsJoins` both move `false → true`. These are forced by spawning the character under the curtain (the user's chosen option) — without them the kit is never granted and late-joining participants never spawn. Both are semantically correct for a reserved server that is loading. Flagged because they change `MatchStates` semantics, not just add to them.
4. **`ReturnToLobbyService.ALLOWED_RETURN_STATES` gains `Loading`.** Required to give the hard-watchdog failure panel a real escape rather than a dead button, and reuses the existing lifecycle as the request asked.
5. **`ControlLock` touches three files outside the feature.** Normally out of scope under the project's scope contract. Included because the user explicitly chose it, and because a curtain built on the unrefcounted switch is not merely imperfect — it is defeated by any of the three existing callers.
6. **No `SetTeleportGui` on the lobby→game leg.** A teleport GUI would cover the gap between leaving the Lobby and `ReplicatedFirst` running on the Game place. It is a genuine polish win but a separable change with its own asset and lifecycle concerns; the `ReplicatedFirst` curtain is what the request actually asked for. Noted as an obvious follow-up.
7. **`MatchClock.runLoading` needs an explicit kick.** `MatchClock` is purely `StateChanged`-driven, and the initial state never fires a transition. This is an asymmetry with its three existing runners and should be commented as such in the implementation.

---

## Found, not fixed

- `GameBoot.luau:33-48` ships a live `TEMP:DEV-BYPASS` block gated on `RunService:IsStudio()` that skips `guardNonReservedServer()`. The file's own header says to delete it before shipping. Present in the committed tree at `c07b159`.
- `diff -rq Lobby Map0_Test` currently prints **17 differences** across `Camera/*`, `Flash/FlashRenderers/*`, `MatchTime/MatchTimeHud.luau`, `Objective/ObjectiveVisualsController.luau`, `Shop/ShopCatalog.luau`, `UI/MatchReceipt*.luau`, `Playermovementcontroller.local.luau`, plus two files only in `Map0_Test`. `MAINHANDOFF.md:14` says this must print nothing.
- `MAINHANDOFF.md:584-596`'s DisplayOrder table is stale — missing `25 ExitCountdownGui`, `35 ShopGui`, `60 PurchaseNotificationGui`, `0 HudLeftGui`. `UIBuilder.luau:30-51` is the real registry.
- `MAINHANDOFF.md:21,44` says the night runs "4 PM → 6 AM"; `MatchSchedule.luau` has `StartHour = 18` (6 PM).
- `MAINHANDOFF.md` labels the Match layer, Mission HUD, cone photo capture, Document pickup, match-time announcer, and responsive HUD as "uncommitted, unverified". All are committed; the working tree is clean at `c07b159`.
- `CameraToolWatcher.local.luau:26` uses `player:WaitForChild("Backpack")` with **no timeout** — hangs the watcher silently if the Backpack never appears.
- Four plan files are referenced by code/doc comments but do not exist on disk: `plans/photo-capture-detection.md`, `plans/create-a-read-only-blueprint-plan-agile-possum.md` (cited at `SpawnSelection.luau:21`), `plans/create-a-read-only-implementation-foamy-cookie.md`, `plans/planning-mode-do-not-rustling-firefly.md` (cited at `Bootstrap.legacy.luau:21`).
