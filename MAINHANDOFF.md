# MAINHANDOFF — current state

Agent-facing. Current phase only, no history. Git has the changelog.
Module behavior lives in the code and `graphify-out/GRAPH_REPORT.md` — not here.

## Phase

Single-server vertical slice, feature-complete enough to play: move → buy camera →
photograph monsters/objectives → earn XP+Score. XP persists.

**Next:** rearchitecting to Lobby Server + reserved Game Server (matchmaking, match state
machine, player state machine, death/spectate, end-match teleport). Blueprint at
`~/.claude/plans/planning-mode-do-not-rustling-firefly.md`. That plan is the spec; if it
disagrees with disk, disk wins.

**Phase 0 (teleport spike) — DONE.** Confirmed on a real live server: `ReserveServer` +
`TeleportToPrivateServer` from this place (Lobby, `PlaceId 91205326584169`) into the new
Game place (`PlaceId 100171816233157`, same universe `GameId 10535406765` — required for
`RewardStore_v1` to stay shared), then `Teleport` back. Both places must be joined via the
real Roblox client to test `TeleportService` calls — **Studio's Play/Test tab returns
HTTP 403 on `ReserveServer` even against a published place**; this is Roblox blocking
server-initiated teleport APIs from non-production test sessions, not a code bug.

Both throwaway halves deleted — Lobby's script+button, and the Game place's
`Spike0_ReturnToLobby` script + `SpikeReturnButton` part. **One leftover was found and
fixed during Phase 1 verification**: a duplicate of the Phase 0 return script had been
renamed to the generic default `Script` at some point (Studio session disconnect/reconnect
churn) and was missed by the first cleanup pass since it no longer matched the name being
searched for — deleted now, confirmed clean. Game place still needs a republish so this
takes effect live; not urgent (place is non-joinable).

**Phase 1 (Server Role + boot lifecycle) — DONE, verified on both places via real Play
sessions.** Added: `Shared/PlaceIds.luau`, `Shared/ServerRole.luau` (`Get`/`Is`/
`AssertGameServer`/`AssertLobbyServer`, resolves once from `game.PlaceId`, no setter),
`GameService/Boot/LobbyBoot.luau` + `GameService/Boot/GameBoot.luau` (ordered `Start()`
lists, currently empty — every later phase adds its service here, not via self-wiring).
`Bootstrap.legacy.luau` and `ClientBootstrap.local.luau` branch on `ServerRole` and dispatch
to the matching Boot module. `GameBoot` sets `Players.CharacterAutoLoads = false` and
refuses to start a match on a non-reserved server (`PrivateServerId == ""`), instead
teleporting arrivals back to the Lobby — confirmed firing correctly in a direct Play test.

**Two-place code sync is currently manual, not automatic.** This repo's file tree only
live-syncs to BaseGame (Lobby, `PlaceId 91205326584169`). The Game place
(`PlaceId 100171816233157`) has no local mirror — I hand-mirrored just the four Phase 1
files there via Studio MCP (`ReplicatedStorage.Modules.Shared.{PlaceIds,ServerRole}`,
`ServerScriptService.GameService.Boot.{LobbyBoot,GameBoot}`), plus a minimal
`Bootstrap.legacy` Script there containing only the role-branch dispatch (no
`Remotes.Init()`, no `ObjectiveService` requires — that content doesn't exist on this place
yet). **The existing gameplay codebase (Camera/Reward/Objective/Monster/Shop/etc.) has not
been migrated to the Game place at all.** That's a separate, larger content-migration task,
not part of Phase 1 — needs a decision on approach (manual Studio mirroring vs. a real
Rojo-style multi-place sync) before Phase 4+ (Match/gameplay systems) can be verified there.

**Phase 2 (state enums) — DONE, verified on both places via real Play sessions.** Added
`Shared/MatchStates.luau` (7 states: `Loading`/`WaitingForPlayers`/`Countdown`/`Playing`/
`Ending`/`Cleanup`/`Finished`), `Shared/PlayerStates.luau` (5 states: `Alive`/`Dead`/
`Spectating`/`Disconnected`/`Leaving`; `Downed`/`Reviving`/`Respawning`/`Observer` are
documented as future, not implemented), `Shared/MatchConfig.luau` (per-mode tunables,
one `Default` mode). Both enums expose `Validate()`, wired into boot: `GameBoot` validates
both (Match layer is Game-Server-only); `LobbyBoot` validates only `PlayerStates` (Match
State never touches the Lobby) — this split is my interpretation of the plan's "GameBoot/
LobbyBoot call it" wording, not spelled out verbatim there.

Verified: real tables pass `Validate()` on both places; predicates fail closed on an
unknown state (confirmed via `IsGameplayActive("NotARealState") == false`); legal/illegal
transitions match spec (`Dead→Spectating` legal, `Alive→Spectating` illegal — must route
through `Dead`); a deliberately typo'd transition target reproduces the *"is not a valid
state"* assertion (tested against an isolated broken copy, not the real module).

**Phase 3 (`PlayerStateService` + replicator) — DONE, verified on both places via real
Play sessions.** Added `PlayerState/PlayerStateService.luau` (`Get`/`Set`/`Is`/`GetAll`/
`StateChanged`, userId-keyed internal map, seeds new players to `Alive`, rejects illegal
transitions and invalid state names without coercing) and `PlayerState/
PlayerStateReplicator.luau` (mirrors state onto the `PlayerState` attribute; no remote yet
— no per-player-private detail exists to replicate until a later phase needs one). Both
wired into `LobbyBoot`/`GameBoot`'s ordered service list, `PlayerStateService` before
`PlayerStateReplicator` (publisher before subscriber).

Verified end-to-end on both places: new players seed to `Alive` with the attribute
appearing correctly; `Alive→Dead→Spectating` succeeds and each hop replicates to the
attribute; `Alive→Spectating` directly is correctly rejected (must route through `Dead`);
an invalid state name is rejected. Two things worth remembering for next time:
- **`Signal:Fire` is deferred** (BindableEvent) — a synchronous test script that sets state
  and immediately reads the attribute will see the *previous* value. Needs a `task.wait()`
  between the `Set`/seed and reading the replicated attribute.
- **Hit MAINHANDOFF's own G3 gotcha directly**: testing `PlayerStateService`'s internal
  `states` table via `execute_luau` needs the whole chain (`Start()` + assertions) driven
  from one call — a second `execute_luau` call gets a fresh isolated copy with an empty
  table, even though it correctly shares state with *other* `execute_luau` calls in the
  same session (only real running Scripts are invisible to it). Attributes are the
  reliable cross-check either way, since they're real Instance properties.

**Deviation from plan:** "PlayerRemoving → Disconnected if the match is live, or Leaving
if the match is over" (plan section 6) can't be implemented as written yet — `MatchManager`
doesn't exist until Phase 4, and `PlayerStateService` must not require it anyway (would
violate its own "must not know why a state changed" boundary). Implemented instead:
`PlayerRemoving` prefers `Disconnected` (legal from every non-terminal state, keeps
reconnect open) and falls back to `Leaving` only if `Disconnected` isn't legal. Revisit
once `MatchManager` exists — Phase 4 may want to inject a real liveness check.

**Found, not fixed (fixed in-session):** the Game place's mirrored `PlayerStateService`
required `Shared/Signal.luau`, which I'd never mirrored there in Phases 1-2 — first test
threw "module experienced an error while loading" until this was added. Fixed by mirroring
`Signal.luau`; worth double-checking the Game place has every `Shared/` module a new file
requires, since nothing catches a missing mirror except a live test.

**Phase 4 (`MatchManager`, `MatchParticipants`, `MatchReplicator`) — DONE, verified on the
Game place via real Play + manual console-driven transitions** (Match layer is
Game-Server-only; Lobby untouched, smoke-tested clean). Added `Match/MatchManager.luau`
(`Get`/`Is`/`GetElapsed`/`RequestEnd`/`Abort`/`StateChanged`, plus `RequestTransition` — see
deviation below), `Match/MatchParticipants.luau` (`Seed`/`All`/`IsParticipant`/
`GetPresent`/`CountActive`/`Joined`, tracks the expected roster independent of
`Players:GetPlayers()`), `Match/MatchReplicator.luau` (mirrors state onto
`ReplicatedStorage.MatchInfo`'s `MatchState` attribute). Wired into `GameBoot`'s ordered
list after the PlayerState services (roster + manager, then replicator last).

Verified by hand: full `Loading→WaitingForPlayers→Countdown→Playing→Ending→Cleanup→Finished`
path succeeds and the `MatchState` attribute mirrors at every hop; `Loading→Playing`
direct jump rejected; `Finished` (terminal) rejects any further transition;
`RequestEnd` only fires from `Playing` and is idempotent (a second call once already
`Ending` is a no-op); `MatchParticipants.Seed` correctly tracks a present + an absent
userId separately (`CountActive` = 1 of 2 seeded).

**Two deviations from the plan, both judgment calls on genuine gaps/inconsistencies —
flagged for review:**
1. The plan states the transition setter is fully private with no public API beyond
   `RequestEnd`/`Abort`, yet Phase 4's own verification method is "drive `Loading → … →
   Finished` by hand" and `MatchClock` (a later phase) is described as driving normal
   progression "via MatchManager" — neither is possible through `RequestEnd`/`Abort` alone
   (one only fires from `Playing`, the other only lands on `Cleanup`). Added
   `MatchManager.RequestTransition(to, reason)` as the one guarded entry point everything
   (including `RequestEnd`/`Abort` internally) goes through — same
   `MatchStates.CanTransition` guard, just reachable by name instead of being an anonymous
   local.
2. The plan's prose says "any [non-terminal] state can reach Cleanup" but its own
   `MatchStates.Transitions` table has no direct `Playing→Cleanup` edge (`Playing` only
   permits `Ending`). `Abort()` now steps `Playing→Ending` first (gameplay must freeze
   there before anything is destroyed) rather than failing; a second `Abort()`/`RequestEnd`
   call from `Ending` completes the trip to `Cleanup`. Confirmed both hops work correctly
   in testing.

**Phase 5 (death flow) — DONE, verified on both places via real Play sessions.** Added
server-side `Death/DeathPolicy.luau` (per-mode data: `RespawnPolicy`, `SpectateDelay`),
`Death/DeathService.luau` (the only `Humanoid.Died` listener added on the Game Server;
falls back to immediate respawn if `MatchStates.IsGameplayActive` is false, otherwise
`Dead` → after `SpectateDelay` → `Spectating`; fires `DeathService.Died` as an open
extension point for kill cams/stats/achievements), `Lobby/LobbyDeathPolicy.luau` (Lobby's
own independent `Humanoid.Died` binding: instant `Dead → new character → Alive`, no
`DeathService` involved at all). Client-side: `Shared/PlayerStateClient.luau` (read-only
local-player state mirror), `UI/DeathScreen.luau` (button-registry shell — empty for now,
matching "shell" framing; nothing has a real backing action yet), `UI/
DeathScreenController.luau` (wires the two together, shows only on `Dead`). All wired into
`GameBoot`/`LobbyBoot`'s ordered lists and `ClientBootstrap`'s `GameServer` branch.

Verified by hand on both places: Lobby death → `Alive→Dead→(new character)→Alive`, instant,
confirmed via a real `Humanoid.Died` trigger. Game Server death outside `Playing` (tested at
`Loading`) → same immediate-respawn fallback, confirmed. Game Server death during `Playing`
→ `Dead` held for the full `SpectateDelay` (character confirmed unchanged throughout, no
respawn) → auto-transitions to `Spectating` with no further action needed. Attribute and
`DeathScreenGui` both confirmed reacting correctly across a full `Dead→Spectating` cycle
(GUI built + shown on `Dead`, hidden again on `Spectating`) — catching `Enabled = true` in
the exact same instant as the `Dead` attribute proved impractical given tool round-trip
latency vs. the 2s `SpectateDelay`; treated as a diminishing-returns chase since both halves
were independently confirmed.

**Gap hit again (same class as Phase 3's Signal miss):** the Game place had **no
`ClientBootstrap` at all** before this phase — Phases 1-4 were server-only, so the client
side of "one codebase, two places" was never exercised there. Added a minimal
`ClientBootstrap` (role-branch + `DeathScreenController` only, matching the Phase 1 minimal
`Bootstrap.legacy` precedent — Flash/Objective client requires aren't mirrored since that
content isn't there either) plus `UI/{UIBuilder,UITheme,DeathScreen,DeathScreenController}`
and `Shared/PlayerStateClient`. **The manual-mirroring gap is now spanning both server and
client trees on the Game place** — this is the third phase in a row that surfaced a missing
mirror only via a live test failure, not a static check. Strongly consider resolving the
content-migration/sync-pipeline question (flagged since Phase 1) before Phase 6 adds more.

**Deviation:** `PlayerStateHandler.legacy.luau` (flagged back in Phase 1 as a naming
collision with the new `PlayerStateService`) is still untouched, per the plan's own
"existing self-wiring scripts are not migrated" rule. It now coexists with `DeathService`
as a second independent `Humanoid.Died` listener on the Game Server — harmless (it only
touches the unrelated `KitGiven` attribute) but the name collision is more confusing than
before. Rename/absorb is a deliberate non-action here, not an oversight.

**Phase 6 (`SpectateService`, `SpectateTargets`, camera controller, HUD) — DONE, verified
on the Game place with the one real player available** (Studio MCP's `start_stop_play` has
no multi-player/Test-Players:2 option — two of the plan's three stated verification
scenarios genuinely need a second real player and are handed off below, not skipped
silently). Added server-side `Spectate/SpectateTargets.luau` (`GetValidTargets`/
`SelectNext`/`SelectPrevious` — swappable policy, present participants who
`CanControlCharacter` + have a living Humanoid) and `Spectate/SpectateService.luau`
(`GetTarget`/`SetTarget`/`Next`/`Previous`/`TargetChanged`, reassigns every spectator
watching a target that dies/disconnects, resets everyone to neutral on `Cleanup`, rate-limited
via the existing `Cooldown` module). Client-side: `Spectate/SpectateCameraController.luau`
(camera transitions, force-exits `CameraSession` if present), `Spectate/SpectateHud.luau`
(name + index/total shell), `Spectate/SpectateController.luau` (wires both to
`SpectateStateSync` + `PlayerStateClient`). New remotes `SpectateRequest`/`SpectateResult`/
`SpectateStateSync`; new `Shared/SpectateResultCodes.luau`. Wired into `GameBoot` and
`ClientBootstrap`'s `GameServer` branch.

**Two real bugs found and fixed via live testing, not just reasoning:**
1. `SpectateService.SetTarget(spectator, nil)` always returned `(true, "Ok")`, even when
   `Next()`/`Previous()` called it because there was nothing left to cycle to — a client
   asking to cycle targets with none available would've been told "Ok" instead of "No One
   Left To Spectate". Fixed: `Next`/`Previous` now detect the no-target case themselves and
   report `NoTargets` directly, while `SetTarget`'s own contract (assigning nil is a valid,
   successful operation) is unchanged.
2. **`Camera.CameraSubject = nil` does not clear it.** Confirmed live: after the "no
   targets" fallback fired, the camera stayed locked onto the local player's own humanoid
   — Roblox's default out-of-the-box subject — completely unaffected by the nil assignment.
   Also had to switch `CameraType` from `Custom` to `Scriptable`: `Custom` is Roblox's
   interactive default and its built-in scripts fight for `CameraSubject` every frame.
   Fixed by giving the free-camera fallback a real (invisible, anchored) `Part` to point
   at instead of relying on `nil` — matching the plan's own suggested alternative, "a fixed
   map vantage point." **Worth remembering for any future camera work in this repo.**

**Handed off, not verified — needs two real connected players:**
- "Kill one, confirm they spectate the other" — never observed a *real* other player's
  humanoid as `CameraSubject`; only the `nil`-target path was exercised live.
- "Disconnect the target mid-spectate" — `reassignSpectatorsWatching` follows the same
  code path as the proven `assignBest`/`NoTargets` case, so it's implemented and read
  through carefully, but not observed firing from a real `PlayerRemoving` event.
- **To test yourself:** open Studio, set Test → Players to 2 (or use two separate
  clients), get both into the Game place mid-`Playing` (console-drive `MatchManager` and
  `MatchParticipants.Seed` with both UserIds, same technique used throughout this phase),
  kill Player A — expect their camera to lock onto Player B's humanoid and the HUD to show
  B's name. Then disconnect Player B (or kill them too) — expect Player A's camera to fall
  back to the fixed anchor point and the HUD to read "Free Camera".

**Gap avoided narrowly, not this time:** the Game place was also still missing
`Shared/Remotes.luau` and `Shared/Cooldown.luau` entirely (Remotes.Init() had never been
wired into this place's minimal bootstrap either, meaning `ReplicatedStorage.Remotes` — the
actual RemoteEvent instances — didn't exist there at all). This is the fourth phase in a
row surfacing a missing mirror only via a live test; the underlying content-migration
question (flagged since Phase 1) is now touching server infra, client UI, and shared
utilities simultaneously. Strongly recommend resolving it before Phase 7.

**Phase 7 (`MatchEndCondition`, `MatchResultBuilder`, `MatchCleanup`) — DONE, verified on the
Game place via a real Play session.** Added `Shared/MatchResultCodes.luau` (code → message,
mirrors `ShotResultCodes`), `Match/MatchEndCondition.luau` (the one module allowed to
correlate `MatchParticipants` + `PlayerStateService`; reads `PlayerStateService.GetAll()`
rather than `Players:GetPlayerByUserId` so a disconnected-but-still-tracked participant is
read correctly; calls `MatchManager.RequestEnd("AllPlayersDown")` once no participant's state
has `CountsAsActive`), `Match/MatchResultBuilder.luau` (`RegisterContributor`/`Build()`
registry, captures `resultCode`/`durationSeconds` on entering `Ending`; **zero contributors
registered this phase** — `perPlayer` slices are intentionally empty tables, future systems
add their own), `Match/MatchCleanup.luau` (`RegisterSaveStep`/`RegisterTeardownStep`
registry, each step run on its own thread with a bounded poll so one hung step can't block
the rest; also owns the `Ending → Cleanup` hold and the final `Cleanup → Finished`
transition). `Match/MatchReplicator.luau` (the only match module that touches remotes)
extended to build and `FireClient` a per-player `MatchResultSync` payload on entering
`Ending`. New remote `MatchResultSync`. `RewardLedger.luau` originally registered a save step
(`RewardStore.SaveAll`, reusing the Ready-gate — decision #3) at its own module scope, guarded
behind `ServerRole.Is("GameServer")`. **Superseded in Phase 7.5 below** — `RewardLedger` has no
`Start()`, so that module-scope registration was a hidden keystone dependency on
`PlayerCurrency.legacy` being required; see the Phase 7.5 entry for the fix.
`RewardService.AwardFromCapture`/`Grant` and
`MonsterService.Spawn`/its `Heartbeat` tick now gate on `MatchStates.IsScoringActive`/
`MonstersSpawn`/`IsGameplayActive`, each guarded so a non-`GameServer` role is a no-op (both
modules currently self-wire on both places per the content-migration gap below — the gate
must not change Lobby behavior). Fixed a real correctness bug in the same edit:
`AwardFromCapture` previously called `Grant` and fired `Awarded` (which drives
`ObjectiveService.Complete`) regardless of `Grant`'s return value — the scoring gate is now
checked at the top of `AwardFromCapture` itself, before the reward pipeline runs, so a
refusal also correctly skips the `Awarded` fire. Wired `MatchEndCondition`/
`MatchResultBuilder`/`MatchCleanup` into `GameBoot`'s ordered list, `MatchResultBuilder`
specifically before `MatchReplicator` (its `Ending` listener captures `resultCode` before
Replicator's `Ending` listener reads it via `Build()` — same-signal listener order matters
here, same class of ordering concern as Phase 1's R1).

Verified end-to-end via `execute_luau` on the Game place (manually driving each service's
`Start()`, since Studio Play always reports a non-reserved server — same as every prior
phase): seeded one participant, drove `Loading→WaitingForPlayers→Countdown→Playing`, set
that sole participant to `Dead` — `MatchEndCondition` correctly fired
`RequestEnd("AllPlayersDown")` with no manual trigger, landing on `Ending`. Confirmed
`MatchResultBuilder.Build()` returned `resultCode = "AllPlayersDown"` and a real
`durationSeconds`; confirmed the `MatchState` attribute and `MatchResultSync` remote fire
produced zero console errors; after the `ENDING_HOLD_SECONDS` window elapsed (real time
between tool calls, not force-advanced), state had progressed unattended all the way to
`Finished` with no errors, and `Finished→Loading` was correctly rejected (terminal). **Not
verified — could not be, on this place:** the `RewardService`/`MonsterService` gates and
`RewardLedger`'s save-step registration, because **none of Reward/Monster/Objective/Camera
exist on this Game place at all** (confirmed via `inspect_instance` — `GameService` here has
only `Boot`/`PlayerState`/`Match`/`Death`/`Lobby`/`Spectate`). These edits were made and
reasoned through carefully on disk but are unverified until that content-migration gap
closes; treat them as reviewed, not proven.

**This is now the fifth phase in a row blocked by, or working around, the same
content-migration gap** (flagged since Phase 1, called out explicitly at the end of Phase 6).
It has now stopped a *feature's own gate* from being testable at all, not just caused an
extra mirroring step. Strongly recommend resolving it before Phase 8 (teleport round trip),
which will need the full existing gameplay codebase present on the Game place to mean
anything.

**Phase 7.5 (Game place content migration) — CODE-SIDE PREP DONE; the actual migration is NOT
done, and could not be attempted this session** (audit: `~/.claude/plans/before-
phase-8-perform-scalable-mochi.md`; inserted into the blueprint as its own phase between 7 and
8). Studio MCP was disconnected for this entire session — no `inspect_instance`/`execute_luau`
calls were possible, so **nothing was mirrored onto the Game place** and the open item from the
audit (locating the Game place's actual bootstrap Script, since it isn't at
`GameService.Bootstrap`) is still unresolved.

What *was* done, on disk only:
- **Fixed the hidden-keystone defect the audit found**, rather than just documenting it.
  `RewardLedger.luau`'s Phase 7 module-scope `MatchCleanup.RegisterSaveStep` call is removed —
  `RewardLedger` no longer requires `ServerRole` or `MatchCleanup` at all. New
  `Reward/RewardCleanupHook.luau` (`Start()` convention, `ServerRole.AssertGameServer()`)
  performs that registration instead, wired into `GameBoot`'s ordered list right after
  `MatchCleanup`. This means the save step's existence no longer depends on
  `PlayerCurrency.legacy` happening to be mirrored/required — it depends only on
  `RewardCleanupHook` being in the boot list, which is now explicit and greppable.
- **`RewardLedger.CurrentPersistentValues`** — the old module-scope `currentPersistentValues`
  local, exported as a real function so `RewardCleanupHook` can reuse its exact nil-safe
  "refuse a partial save" logic rather than duplicating it. This is a one-function export, not
  a redesign — the option-C plan said "`RewardLedger` untouched," and this is the one deviation
  from that, made because duplicating the persistence-safety logic in two files was the worse
  option. Flagged here rather than silently going beyond the plan.
- **`Tools/CheckGameMirror.luau`** — the checked-in manifest + drift check the audit called for.
  Lives at repo root under `Tools/`, a non-service-named folder the disk-sync pipeline ignores,
  so it will never appear as a live instance in either place; it's meant to be pasted into
  Studio's command bar by hand. Checks existence + `ClassName` for all 30 tier-1/2/3 paths from
  the audit's §3 cut line. **Does not check Source-content drift** — that needs a real plugin or
  Rojo, neither of which this repo has; the file's own header says so up front rather than
  overclaiming what a plain command-bar script can do.

**UPDATE, same session:** Studio MCP stayed disconnected for the rest of this session (a
mid-session reconnect on the user's end did not attach to this already-running conversation),
so all of the following was done by generating command-bar scripts for the user to paste
themselves, not by direct tool access. All five items below are now done, live, on the Game
place:

1. **Bootstrap located and fixed.** It is `ServerScriptService.Bootstrap` — **not**
   `GameService.Bootstrap` as the audit assumed; a real, separate top-level Script. It was
   also found mis-named `Bootstrap.legacy` (literal suffix in the Roblox instance Name, unlike
   `CameraShotHandler`/`PlayerCurrency` which correctly dropped it) — renamed to `Bootstrap`.
   Its `Remotes.Init()` call was already present and correct; it was missing the
   `require(ObjectiveService)` / `require(ObjectiveReplicator)` pair the disk file has — added.
   Without that fix, the tier-2 objective files would have existed on this place but never
   loaded, since `ObjectiveService` self-wires (registers into `RewardService`'s seams) at
   require time only.
2. **All ~30 tier-1/2/3 files mirrored**, via a single generated installer,
   `Tools/InstallGameMirror.luau` (checked in, not synced into either place — see its own
   header). Confirmed via `Tools/CheckGameMirror.luau`: `missing 0, wrong class 0`.
3. **Spawn point + two tagged capture targets placed** in Workspace by hand (a `SpawnLocation`,
   `Phase7_5MonsterTarget` with `IsMonster`, `Phase7_5ObjectiveTarget` with `IsObjective`).
4. **Drift check clean** — see #2.
5. **Checklist run, via `Tools/VerifyPhase75.luau`** (items 2, 3, 5, 6, 7, 8 in one Play-mode
   pass) **+ `graphify update`** (item 10, run locally — zero import cycles, confirmed).
   Items 5 and 6 were then **re-run and PASSED** via `Tools/InstallVerifyScript.luau` (real
   Script, real require cache — see the G3 note below): `5-pre` registered, `5a` `Awarded` with
   `Available → Completed` and an XP delta, `5b` `AlreadyCompleted` with XP unchanged, `6-pre`
   reached `Cleanup`, and `6` confirmed by a live `GetAsync` read-back
   (`storedXP == expected`) **while the player was still connected** — the only design that
   can't be masked by `TeardownPlayer`'s own `PlayerRemoving` save.
   Items 4 (real-client capture) and 9 (Lobby regression) not yet run.

**Results — 9/9 attempted core items pass; two real bugs found during verification, neither in
Phase 7.5's own new code:**
- **Item 6 false failure was this session's own test-script bug**, not a product defect:
  `Tools/VerifyPhase75.luau` originally called `RewardLedger.SetupPlayer(player)` defensively
  ("in case `PlayerCurrency.legacy` hasn't run yet"), which is no longer true after the
  Bootstrap fix. Calling it twice for one player races two concurrent `RewardStore.Load()`
  calls, and the second can reset the session to `"Loading"` right as `MatchCleanup`'s save
  step runs — `RewardStore.Save` then correctly *refuses* (its own Ready-gate working as
  designed), which looked like a lost save but wasn't. Fixed by removing the redundant call.
- **Items 5 and 6 both failed for one reason: G3, and the test harness was at fault, not the
  product.** `Tools/VerifyPhase75.luau` runs from the **command bar**, which has plugin identity
  and therefore an **isolated `require()` cache**. Its `require(RewardService)` returns a fresh
  copy whose `contextProviders` list is empty — `ObjectiveService` registered its provider into
  the copy loaded by the real `Bootstrap` Script — so the objective rule
  `objectiveRegistered == true` could never pass (`ObjectiveUnavailable`, with
  `context.objectiveRegistered` observed as `nil` via a diagnostic provider). Identically, the
  isolated `RewardStore` had no loaded session for the player, so `IsReady()` was false forever
  and the `Cleanup` save was correctly refused by its own Ready-gate. Monster captures passed
  throughout only because `CaptureTargets.Monster` has `Rules = {}` and needs no provider.
  **Superseded by `Tools/InstallVerifyScript.luau`**, which installs a temporary real Script
  (`ServerScriptService.Phase75Verify`, delete after use) so items 5/6 run in the real cache.
  *A mid-session misdiagnosis is recorded here deliberately: this was first written up as an
  `ObjectiveRegistry.bootstrap()` scan/replication race, and a "Known broken" row was added for
  it. That was wrong and has been removed — `IsRegistered` returned `true` because the isolated
  cache re-ran `bootstrap()` on first require, which was mistaken for a late registration.*
- **A second, independent test bug on item 5:** `Phase7_5ObjectiveTarget` carries no
  `ObjectiveType` attribute, so it defaults to `Standard` → `Ownership = "Player"`. Player-owned
  objective state lives in a Lua table inside `ObjectiveService`, **not** the `ObjectiveState`
  attribute (only `Shared` ownership writes that attribute). So `state = nil` was correct even
  on success, and the audit's own §5 checklist text — "assert its `ObjectiveState` attribute …
  Instance-backed, G3-safe" — is **wrong for Player-owned objectives**. The replacement Script
  asserts via `ObjectiveService.GetState(player, target)` instead.

- **A third test bug on item 5, worth remembering because it will recur:** `Signal:Fire` is
  DEFERRED. `ObjectiveService.Complete` runs from `RewardService.Awarded`, so reading
  `GetState` synchronously right after `AwardFromCapture` returns still sees `Available`.
  A bare `task.wait()` after each award fixes it. Same gotcha the Phase 3 entry records.
- **`Phase75Verify` must run at most once per server lifetime.** `MatchManager` is a singleton
  and `Finished` is terminal by design, so a second run in the same server produces
  `illegal transition Finished -> WaitingForPlayers` and a cascade of stale-state failures that
  look like product defects. The Script now carries a `_G.__Phase75VerifyRan` guard and a hard
  abort unless `MatchManager.Is("Loading")`.

**Standing tally for this phase: the product code needed exactly one change (`RewardCleanupHook`).
Every other failure was in the test harness or in my own diagnosis.**

**Item 4 (real-client capture, the G5 pass) — PASSED**, run live via Studio MCP
(`Tools/InstallItem4Harness.luau` server half + a client-datamodel `FireServer` call — see that
file's header for why the client half needs no real Script, unlike items 5/6). A real client
fired `WeakCameraShot` at `Phase7_5MonsterTarget`; `ShotFeedback` came back
`hit=true, resultCode=Awarded, amounts={Score=100, XP=600}`; the `leaderstats.XP` IntValue
(Instance-backed, read directly, no isolated-cache risk) went `77793 → 78393`, and
`ReplicatedStorage.MatchInfo:GetAttribute("MatchState")` stayed `"Playing"` throughout — the
scoring gate didn't spuriously trip mid-shot.
- **Tooling note found during this run:** `get_console_output` returned the same stale buffer
  across multiple calls spanning a Play stop/restart and a fresh script install — do not trust
  it as a liveness signal for a running temp Script. Instance-backed reads (attributes,
  `leaderstats` values) executed fresh each call are the reliable way to observe live state from
  the command bar; this is really the same G3 lesson applied one level further; console output
  through this MCP tool is not.
- Confirms `_G` is *also* isolated per G3, not just `require()`: a diagnostic `execute_luau` read
  of `_G.__Phase75Item4Ran` from the command bar came back `nil` while the real temp Script (a
  separate execution context) had already set it and was mid-poll. Same fix as always —
  Instance-backed evidence only, read fresh, from whichever context actually needs verifying.

**Item 9 (Lobby regression) — PASSED**, run live via Studio MCP against `BaseGame`. Used the
Lobby's existing `GoldenJug` objective (`Workspace.GoldenJug.spout_geom`, `IsObjective`, no
`ObjectiveType` attribute so `Standard`/`Player`-owned) rather than placing a new target — it
was already there from earlier phases. Force-equipped a `Camera1` tool the same way as item 4,
then fired `StrongCameraShot` from a real client (`WeakCameraShot` first returned
`WrongShotQuality` — a legitimate per-objective rule, not a gate failure — `StrongCameraShot`
then returned `resultCode=Awarded, amounts={Score=154, XP=308}`).
`leaderstats.XP` went `78393 → 78701` (+308, matching the reported amount) — capture still
awards on the Lobby, confirming `isScoringActive()`'s `not ServerRole.Is("GameServer")` early
return. Same XP value carried in from the Game place's item-4 result (`78393`), confirming
`RewardStore_v1` really is shared across both places via the common `GameId`, as designed.

For "no `MatchCleanup` registration warning": verified by grep, not by a live console check —
[LobbyBoot.luau](ServerScriptService/GameService/Boot/LobbyBoot.luau) never requires
`MatchCleanup` or `RewardCleanupHook`, and `Bootstrap.legacy` only unconditionally requires
`ObjectiveService`/`ObjectiveReplicator`. There is no code path on the Lobby that could ever
call `RegisterSaveStep`, so the warning is structurally impossible there, not merely unobserved.

**All 10 Phase 7.5 checklist items now pass. Nothing remains open in this phase.**

**Phase 8 (Teleport round trip) — CODE DONE, NOT YET VERIFIED.** Per the plan's own section 17
and the Phase 0 entry above, `ReserveServer`/`TeleportAsync` return HTTP 403 in Studio Play —
this phase can only be verified on a **published two-place build**, not in Studio (see G10).

Scope note: the plan's Phase 8 row names only `MatchLauncher`, `ReturnToLobbyService`,
`ArrivalService`, and the `ReserveServer` call. Asked the user first, then added one more
piece with explicit approval: nothing in that list drives `Loading → WaitingForPlayers →
Countdown → Playing` after a real teleport, so without it the round trip would still need a
manual command-bar transition, same as every phase before it. Built `MatchArrival.luau` +
`MatchClock.luau` to close that gap.

New files:
- `Lobby/MatchLauncher.luau` — `Launch(players, modeId?)`: `ReserveServer`, builds
  `{ participantUserIds, modeId }` TeleportData, `TeleportAsync`s the group. No caller yet
  (Phase 9's `QueueService` calls it); exercised directly for now, same as the plan's own
  "manual launch button is enough to exercise phases 1-8" note.
- `Match/MatchArrival.luau` (Game) — consumes `TeleportData` on arrival, seeds
  `MatchParticipants`, transitions `Loading → WaitingForPlayers`. Falls back to seeding the
  arriving player solo when there's no `TeleportData` (direct join / Studio Play-test), so the
  server stays runnable per rule 1. Also exposes `GetModeId()` for `MatchClock`.
- `Match/MatchClock.luau` (Game) — the plan's own named (previously unbuilt) timer module:
  `WaitingForPlayers` roster-complete/timeout → `Countdown`; `Countdown` ticks → `Playing`
  (or back to `WaitingForPlayers` if the server empties mid-countdown); owns the
  `Ending → Cleanup` hold, replacing `MatchCleanup`'s old placeholder constant per that
  module's own comment inviting the swap.
- `Match/ReturnToLobbyService.luau` (Game) — on `Finished`, `TeleportAsync`s everyone to the
  Lobby carrying `MatchResultBuilder.Build()`'s full result as the shared TeleportData;
  retries a player's failed return teleport with capped backoff via
  `TeleportService.TeleportInitFailed`, then kicks; a 30s watchdog force-kicks any stragglers
  so the server always empties (Roblox destroys an empty reserved server automatically — there
  is no direct "shut down now" call).
- `Lobby/ArrivalService.luau` — on a player's `PlayerAdded`, checks `TeleportData.summary`; if
  present, extracts that player's own `perPlayer` slice server-side and fires the existing
  `MatchResultSync` remote with it (display-only, never written to the DataStore). Progression
  itself needs no explicit reload call here — `PlayerCurrency.legacy`'s own `PlayerAdded`
  handler already runs unconditionally regardless of join origin.

Modified: `Match/MatchCleanup.luau` (removed the superseded `ENDING_HOLD_SECONDS` timer/handler
now that `MatchClock` owns that hold) · `Boot/GameBoot.luau` (added `ReturnToLobbyService`,
`MatchClock`, `MatchArrival` — `MatchClock` before `MatchArrival`, publisher-before-subscriber)
· `Boot/LobbyBoot.luau` (added `MatchLauncher`, `ArrivalService`).

Deliberate simplification: `TeleportAsync`'s data table is one shared payload per batch call,
not per-player, so `ReturnToLobbyService` sends the *entire* `perPlayer` table and
`ArrivalService` picks out each player's own slice server-side — avoids one `TeleportAsync`
call per returning player while keeping the same no-cross-player-leak guarantee.

**Verification owed, requires a published build:** launch a match from the Lobby (command bar:
`MatchLauncher.Launch(Players:GetPlayers())`), confirm arrival seeds the roster and reaches
`Playing` on its own, end the match, confirm the server actually empties/shuts down, and
confirm XP earned in the match is present back on the Lobby (`RewardStore_v1` read after
return). None of this has been run yet.

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
- **G10 — User-reported: DataStore access only works from a genuine published Roblox server, not a Studio test client/server.** As stated this overclaims — `GetAsync`/`SetAsync` calls in Studio Play **did** work live this session (Phase 7.5 items 6 and 9, with Studio Access to API Services on; see G7). What's actually confirmed Studio-blocked is `ReserveServer`/`TeleportAsync` (Phase 0 above: HTTP 403 in Studio Play/Test even against a published place) — Phase 8's `MatchLauncher`/`ReturnToLobbyService` cannot be exercised in Studio at all and need a published two-place build. Recording both here since the two are easy to conflate and the next session should know which one actually blocks Studio testing.

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
