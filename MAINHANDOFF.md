# MAINHANDOFF — current state

Agent-facing. Current phase only, no history. Git has the changelog.
Module behavior lives in the code and `graphify-out/GRAPH_REPORT.md` — not here.

## Phase

Two published places, live-syncing to disk independently: `Lobby/` (Lobby
server) and `Map0_Test/` (reserved Game server, teleported to via
matchmaking). Both trees are kept **byte-identical on every shared path** —
verify with `diff -rq Lobby Map0_Test` after any cross-cutting change; there
is no Rojo project file and no automated drift check beyond that diff.

There are **no standing exceptions** — `diff -rq Lobby Map0_Test` prints
nothing, and any output is a bug. (`ReturnToLobbyRequest` is listed in both
places' `Remotes.ALL_NAMES` even though only the Game place connects to it,
precisely so the diff stays a clean machine check.)

What exists and works end to end: move → buy camera → photograph
monsters/objectives → earn XP/Score → queue on a lobby pad → teleport into a
reserved match server → match runs a 4 PM → 6 AM night on a configurable
schedule → sunrise kills whoever is left and ends the match → return to Lobby
with XP persisted. Loadout (camera choice) survives both a teleport and a
plain rejoin. Reward persistence is on ProfileStore with a real per-session
lock. Verified live on the published two-place build.

**Uncommitted work-in-progress on top of that baseline** (not yet verified
live, not yet committed): a formal Match layer (`GameService/Match/*`)
replacing the old ad hoc lifecycle glue — now including a real, timed
`Loading` phase with a client curtain (`plans/match-loading-screen.md`) — a
shared Mission List HUD, a Monster investigation/search overhaul
(`Investigation` component, `VisualScan` behaviour, `PointSelector`), a
capture-target registry feeding a rewritten cone-based `PhotoCapture`, a
Document pickup, and the match-time announcer + responsive-HUD work
described in `plans/`. See the new subsections below and `git status` for
the exact file list — this paragraph only orients; it is not a substitute
for reading the diff before touching any of it.

**Known-broken and half-built items are their own sections below** — this
paragraph is the only narrative allowed in this file. For how any of this was
built, or what it used to be, see `git log`.

### Match time — the single authority on match length (Game place only)

A match is a night: 4 PM → 6 AM, on a segment schedule where each stretch of
hours has its own real-time cost (`MatchTime/MatchSchedule.luau`). `Default` is
60 s/hour to 7 PM then 75 s/hour, totalling **1005 s**. `Debug` (3 s/hour, 42 s
total) exists for Studio runs — never point a real mode at it.

**Hours run on a continuous scale past 24**: 6 AM is `30`, midnight is `24`.
Every comparison and subtraction in the system is plain arithmetic on that
scale. The only legal `% 24` are `MatchTimeMath.FormatHour` (display) and
`MatchTimeLighting` (`ClockTime` is a 0-24 engine property). A wrap anywhere
else reintroduces midnight-crossing bugs.

`MatchConfig.MatchDuration` and `MatchClock.runPlaying` **do not exist** — how
long `Playing` lasts is the schedule's total and nothing else. `MatchClock`
still owns the `WaitingForPlayers`/`Countdown`/`EndingHold` timers; those bound
states *outside* the match and are not a second match clock.

The clock is **match-scoped**: it anchors on `Playing` and is fully torn down on
any exit from it — Heartbeat disconnected (not left idle), anchors cleared,
`MatchTimeEvents.Reset()`. `GetHour`/`GetPhase`/`GetProgress` return **nil**
outside `Playing`; that nil is the contract, so every consumer must handle "no
match time right now" rather than defaulting to a number. Nothing exists on the
Lobby: the server modules are `GameBoot`-only and the HUD controller is required
only in `ClientBootstrap`'s `GameServer` branch.

Sunrise ends the match: `RequestEnd("Sunrise")` **first** (so `MatchEndCondition`
can't win the race and stamp `AllPlayersDown`), then `Health = 0` on every
survivor, with no yield between the two. Those deaths land while the state is
already `Ending`, where `MatchStates.RespawnsOnDeath` is false — that flag is the
only thing stopping `DeathService` respawning everyone under the result receipt.

Phases (`MatchPhases`) are **derived from the hour, never stored or
transitioned** — that is what keeps them from becoming a state machine parallel
to `MatchStates`. A monster's effective stage is
`max(spawnPoint.Stage, phase.MonsterStage)`: the authored stage is a floor, so
the ramp is monotonic and collapses to today's behaviour when there is no match
time.

### Match layer (`ServerScriptService/GameService/Match/`) — Game place only, uncommitted

A formal phased lifecycle replacing the previous ad hoc glue. Each module owns
exactly one concern and the boundaries are enforced in each file's own header
comment — read the module before extending it rather than guessing from the
name:

- `MatchManager` — owns the current `MatchStates` value and is the **one**
  guarded entry point (`RequestTransition`) every state change goes through,
  including `RequestEnd`/`Abort`. No gameplay logic, no remotes/attributes.
- `MatchParticipants` — the authoritative roster (who was teleported in and
  is expected), independent of `Players:GetPlayers()`. A disconnected
  participant is still a participant.
- `MatchArrival` — Game-side counterpart to the Lobby's `ArrivalService`:
  consumes `TeleportData`, seeds `MatchParticipants`, captures
  `MatchSettings`, and fires `Seeded`. **No longer transitions the match
  itself** — that used to happen here in the same frame as the first
  arrival, which left no real `Loading` window. `MatchLoadingGate` (below)
  owns `Loading → WaitingForPlayers` now. Falls back to a solo participant
  (the arriving player) with no `TeleportData`, so a direct Studio Play-test
  still produces a runnable match of one.
- `MatchSpawner` — loads a character for each participant, reacting to
  `MatchArrival.Seeded` (not a state change) so it happens **during**
  `Loading`, under the curtain. Required because `GameBoot` sets
  `CharacterAutoLoads = false`; without this an arriving participant is a
  disembodied camera.
- `MatchLoadingGate` — the one module that may fire `Loading →
  WaitingForPlayers`. Gated on every present participant firing the
  `MatchClientReady` remote (client-reported, never trusted alone) or
  `MatchConfig.LoadingTimeout` (45s, via `MatchClock.StartLoadingTimeout`)
  elapsing. Ledger is drop-on-leave. See "Match loading screen" below.
- `MatchClock` — optional per-mode timers (`WaitingForPlayers` timeout,
  `Countdown` ticks, the `Ending → Cleanup` hold). Drives transitions only
  through `MatchManager`, holds no state of its own. Supersedes
  `MatchCleanup`'s old placeholder `ENDING_HOLD_SECONDS` constant.
- `MatchEndCondition` — the one module allowed to correlate the roster
  (`MatchParticipants`) with per-player state (`PlayerStateService`) to
  decide when a live match has nobody left to end for. Policy only; does not
  itself clean up or teleport.
- `MatchReplicator` — mirrors `MatchManager`'s state onto
  `ReplicatedStorage.MatchInfo` attributes (shared state → attribute, per the
  existing invariant), plus `LoadingReadyCount`/`LoadingReadyTotal` from
  `MatchLoadingGate.ReadyCountChanged` (nil outside `Loading`, same
  `ShowsMatchTime`-only convention as the match clock). The one Match module
  allowed to touch remotes: on entering `Ending` it also builds and sends
  the per-player `MatchResultSync` payload.
- `MatchResultBuilder` — assembles the end-of-match summary from registered
  contributors (`RegisterContributor`, same non-yielding/side-effect-free
  contract as `RewardService.RegisterContextProvider`). Feature systems
  register their own slice; this module never learns what an objective or
  reward type is. `MatchRosterHook` (display names) and `MatchStats`
  (survival time + capture counts, feeding `Shared/MatchGrade.luau`'s letter
  grade) are its two current registered contributors.
- `MatchCleanup` — saves and destroys on reaching `Cleanup`. Systems opt in
  via `RegisterSaveStep`/`RegisterTeardownStep`. Must not teleport (that's
  `ReturnToLobbyService`) or compute rewards itself.
- `ReturnToLobbyService` — teleports everyone home on `Finished`, then lets
  Roblox destroy the empty reserved server naturally. Only reacts once
  `Cleanup` has actually finished saving. A watchdog force-kicks stragglers
  if the return teleport doesn't empty the server after a grace period —
  this is the source of the `ReturnToLobbyService: watchdog elapsed` /
  `TeleportAsync failed: Request Context Failure` lines seen in Studio
  Output; expected there (G10 — `TeleportAsync` 403s in Studio Play), not
  evidence of a live bug.
- `MissionProgress` / `MissionReplicator` — see Mission List section below;
  live in this folder because mission progress is match-scoped shared state,
  the same category as the roster and the clock.

**Relationship to existing systems, not yet reconciled in prose elsewhere:**
`MatchClock` here is a distinct module from `MatchTime/`'s clock described
above — this one times the `WaitingForPlayers`/`Countdown`/`Ending→Cleanup`
states *around* a match; `MatchTime` times the *Playing* night itself. Same
naming collision the original "Match time" section already calls out for the
old `MatchClock` — worth a rename pass before this ships, not done here.

### Match loading screen — real `Loading` phase + client curtain, uncommitted

Blueprint: `plans/match-loading-screen.md`. `Loading` was previously
instantaneous (`MatchArrival` transitioned out of it in the same frame as
the first arrival); it is now a real, timed, server-gated phase.

- **`MatchStates.Loading`** gained `ShowsLoadingScreen = true` (new
  `CORE_FLAGS` entry, all 7 states carry it) and flipped `KitGranted`/
  `AcceptsJoins` to `true` — characters spawn and kits grant **during**
  `Loading`, hidden under the curtain, not after it.
- **Client**: `ReplicatedFirst/LoadingCurtain.local.luau` builds an opaque,
  dependency-free curtain (`LoadingCurtainGui`, `DisplayOrder` 2000,
  `KeepDuringCamera`) before `ReplicatedStorage.Modules` even replicates.
  `UI/LoadingController` (required first in `ClientBootstrap`'s
  `GameServer` branch) adopts that same instance by name once `Modules`
  exists, runs four stages (replication → `ContentProvider:PreloadAsync` off
  `Shared/LoadingManifest` → local character/camera → server handshake),
  fires `MatchClientReady` once, then waits for `MatchInfo.MatchState` to
  leave `"Loading"` before fading. `UI/LoadingHud` is the pure-UI half.
- **Input lock**: `Shared/ControlLock` — a refcounted, reason-keyed
  replacement for the three previously-unrefcounted
  `PlayerModule.Controls:Disable()/Enable()` call sites
  (`ItemUseClient`/`CameraShelfClient`/`PlayerShop`, now all migrated onto
  it). `LoadingController` acquires `"MatchLoading"` for the duration.
- **`StarterPlayerScripts/CoreGuiController`** additionally disables
  `Backpack`/`Chat` CoreGuis while `MatchInfo.MatchState == "Loading"`,
  reacting to the attribute directly (same nil-tolerant pattern as
  `MissionHudController`) rather than coordinating with `LoadingController`.
- **Escape hatch**: `Loading` was added to
  `ReturnToLobbyService.ALLOWED_RETURN_STATES` so the client's hard
  watchdog (60s, no server response) can offer a working "Return to Lobby"
  button through the existing teleport-retry/kick path.
- Preload manifest (`Shared/LoadingManifest.Collect`) is deliberately
  narrow: monster/camera/pickup/support-item models + tool sounds. Map
  geometry is explicitly excluded — the engine streams it, and blanket
  preloading it was the biggest available regression risk.

### Mission List HUD — shared match-scoped progress, uncommitted

`Mission/MissionClient` (read-only mirror of `MatchInfo` attributes) →
`Mission/MissionHudController` (wires client to HUD, no heartbeat — repaints
on attribute change since mission values are event-shaped, not a clock) →
`Mission/MissionHud` (pure UI: Monster Photo score, Soft Objective count,
Document placeholder). Same three-layer split as `MatchTime`'s
Client/Controller/Hud. Required only from `ClientBootstrap`'s `GameServer`
branch — the Lobby never builds it.

Server side, `Match/MissionProgress` owns the shared (not per-player) counts:
photo score, soft-objective completions, and Document pickups. Documents are
counted from `PickupService.Collected`, not a marker attribute — a collected
pickup is destroyed, so there's no instance left to mark; the denominator is
therefore fixed at spawn count, not a live scan. `MissionReplicator` publishes
onto `MatchInfo` attributes only while `Playing`, the same
`ShowsMatchTime`-only convention the match clock uses — nil outside `Playing`
is "no mission list," not zero.

`HudLeftColumn` is new shared UI infrastructure: Cash and the Mission List
both parent into one left-column Frame so they share a single anchor and
`UIScale` and stack via `LayoutOrder` (Cash 1, Mission List 2) — the same
`AutomaticSize.Y` + `UIListLayout` shape `MatchTimeHud`'s announcer column
uses. Deliberately **not** tagged `KeepDuringCamera`: `CameraSession`'s
`hideOtherGuis` already hides any untagged, enabled ScreenGui on camera entry,
which is the behavior Cash's ScreenGui already had.

### Monster investigation / search overhaul — uncommitted

Extends the capability-driven Monster framework above with a real
investigate-and-search cycle, replacing whatever `States/Check.luau` did
before (585-line rewrite):

- `Components/Investigation` — decides **where** an LOS-loss, footstep, or
  other stimulus investigation should go and **why**. Ticks right after
  Targeting in the same `MonsterInstance:Tick`, so it always sees that
  frame's Targeting writes with no event subscription needed (same pattern
  Aggression uses against Perception). Sole writer of
  `Blackboard.InvestigationPosition/Reason/At`. `States/Check` reads only
  this channel — never `LastStimulus`/`LastKnownPos` directly — because
  Investigation is what enforces "a footstep never becomes a sighting."
- `States/Check` — branches on `InvestigationReason`. Visual (LOS loss):
  settle ~1s (`losdelay`) → relocate to a PatrolPoint continuing the escape
  route (360° discovery around the projected focus) → brief wander →
  walk to a relevant SearchPoint → `Behaviors/VisualScan` → linger 4-8s →
  give up to `Patrol`. Non-visual (heard stimulus/trail) presumably takes a
  shorter path directly to search — read the file before relying on the
  exact branch, this summary is from the header comment only.
- `Behaviors/VisualScan` — a transient (constructed-and-discarded, not a
  component) slow rotate-one-way-then-other-then-back search behavior.
  Perception keeps ticking independently during it, so a monster can be
  re-spotted mid-scan and resume `Chase` with no extra wiring.
- `Search/PointSelector` — one gate-and-rank engine shared by SearchPoint
  selection (hard directional cone) and PatrolPoint selection (360°
  discovery, direction is a soft bonus only), reusing Navigation's existing
  reachability/occlusion checks and `PatrolGraph`'s spatial scans rather than
  adding a second point-selection system. `States/Patrol`'s own selection
  logic is a separate, established caller.
- `MonsterConstants.luau` (new, `ReplicatedStorage/Modules/Monster/`) —
  centralizes attribute names and defaults the framework would otherwise
  spell as string literals/magic numbers. Deliberately does **not** own
  `IsMonster` — that stays with `Reward/CaptureTargets` per the existing
  attribute-ownership invariant.

Same map-authoring gap as before applies doubly now: this entire investigate
cycle needs `IsPatrolPoint`/`IsSearchPoint` parts placed, and **neither
published map has any** — falls back to `Wander` with a one-time warn.

### Capture registry + rewritten photo detection — uncommitted

`Reward/CaptureRegistry` — discovery/lifecycle for every capturable instance
in Workspace, generalized over every `CaptureTargets`-registered type
(Monster, Objective, future types) instead of `PhotoCapture` hardcoding
`IsObjective`/`IsMonster` scans itself. Modelled on
`Objective/ObjectiveRegistry`.

`PhotoCapture` is rewritten (240-line diff) from a 5×5 spread raycast to
angular candidate selection → geometry proof → line-of-sight confirm
(design in `plans/photo-capture-detection.md`, not read in full here). The
aim cone half-angle is claimed byte-identical to the old grid's outer ring —
the stated intent is every accuracy gain comes from removing false negatives
*inside* the cone, never widening it. `USE_CONE_DETECTION` gates the new path
so the old 5×5 path stays reachable as an instant rollback. **Check this flag
before relying on either path being active.**

### Document pickup — match-scoped mission collectible, uncommitted

`Pickup/PickupHandlers/Document` — grants no currency, no per-player state.
Collecting one *is* the event; `MissionProgress` (subscribed to
`PickupService.Collected`) owns the shared count. Not gated on `KitGiven`
(that gate exists only to stop a late kit grant overwriting
`leaderstats.Cash`, and this handler never touches the wallet). Same
disposal semantics as every other pickup — nothing persists past the match.

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

### Monster AI framework (Game place only) — capability-driven, component-based

Fully rearchitected off the old single-script `MonsterAgent`. A monster is a
`MonsterConfig` row (`ReplicatedStorage/Modules/Monster/Configs/<Id>.luau`) —
`Capabilities` (`MonsterCapabilities.luau`) decide which `ServerScriptService/
GameService/Monster/Components/*` get constructed, which `States/*` become
eligible, and which `Stimulus/StimulusKinds` get subscribed. Adding a monster
is one config file; no existing file changes. `Monster1` is the only
shipping monster today — the old `GreyCube` placeholder is deleted.

Per-instance: `MonsterInstance` ticks `Components` in a fixed dependency
order (Perception → Targeting → Aggression → Navigation → Combat), then
`Brain` (`Brain/Brain.luau`) scores every eligible `States/*` module and
`StateMachine` runs the winner. Bands are hard precedence (Attack > Chase >
everything else); within a band, highest weighted `Score()` wins, with
hysteresis against flapping. `MonsterBus` is per-instance pub-sub for
same-tick events (`Arrived`, `StimulusReceived`, `Evolved`...); cross-service
signals (`MonsterRegistry.Spawned`/`Died`) use `Shared/Signal` instead — do
not mix the two.

**Patrol is the actual default state** (Band 0, scores above `Wander`).
`PatrolGraph.luau` scans Workspace once at boot for `IsPatrolPoint`/
`IsSearchPoint` parts (same convention as `IsMonsterSpawn`) and answers
spatial queries; connectivity is **implicit by distance**, no authored link
data. `States/Patrol.luau` walks the network with junction-aware direction
choice (uniform over left/right/forward buckets, not over points), a last-2
history ring against oscillation, occasional `SearchPoint` detours, and an
occasional stop-and-look pause at a PatrolPoint (`Stats.PatrolPauseChance`,
multiplied to 0 by the evolution tier below). Candidate points are filtered
by `Navigation:HasLineOfSight` first — a monster will not pick a destination
through a wall, only falling back to an occluded one if nothing visible
exists within range. **Neither published map has any `IsPatrolPoint`/
`IsSearchPoint` parts placed yet** — until they are, `Monster1` falls
straight through to `Wander` with a one-time warn; this is a map-authoring
gap, not a code gap.

Perception is capability-gated sensors (`Sensors/Vision|Hearing|Flash|
Proximity`) plus a global `Stimulus/StimulusBus` for footsteps
(`FootstepEmitter`) and camera flashes (`FlashStimulusAdapter`, which
subscribes to `Flash/FlashEvents` — that publisher now has a real
subscriber). `Targeting:FollowTrail` lets a lost-but-still-sprinting target
be re-acquired from a fresher heard stimulus instead of the chase dying at
stale `LastKnownPos`. `Evolution` (Stats-only mutation, hour-gated via
`MatchTimeEvents`) is live on `Monster1` — the `Witching` tier fires at hour
27, multiplying `WalkSpeed` and zeroing `PatrolPauseChance`. The rest of the
tier schema (capability grants, new states/abilities) is **not**
implemented; full design and rationale in `plans/EvolutionPlan.md`.

### Pickup System — hand-placed in v1, visuals are place-agnostic

`GameService/Pickup/` (`PickupRegistry`, `PickupPrompt`, `PickupService`,
`PickupHandlers/`, `PickupCleanupHook`) + `Player/CashWallet.luau` are wired
into `GameBoot` only — a pickup placed on the Lobby has no prompt and grants
nothing there.

`PickupVisualsController` (client, idle spin + light pillar) is the
exception: it's wired unconditionally into `ClientBootstrap` on **both**
places, since it only watches the shared `IsPickup` attribute and has no
dependency on the server-side registry or match state. Net effect: a pickup
placed on the Lobby spins and glows exactly like one on the Game place, but
is never interactable and never pays out there.

- **Identity is two attributes**, same shape as `IsMonsterSpawn`/`MonsterId`:
  `IsPickup` (discovery marker) and `PickupType` (row key into
  `ReplicatedStorage/Modules/Pickup/PickupTypes.luau`). Both strings are owned
  exclusively by `PickupTypes` — read `PickupTypes.MarkerAttribute`/
  `.TypeAttribute`, never hardcode them.
- **No spawner yet.** Pickups are hand-placed in Workspace and copied out of
  `ReplicatedStorage.Assets.Pickup.<Type>` by a designer, must be **Anchored**
  and have a `PrimaryPart` if a Model. A `PickupSpawner` (markers +
  server-side cloning at match start, mirroring `Monster/EncounterDirector`)
  is the intended next step and needs no change to the registry/service/
  handlers to add.
- **Race safety has no lock object** — `PickupService` claims an instance in
  a `claimed[instance] = true` table with no yield between the validation
  chain and the claim, relying on Luau's cooperative scheduling to serialize
  two same-frame triggers. Any future handler that yields (a DataStore write,
  an async call) **must** claim first, then yield — never the reverse.
- **Cash is per-life, same as the existing starter-kit Cash.** A pickup's
  cash is wiped by `EndGame` on death/match end exactly like the starter
  stipend — this was a deliberate decision, not an oversight; revisit only if
  playtesting says it feels punishing.
- **No new remotes.** `ProximityPromptService.PromptTriggered` fires
  server-side with the triggering player — the whole flow is server-only.

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

### Movement authority — server-owned (both places)

`GameService/Player/CharacterMovementService.luau`, booted early in both
`GameBoot` and `LobbyBoot`. It owns every Humanoid movement property and the
stamina number.

- **Why it must be server-side.** Live Roblox servers validate character
  motion against the **server's** copy of `Humanoid.WalkSpeed`, and a
  LocalScript's writes to Humanoid properties no longer replicate. The client
  setting `WalkSpeed = 0` (so its `LinearVelocity` drive owns X/Z) left the
  server believing the default 16: walking passed, sprinting was rejected and
  rubber-banded. Studio does not run that validation — **this class of bug is
  invisible in Studio and only appears on a published build.**
- **WalkSpeed is a budget, set per sprint state**, at
  `walk-or-sprint × BUDGET_HEADROOM` (1.15). The headroom absorbs slopes,
  knockback and the client's accel-lerp overshoot; it is too small to spend as
  a second sprint.
- **WalkSpeed/SprintSpeed/MaxStamina are per-player buffable** (`Pills`,
  `AdrenalineShot`, `EnergyDrink`) via `Player/PlayerEffects` — a delta stored
  against the `PlayerStats` base, additive and independently timed, never a
  captured/restored absolute (see that module's own header for why). Every
  reader of these three stats goes through `PlayerEffects.GetStat`, never
  `PlayerStats.Get`, on both server and client — the client's copy arrives
  over the widened `StaminaSync` payload (`{stamina, maxStamina, walkSpeed,
  sprintSpeed}`, not a bare number) and is mirrored onto `PlayerRuntimeStats`.
  A movement HOLD (`ItemUseService`, during a 3s item use) is a separate,
  stronger override — `CharacterMovementService.SetMovementLocked` forces the
  budget to 0 regardless of any buff.
- **The client still zeroes `WalkSpeed` locally** and re-zeroes it whenever the
  server's value replicates down — otherwise the engine's own movement fights
  the `LinearVelocity` drive.
- **Sprint is a request.** Client fires `SprintRequest(bool)`; the server
  grants only if its own stamina allows. Stamina replicates back on
  `StaminaSync(stamina)` at 10 Hz, and is mirrored to `Player` attributes
  `Stamina`/`Sprinting` purely so the value is inspectable from Studio.
- **The client does not simulate stamina.** It renders the synced number. An
  earlier split where both sides ran the drain/regen rule made the bar appear
  frozen whenever the two disagreed — see the invariant below.
- **Jump cooldown** (`PlayerStats.JumpCooldown`, 0.3s) runs from **landing**,
  not takeoff — a jump's airtime exceeds the cooldown, so a takeoff-anchored
  timer rate-limits nothing. Enforced on the client (where the character is
  simulated, and so where the player feels it) and on the server.
- **Shift lock is force-disabled** (`StarterPlayer.EnableMouseLockOption` plus
  per-player `DevEnableMouseLock`): its switch binds Shift and swallowed the
  sprint key.

### Sprint input — one intent cell, many devices

`ReplicatedStorage/Modules/Movement/SprintIntent.luau` is a client state cell
(`Get`/`Set`/`Changed`, no Instances, no remotes). Every input device writes
it; `Playermovementcontroller` is the **only** subscriber and the only place
that applies the stamina gate, fires `SprintRequest`, and drives top speed and
FOV. Adding a device means writing intent, not repeating that sequence.

`StarterPlayerScripts/MobileSprintButton.local.luau` — touch sprint, **tap to
arm**:

- Tapping arms; it does not change speed. Armed **+ joystick moving** sprints.
- **The button is a toggle** — tapping while armed cancels, so a player can
  drop back to a walk mid-run without letting go of the joystick. Cancelling
  also resets the release tracker, or a cancel mid-run would leave a stale
  release pending that disarms the *next* tap.
- Nothing in the button writes `SprintIntent` directly: the RenderStepped loop
  is its single writer (`armed and stickActive`). Arming and cancelling only
  move the `armed` flag, and the loop picks it up on the next frame.
- **Sprint is refused entirely while in camera mode** (`CameraState.Get()`),
  and opening the camera mid-sprint clears the intent. Client-side only, by
  design — see Known broken/deferred.
- Letting the joystick centre disarms — sprinting again needs a fresh tap.
  Disarm triggers only on a genuine active→inactive release; disarming on a
  merely-centred stick clears the arm one frame after the tap and makes the
  button look dead.
- Always visible during a touch session, at a **frozen** home position captured
  once from the joystick's resting centre. `DynamicThumbstick` leaves
  `ThumbstickStart` wherever the last touch landed, so re-reading it later
  strands the button wherever a run happened to start.
- A stretch/gesture trigger was built and removed — it fired during ordinary
  movement often enough to be unpredictable.

## Architecture invariants

Rules that outlive any single file. Violating one is a bug even if it works.

- **Config in data tables, not logic.** `CameraStats`, `MonsterStats`, `RewardTypes`, `CaptureTargets`, `ObjectiveTypes`, `MatchConfig`. Adding a camera/monster/reward/target/mode = one table row, no new script.
- **Enum as data.** States are rows with flags (`ObjectiveStates`, `MatchStates`, `PlayerStates`). Never branch on a state *name*; read its flag. Predicates fail closed on unknown states.
- **Replication split.** Shared state → Instance attribute (auto-replicates). Per-player state → RemoteEvent + snapshot on join/`CharacterAdded`. Attributes cannot express per-player values.
- **RemoteEvents only.** Zero RemoteFunctions in the repo. Client fires a request; server replies on a separate `*Result`/`*Feedback` remote with a **code string**; a shared `*ResultCodes` module maps code → message. Some flows (queue pads) have no client-initiated request at all — server-sensed state replicates via attributes instead, and the remote exists only for one-off result messages.
- **All remotes registered** in `Remotes.ALL_NAMES`; `Remotes.Init()` provisions them (server, from `Bootstrap.legacy.luau`). Never `WaitForChild` a remote by hand.
- **Ownership is symmetric.** Whoever acquires a GUI/effect/connection releases it, by reference, via a `Trove` — never by name lookup.
- **Freezing player input goes through `Shared/ControlLock`**, never a bare `PlayerModule.Controls:Disable()/Enable()`. The raw switch is shared and unrefcounted — two independent freeze reasons stomp each other. `Acquire(reason)`/`Release(reason)` compose; every current caller (loading curtain, camera shelf, item-use hold, CCTV view, shop) is migrated onto it.
- **No reward amount ever crosses a remote.** `RewardService` is the only sink.
- **Server reads attributes off the server-observed instance**, never client-declared identity.
- **Countdowns cross the wire as a deadline, never a remaining duration.** A `workspace:GetServerTimeNow()` timestamp the client subtracts locally, so its tick cannot drift and costs nothing per second. Used by `QueuePadEndsAt`, `MatchResultSync.returnsAt`, and the `MatchTime*` anchors. Corollary: **one owner computes the deadline, everyone else reads it** — `MatchClock.GetEndingDeadline()` anchors on first request precisely so the receipt's countdown and the real `Cleanup` transition can't disagree.
- **One simulator per value.** If the server owns a number, the client renders it — it must not run the same rule in parallel "for smoothness". Stamina was simulated on both sides against one shared rule; the moment the two disagreed the sync stomped the client every tick and the HUD looked frozen. Prediction is a deliberate exception, not a default, and needs a written reconciliation rule.
- **Defaults are for display, never persistence.** If you can't distinguish "no data" from "couldn't read data", do not write.
- **Identity by attribute, never by `.Name`.** `IsMonster`/`IsObjective`/`QueuePadSize`/etc. — a rename or a "Camera" collision must not change behavior.
- No `--!strict`. No circular dependencies (graph currently reports **zero** import cycles — protect that).

## Systems

| System | Status | Notes |
|---|---|---|
| Movement / FOV / camera tilt | works | client `LinearVelocity`, asymmetric smoothing; speed budget is server-set — see Movement authority |
| Sprint / stamina / jump cooldown | works | server-authoritative (`CharacterMovementService`); client renders, never simulates |
| Mobile sprint button | works | tap-to-arm, `MobileSprintButton.local.luau`; touch only |
| HUD (stamina) | works | `StarterPlayerScripts`, **not** `StarterGui` — see G1 |
| Inventory slots + shop | works | `ShopCatalog` (7 support items) drives price/description/UI; server-authoritative buy through `CashWallet`; empty slots tagged `IsEmpty`, held items tagged `ItemId`; Game place only |
| Support item gameplay | uncommitted, unverified | Generic 3s hold-to-use lifecycle (`Item/ItemUseService`, client `ItemUseClient.local.luau`) reads `ShopCatalog.Effect`; per-player stat buffs go through `Player/PlayerEffects` (deltas, not absolutes — additive/independent-timer stacking); Motion Sensor/Compact Speaker/Portable CCTV are placed world objects under `workspace.Deployables` via `Item/ItemWorld/*`. Needs `Assets.Tool.SupportItem.ItemRemotes.*` and `Assets.Tool.SupportItem.PlacedItem.*` authored in Studio — see `plans/create-a-read-only-implementation-foamy-cookie.md` |
| Flashlight | works | `Player/FlashlightService`, both places now (ported from Map0-only — see Phase note below); Brighter Flashlight's range/brightness bonus goes through `PlayerEffects`, not `PlayerStats.Set` |
| Currency UI | works | remote-driven |
| Camera framework | works | client session/viewfinder/touch HUD + shelf; one `Trove` per session |
| Photo capture → reward | works | 5×5 spread raycast → `CaptureTargets.Resolve` → `RewardService` |
| XP persistence | works | ProfileStore (`RewardStore_v2`), real session lock. `RewardStore_v1` is a legacy read path only — see Tracked sunset conditions |
| Match time / sunrise ending | works | Game place only; `MatchTime/` server + shared. Single authority on match length — see Match time above |
| Match time HUD | works | top-centre bar + hour label, `DisplayOrder` 20, `KeepDuringCamera`. Client renders from replicated anchors; never simulates |
| Monsters | works | Capability-driven component architecture (`Monster/`); see Phase section above. `Monster1` only; Patrol is the default state but has no map points placed yet |
| Objectives | works | registry/service/replicator + client visuals |
| Flash | works | client `FlashSignal` → screen + world-light renderers; server `FlashEvents` publishes to `Camera` clients and now also to `Stimulus/FlashStimulusAdapter` for monster perception |
| Touch-device detection | works | `Shared/TouchSession.IsActive()` — the single answer, called never cached; see G6 |
| Mobile landscape lock | works | `ScreenOrientationController.local.luau` — `LandscapeSensor`, re-applied on change (see G19). No-op on desktop |
| Spectate | works | `Custom` + `CameraSubject` with a re-assert guard — see G12; camera resolved per call, never cached |
| Death → kit teardown | works | `KitLifecycleHook` calls `EndGame.ClearPlayerTools` on death (tools used to survive into spectate); `SpectateHud` hides the Backpack CoreGui while spectating |
| Matchmaking (queue pads) | works | see Phase section above |
| Party | server-only | see Phase section above — no client surface |
| Loadout persistence | works | camera choice survives teleport and rejoin |
| Pickup / Cash collection | works | Prompt + grant are Game place only; visuals are place-agnostic; hand-placed pickups, no spawner yet — see Phase section above |
| Match layer (`GameService/Match/*`) | uncommitted, unverified | Formal phased lifecycle replacing prior ad hoc glue — see Phase section above |
| Match loading screen | uncommitted, unverified | Real, timed `Loading` phase + client curtain, server-gated on `MatchClientReady`/`LoadingTimeout` — see Phase section above and `plans/match-loading-screen.md` |
| Mission List HUD | uncommitted, unverified | Shared match-scoped progress (photo score / soft objectives / documents) — see Phase section above |
| Monster investigation/search overhaul | uncommitted, unverified | `Investigation` + `VisualScan` + `PointSelector`; needs the same unplaced Patrol/Search points as Patrol |
| Photo capture (cone detection) | uncommitted, unverified | Rewritten from 5×5 grid to angular-cone detection behind `USE_CONE_DETECTION`; old path still reachable |
| Document pickup | uncommitted, unverified | Match-scoped mission collectible, no currency |
| Match-time announcer (countdown / 3 AM enrage) | uncommitted, unverified | Plan says "not implemented" but the files exist and are wired — verify against `plans/match-time-announcer.md`'s checklist before trusting either claim |
| Responsive HUD scaling | implemented per plan, unverified this session | `UIScaleController` + Cash/MatchTime/Stamina holders — see `plans/responsive-hud.md` |

## Half-built / not wired

- **`RewardModifiers`** — registry exists, zero entries. The Combo/Streak/Event seam, unproven.
- **`MatchTimeEvents`** — registry + monotonic-cursor dispatcher exist and are exercised by the clock, but ship with **zero registered entries**. The seam for timed spawn waves / extraction windows.
- **`MatchPhases` flags beyond `MonsterStage`** — `MonstersAggressive` and `ExtractionOpen` are declared and read by nothing yet.
- **`Monster1` Stage 2 / Evolution numbers** — real and reachable (`DeepNight` at hour 24, `Witching` evolution tier at hour 27), tuned by eye against the player's `WalkSpeed`/`SprintSpeed`, not by playtest. See tuning comments in `Configs/Monster1.luau`.
- **Evolution's non-Stats tier schema** (capability grants, new states/abilities) — see `plans/EvolutionPlan.md`.
- **PatrolPoint/SearchPoint authoring** — `PatrolGraph` and `States/Patrol.luau` are complete; neither published map has any points placed. Patrol falls back to `Wander` until they exist.
- **`SoundIds.luau`** — TODO stub.
- **Party client surface** — see Phase section above.

## Known broken / deferred (accepted)

| Issue | Impact | Why deferred |
|---|---|---|
| `origin` is client-supplied | Spoofable shot origin | `CaptureGuard.ValidateShot` 10-stud proximity check is a mitigation; server-derived origin is a larger change |
| Camera-mode sprint block is client-side only | A modified client can still sprint while scoped | The only server-side signal is `CameraSessionTracker`'s client-reported InCamera flag, which must never back a server-authoritative check. It is a UX rule; the WalkSpeed budget still caps absolute speed |

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
- **G6 — Studio reports `TouchEnabled` *and* `KeyboardEnabled` true — in Play Solo *and* under Test → Device emulation** (the developer's real keyboard keeps the latter true). A `TouchEnabled and not KeyboardEnabled` gate is therefore wrong: always wrong on a touchscreen laptop, and **nondeterministic under emulation** — measured, `KeyboardEnabled` can read false at module-load and true a moment later, so a gate cached at load flips between sessions with no code change. (That race is why `CameraTouchHud` appeared *sometimes*.) **Use `Shared/TouchSession.IsActive()`** — never hand-roll this again, and never cache its result, since a phone preset selected after Play never reaches a script that already decided. Both former offenders (`CameraTouchHud`, `MobileSprintButton`) now go through it.
- **G7 — Studio API Services off** ⇒ every join lands in `RewardStore` state `Failed`: XP shows 0 and *nothing is written*. Real data stays intact. Not a bug.
- **G8 — `ServerScriptService` modules are unreachable from clients.** Shared code must live in `ReplicatedStorage`.
- **G9 — Roblox does not guarantee Script execution order.** `Bootstrap.legacy.luau` is a decoupling point, *not* an ordered bootstrap. Boot order for a place's services comes from the ordered list in its `Boot/*Boot.luau` `Start()` call, not require order.
- **G10 — `ReserveServer`/`TeleportAsync` return HTTP 403 in Studio Play/Test, even against a published place.** `GetAsync`/`SetAsync` and other DataStore calls **do** work in Studio Play with API Services on (see G7) — don't conflate the two. Matchmaking's launch step (`MatchLauncher`) can only be verified end-to-end on a published two-place build, never in Studio.
- **G11 — `Signal:Fire` (the shared `BindableEvent` wrapper) is deferred.** A synchronous read of an attribute or state immediately after the `Set`/`Fire` that changed it sees the *previous* value. Needs a `task.wait()` between the write and the read whenever testing from the command bar or a test script.
- **G12 — Spectating is `CameraType.Custom` + `CameraSubject`, NOT `Scriptable`.** (This entry previously said the opposite; that was wrong and it broke spectate.) `Scriptable` means "no engine camera logic at all" — the engine stops writing `CFrame` and **ignores `CameraSubject` entirely**, so the camera freezes where it stood while the HUD happily names a target. `Custom` is what follows a subject. Its one cost is that Roblox's camera scripts reassign `CameraSubject` to the local humanoid on respawn — re-assert it rather than giving up engine camera control. Also: `Camera.CameraSubject = nil` does not clear it (a free-camera fallback needs a real anchored Part), and **never cache `Workspace.CurrentCamera` at require time** — the engine replaces it on respawn/teleport and every write then lands on a camera nobody is rendering.
- **G14 — Client writes to Humanoid properties do not replicate, and live servers validate motion against the server's copy of `WalkSpeed`.** Anything that moves a character faster than the server's `WalkSpeed` is rejected on a published build and rubber-bands. Studio does not run this validation at all, so **it looks perfect in Studio and fails live**. Movement budgets must be server-set — see Movement authority.
- **G15 — `UIBuilder.CreateScreenGui` returns ScreenGuis with `Enabled = false`.** Every caller opts in. Forgetting it renders nothing regardless of `Visible`, with no error — it looks exactly like the script never ran.
- **G16 — `TouchGui.TouchControlFrame.DynamicThumbstickFrame` is a ~420×322 region covering the whole bottom-left.** Any touch UI placed there must outrank `TouchGui` (`DisplayOrder` 0) or it renders under the stick — pick a value from the registry in `UIBuilder.CreateScreenGui`'s comment, and never reuse an existing one. `ThumbstickStart` is present and visible **even at rest** (this layout draws a resting ring), so it cannot be used as an "is the player touching the stick" signal — use move-vector magnitude. It also stays wherever the last touch landed, so it is not a reliable home position after the first drag.
- **G17 — Stick *displacement* is only available from `ControlModule:GetMoveVector()`** (magnitude scales 0..1 with the push, capped at 1). `Humanoid.MoveDirection` is normalized — identical at a nudge and at full stretch — so it can answer "is the player moving" and nothing more.
- **G19 — `PlayerGui.ScreenOrientation` written once at client start silently loses.** Measured: the write appears to succeed, then reads back as `Sensor` seconds later with no error and nothing observably reverting it — a StarterPlayerScripts LocalScript runs before the engine finishes seeding PlayerGui from StarterGui. A write made *later* in the same session holds and survives death/respawn, so it is a startup race, not a repeated overwrite. Re-apply via `GetPropertyChangedSignal("ScreenOrientation")`. Note also that setting `StarterGui.ScreenOrientation` does **not** update an existing PlayerGui — it is only the seed for a new one.
- **G18 — MCP input automation lands in Studio-window coordinates, not the emulated viewport's.** Measured: a click sent at `x=66` arrived in-game at `x=19` (~47px X offset; Y matched). A synthetic tap that "does nothing" is usually missing the target, not being consumed — verify by logging `UserInputService.InputBegan` position before concluding anything about input ownership.
- **G20 — Roblox does not guarantee the order of multiple handlers connected to one event.** G9 is about Script execution; this is about `Connect` order on a single signal, and it is *not* registration order you can rely on. Measured: a listener connected *after* `MatchClock`'s read `GetEndingDeadline()` in the same `StateChanged` batch and got `nil`. **Never let one handler depend on another handler of the same event having already run.** Fixes that do work: compute-on-first-request (what `MatchClock.GetEndingDeadline` does), or publish a distinct signal the consumer subscribes to instead (`MatchTimeService.Started`/`Stopped` exist for exactly this). A value fired deferred *from inside* a handler does resolve in a later batch, so that ordering is safe.
- **G21 — `guardNonReservedServer()` stops the whole Game-place boot in Studio** (`game.PrivateServerId == ""`), so `GameBoot`'s ordered service list never runs and no match ever starts. To exercise the real boot list in Studio, temporarily comment the `if guardNonReservedServer() then return end` block and point `MatchConfig.Modes.Default.ScheduleId` at `"Debug"` — **then revert both**; grep for leftover markers before committing. Without that bypass the only way to test is to start services by hand, which does not prove boot order.
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
| `Stamina` / `Sprinting` | Player | Server-written by `CharacterMovementService`, for observability only. Nothing reads them — the HUD goes through `StaminaSync` |
| `QueuePadSize` | the pad's `Zone` Part | Queue pad capacity (1/2/4). Owned by `QueuePadService` |
| `QueuePadLabel` | a Part inside the pad model | Marks which descendant carries the display `BillboardGui`/`TextLabel` |
| `QueuePadCount` / `QueuePadCapacity` / `QueuePadEndsAt` | the pad's `Zone` Part | Server-written, read-only display state. `QueuePadEndsAt` is `0` when idle, else a `workspace:GetServerTimeNow()` deadline |
| `MatchState` | `ReplicatedStorage.MatchInfo` Folder | Current `MatchStates` name. Written by `MatchReplicator` |
| `LoadingReadyCount` / `LoadingReadyTotal` | same `MatchInfo` Folder | `MatchLoadingGate`'s ready ledger, mirrored by `MatchReplicator`. **Nil outside `Loading`** — same nil-outside-scope convention as the match time anchors below |
| `MatchScheduleId`, `MatchTimeStartedAt`, `MatchTimeEndsAt`, `MatchTimeAnchorAt`, `MatchTimeAnchorHour` | same `MatchInfo` Folder | Match clock anchors, written by `MatchTimeReplicator`. **All nil outside `Playing`** — absent must read as "no match time", never hour 0. `AnchorAt`/`AnchorHour` equal `StartedAt`/`StartHour` unless a schedule is swapped mid-match |
| `IsMonsterSpawn` | Part or Model, Workspace | Hand-placed monster spawn point. Optional `MonsterId` (default `Monster1`) and `Stage` (default 1) |
| `MonsterId` / `Stage` | spawned monster Model | `Stage` here is the **effective** stage and is rewritten on every re-stage — the authored floor lives on the spawn point, not on this |
| `EvolutionTier` / `AIState` / `AggressionLevel` | spawned monster Model | Replicated for client-side reads: current evolution tier name, current state name, quantised aggression band (`Low`/`Medium`/`High` — not the raw scalar, see `MonsterConstants.AggressionLevels`) |
| `IsPatrolPoint` / `IsSearchPoint` | invisible Part, Workspace | Hand-placed Patrol network node / secondary investigation spot. Optional `MonsterId` to restrict to one monster type. None placed yet in either map — see Half-built |
| `IsPickup` / `PickupType` | Model or Part, Workspace | Pickup identity. Owned by `Pickup/PickupTypes.luau`; never hardcode elsewhere |
| `PickupAmount` | same instance | Optional per-instance override of a Cash pickup's `Params.Amount` |

**ScreenGui DisplayOrder registry** (full list + rationale lives in
`UIBuilder.CreateScreenGui`'s comment — pick a gap, never an existing value):

| Order | ScreenGui |
|---|---|
| 0 | Roblox `TouchGui` (engine-owned), and most of this repo's GUIs |
| 15 | `ItemUseGui` — support-item hold progress bar + Motion Sensor warning |
| 20 | `MatchTimeGui` — top-centre match clock; loses to the sprint button and both modals |
| 30 | `MobileSprintGui` — beats `TouchGui`, loses to both modals |
| 40 | `DeathScreenGui` |
| 50 | `MatchReceiptGui` |
| 100 | `CameraTouchHud` |
| 1000 | `ScreenFlashRenderer` |
| 2000 | `LoadingCurtainGui` — match loading screen; must beat everything, including the camera flash |

**Asset paths** (tree structure differs — don't assume parity):
- `ReplicatedStorage.Assets.Tool.SupportItem`
- `ReplicatedStorage.Assets.Tool.SupportItem.ItemRemotes.{CompactSpeakerRemotes, PortableCCTVTablet}` — **post-use replacement tools, not shop stock.** The shop grants the plain `CompactSpeaker`/`PortableCCTV` Tool from `SupportItem`; using it places the world object and swaps the held Tool for the matching one here (`ShopCatalog`'s `ReplaceWith`). Both have `Enabled = false` catalog rows so they resolve an asset and an ItemId but can never be bought
- `ReplicatedStorage.Assets.Tool.SupportItem.PlacedItem.{PlacedMotionSensor, PlacedCompactSpeaker, PlacedPortableCCTV}` — the world objects Deploy-kind items place; `PlacedPortableCCTV` needs a child Part named `Lens` (falls back to `PrimaryPart`) as the CCTV camera subject. Missing asset degrades to a `"Failed"` ItemUseResult, no hard error
- `ReplicatedStorage.Assets.Tool.Camera.Camera1`
- `ReplicatedStorage.Assets.Pickup.Cash` — Studio-authored, Anchored, `PrimaryPart` set if a Model
- `ReplicatedStorage.Sounds.Tool.FlashLightSound` — needed by both places now that Flashlight is ported to Lobby too
- `ReplicatedStorage.Sounds.Tool.CompactSpeakerSound` — cloned onto the placed speaker when its remotes arm it, and looped for the active window. Server-created on a replicated part, so every client hears it positionally. Missing clip = a silent but still functional lure (warn only)

**Security boundary:** `CameraSessionTracker`'s InCamera flag is client-reported — UX guard only, never a security check.
