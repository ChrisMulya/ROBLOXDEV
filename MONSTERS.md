# Monster System Blueprint

Design/architecture plan for the monster AI system. No implementation yet — this is the contract every monster (grey cube MVP through full variety + evolution) is built against.

## The core idea

Four things vary per monster. Keep them in four *different* places, or the state machine gets forked every time a creature is added:

| What varies | Lives in | Adding a monster costs |
|---|---|---|
| **Numbers** (speed, radii, cooldowns) | `MonsterStats` data table | one table entry |
| **Which states it can use** | `MonsterStats` per-stage `States` list | one array |
| **Unique quirks** | `Behaviors/<Name>.luau` hook module | one small file, all hooks optional |
| **Stage progression** | `MonsterStats[id][stage]` sparse overrides | a few lines |

The state machine itself never changes. This mirrors the existing `CameraStats` pattern — same mental model, no new concepts.

## File layout

```
ReplicatedStorage/Modules/Monster/
  MonsterStats.luau          -- data owner, keyed by MonsterId then Stage

ServerScriptService/GameService/Monster/
  MonsterService.luau        -- registry + ONE Heartbeat tick for all monsters
  MonsterAgent.luau          -- per-instance blackboard + state machine runner
  MonsterSensing.luau        -- nearest player, LOS, noise  (MVP: distance only)
  MonsterMovement.luau       -- MoveTo wrapper  (MVP: Humanoid; later: Pathfinding)
  MonsterDamage.luau         -- contact kill + per-player cooldown
  MonsterAggression.luau     -- night-clock scalar -> modifies radii/speed/pursuit
  MonsterEvolution.luau      -- stage bumps
  States/
    Chase.luau               -- MVP builds ONLY this one
    Wandering.luau
    Checking.luau
    Lurk.luau
  Behaviors/
    GreyCube.luau            -- MVP: every hook empty
```

---

## Contract 1 — Stats (mirrors CameraStats)

```lua
MonsterStats.Stats = {
    GreyCube = {
        [1] = {                              -- stage 1 = full base table
            WalkSpeed        = 12,
            DetectRadius     = 60,
            LoseInterestDist = 90,
            PursuitDuration  = 20,           -- secs hunting after losing you
            AttackReach      = 4,
            AttackCooldown   = 1,
            States = { "Chase" },            -- MVP: chase is the whole brain

            -- Solved-AI insurance. See flag at bottom.
            TransitionChance = { Chase = 1.0 },
        },
        [2] = {                              -- SPARSE — merged over stage 1
            WalkSpeed       = 18,
            PursuitDuration = 35,
        },
    },
}

-- Returns base merged with every override up to `stage`.
function MonsterStats.Get(monsterId, stage)      -- TODO
function MonsterStats.GetStageForTime(id, nightTime) -- TODO
```

Sparse stage overrides are what make evolution nearly free: stage 3 crazier = five lines, not a second stat block.

## Contract 2 — The Agent (the blackboard)

Per-monster mutable memory. States read/write this and nothing else.

```lua
agent = {
    model, humanoid, rootPart,
    monsterId  = "GreyCube",
    stage      = 1,
    stats      = <cached MonsterStats.Get result>,
    behavior   = <Behaviors.GreyCube>,

    state        = "Chase",
    stateElapsed = 0,

    target       = nil,   -- Player?
    lastKnownPos = nil,   -- Vector3? -- what Checking walks toward
    lastSeenAt   = 0,     -- os.clock() -- drives pursuit timeout

    aggression = 0,       -- 0..1, DERIVED each tick, not stored long-term
    memory     = {},      -- behavior-specific scratch space
}
```

## Contract 3 — State module (every state is identical in shape)

```lua
local Chase = {}
Chase.Name     = "Chase"
Chase.TickRate = 0.05        -- cheap states tick slow: Wandering = 0.25

function Chase.Enter(agent)  end
function Chase.Exit(agent)   end

-- Return a state name to transition, or nil to stay.
function Chase.Update(agent, dt)
    -- TODO: MonsterMovement.MoveTo(agent, agent.target position)
    -- TODO: if within AttackReach -> MonsterDamage.TryKill
    -- TODO: if lost target and elapsed > PursuitDuration -> return "Checking"
    return nil
end

return Chase
```

Adding **Lurk** later = one new file + adding `"Lurk"` to a stats array. Zero edits to existing states.

## Contract 4 — Behavior hooks (this is how monsters get personality)

Every hook optional. The runner skips `nil`. `GreyCube.luau` defines none of them.

```lua
Behavior.OnSpawn(agent)
Behavior.OnUpdate(agent, dt)                        -- runs every tick, any state
Behavior.OnStateEnter(agent, stateName)
Behavior.TransitionOverride(agent, from, to) -> to? -- hijack transitions
Behavior.OnPhotographed(agent, player, shotType)    -- ties into existing camera system
Behavior.OnEvolve(agent, newStage)
Behavior.OnKill(agent, player)
```

**What this buys later, with no state-machine edits:**
- *Stalker* — `TransitionOverride` refuses `Chase` while any player is looking at it
- *Screamer* — `OnStateEnter("Chase")` alerts every other agent within 100 studs
- *Mimic* — `OnUpdate` freezes movement when observed

---

## The tick loop (one Heartbeat for all monsters, not one per monster)

```lua
-- MonsterService
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for _, agent in pairs(liveAgents) do
        local state = States[agent.state]
        if now - agent.lastTick >= state.TickRate then
            MonsterAgent.Tick(agent, now - agent.lastTick)
            agent.lastTick = now
        end
    end
end)

-- MonsterAgent
function MonsterAgent.Tick(agent, dt)
    agent.stateElapsed += dt
    agent.aggression = MonsterAggression.Resolve(agent)
    MonsterEvolution.Update(agent)
    if agent.behavior.OnUpdate then agent.behavior.OnUpdate(agent, dt) end

    local nextState = States[agent.state].Update(agent, dt)
    if nextState then MonsterAgent.SetState(agent, nextState) end
end

function MonsterAgent.SetState(agent, newState)
    -- 1. behavior may redirect
    -- 2. roll stats.TransitionChance[newState] -- may refuse  <- the anti-solve valve
    -- 3. Exit old -> set state -> reset stateElapsed -> Enter new
    -- 4. behavior.OnStateEnter
end
```

## Aggression & Evolution (derive, don't store)

```lua
-- Global night curve: 0.2 @ 8PM -> 0.4 @ midnight -> 0.7 @ 3AM -> 1.0 @ 5AM
function MonsterAggression.GetGlobal() -> 0..1

function MonsterAggression.Resolve(agent)
    -- global * behavior modifier + transient "recently provoked" bump
end

-- Applied multiplicatively, never as raw stat writes:
effectiveDetect  = stats.DetectRadius    * (1 + aggression * stats.AggressionDetectScale)
effectivePursuit = stats.PursuitDuration * (1 + aggression)
```

Aggression raises **detection radius, pursuit duration, and speed** — not damage. A monster that hits harder isn't scarier when contact is already lethal; a monster that gives up later is.

---

## The MVP: exactly what the grey cube needs

Six files, all small.

| File | MVP content |
|---|---|
| `MonsterStats` | one `GreyCube` entry, stage 1 only, `States = {"Chase"}` |
| `MonsterService` | spawn/despawn registry, Heartbeat loop, `liveAgents` table |
| `MonsterAgent` | blackboard + `Tick` + `SetState` (full version — ~40 lines) |
| `MonsterSensing` | **`GetNearestPlayer(pos, maxDist)` only.** LOS/noise stubbed `return true` |
| `MonsterMovement` | `MoveTo(agent, pos)` -> `humanoid:MoveTo(pos)`. Nothing else |
| `MonsterDamage` | `TryKill` + `lastHitTime[UserId]` cooldown, cleared on `PlayerRemoving` |
| `States/Chase` | move at nearest player; if dist < AttackReach -> TryKill |
| `Behaviors/GreyCube` | `return {}` — literally empty |

**Model attributes** (matching existing convention):
```
IsMonster  = true
MonsterId  = "GreyCube"
Stage      = 1
CanCapture = true      <- ties straight into existing CameraShotHandler
```

That last one matters more than it looks. `CameraShotHandler.legacy.luau` already walks up parents hunting for `CanCapture` — so the moment the cube has that attribute, **it is photographable with zero camera-code changes.** The first monster is a valid photo subject on day one.

## Build order

1. `MonsterStats` + `MonsterService` + `MonsterAgent` + `States/Chase` -> cube walks at you
2. `MonsterDamage` -> cube kills on touch
3. Add `CanCapture` -> cube is photographable (free, already wired)
4. **Then** `MonsterSensing` LOS raycast -> cube loses you behind walls
5. `States/Checking` + `Wandering` -> cube stops being omniscient
6. `MonsterAggression` -> night clock starts mattering
7. `States/Lurk` + real `Behaviors/*` -> monsters become characters
8. `MonsterEvolution` -> stages

Steps 1–3 are one sitting — that's the vertical slice for this system.

---

## Risks to plan around

**"A lot of monster variety" + "evolution stages" is the combination that kills solo projects.** Evolution roughly doubles per-monster cost: two behavior sets, two model states, two tuning passes. It halves the roster that's affordable. Monster count is already the real ceiling in this genre — each creature is model, rig, animation set, AI hooks, audio, journal entry, tuning.

The `Behaviors/` hook layer is the leverage against this: one model can host multiple behavior variants — same mesh, different `Behaviors/` module, and players can't predict which one they're dealing with tonight. A monster with four hunting patterns outlasts four monsters with one each, at a fraction of the content cost.

Recommendation: build **3 monsters × 3 behavior variants**, not 9 monsters. Same felt variety, roughly a third of the content budget. `MonsterService.Spawn` should pick the behavior variant at spawn time, not at model-authoring time.

**The state machine gets solved in a weekend unless randomness is architectural.** This is why `TransitionChance` is in the stats table from step 1, not added later. Retrofitting probability into states written assuming determinism means rewriting every state. A monster that behaves as expected 100% of the time is a puzzle; 85% is a predator. One field in `SetState`, added now, buys that permanently.
