# Evolution — deferred plan

**Status: PARKED.** Evolution is deliberately out of scope until further notice. This file
holds what was blueprint §10 (Phase E, step 10) plus the parts of §18 that only exist to serve
it, so the blueprint's phase list can drop to what is actually being built.

**This file is not a record of what shipped.** Some of step 10 was implemented before the
decision to park it (see "What already exists on disk" below). That code stays where it is —
it is inert without an `Evolution` block in a monster config, and removing it is a separate
decision this file does not make.

Blueprint cross-references (`§10`, `§18` evolution bullets) point here.

---

## 1. Intent

Evolution is a **discrete event at a match hour** via the `MatchTimeEvents` dispatcher, distinct
from the coarser midnight phase ramp via `MatchPhases.MonsterStage`, which continues to work
unchanged.

```
MatchTimeService.sample()
  └─ MatchTimeEvents.Dispatch(hour)          -- monotonic cursor, task.spawn + pcall
       └─ MatchTimeEvents.Register("MonsterEvolution:<hour>", hour, fn)
            └─ MonsterRegistry.ForEach(inst -> inst:Evolve("<tier>"))
                 └─ Evolution:Apply(tierName)
```

`Evolve` is a no-op on any monster lacking `CanEvolve`. Nothing branches on monster type.

---

## 2. Evolution is a mutation set, not a stat table

The key generalisation over `Restage`:

```lua
Evolution = {
  Tiers = {
    Witching = {                       -- fires at hour 27
      Stats        = { WalkSpeed = 1.3, DetectRadius = 1.25 },  -- MULTIPLIERS
      Capabilities = { Grant = {"CanTeleport"}, Revoke = {} },
      States       = { Enable = {"Teleport"} },
      Aggression   = { Decay = 0.95, Thresholds = { Chase = 0.35 } },
      Perception   = { Sensors = { Vision = { FOV = 200 } } },
      Abilities    = { Unlock = {"SummonMinion"} },
      Presentation = { AnimationSet = "Evolved", VFX = "EvolveBurst", SFX = "Roar" },
    },
  },
}
```

**Why multipliers rather than an absolute stage table:** it composes. A monster whose stats
were already raised by the midnight phase ramp evolves correctly at 3 AM without the two systems
fighting. Absolute values would make ordering matter.

---

## 3. Three guards that multiplication requires

**1. Clamps.** A single ×1.3 on a stage-2 monster can put `WalkSpeed` above the player's
`SprintSpeed`, silently converting "escape is a stamina budget" into "escape is impossible".
Every stat declares limits alongside its base; clamping is the last pipeline step.

> **Superseded in practice.** `Limits.WalkSpeed.Max` was explicitly removed from
> `Configs/Monster1.luau` by decision, precisely so the ×1.3 tier would produce a
> faster-than-sprint monster after hour 27. The clamp *mechanism* remains correct and stays;
> the specific ceiling this paragraph argued for was overridden on purpose. If evolution is
> ever unparked, re-derive `LeashDistance` against the evolved speed — see that config's
> comment, which has been wrong three times.

**2. A declared operation order.** Multiplication is commutative, so order does not matter
*today* — but that dies the moment any system wants a flat or absolute change, and one will
(a scripted "slowed to 8 for 10s", a debuff pickup):

```
stage-merged base  →  Set  →  Add  →  Multiply  →  Clamp
```

**3. Idempotent tier application.** The instance keeps an `AppliedTiers` set; re-applying a
present tier is a no-op. Not theoretical: a monster spawning *after* the hour must have the tier
applied at spawn, while `MatchTimeEvents` also fires. Without idempotency, two correct paths
double-apply and produce a ×1.69 monster. Tiers are `Stacks = false` by default.

---

## 4. Invariants carried forward from `MonsterService.Restage`

- Apply as a **wholesale table swap**, never field-by-field. Components read `stats.*` fresh
  each tick, so a reference swap is atomic mid-tick and cannot leave a half-applied stat set.
- **Do not reset state, target, or position.** A monster that evolves mid-chase keeps chasing.
- Escalation is **monotonic**. Evolution never reduces a stat.
- The spawn point's authored stage is a **floor**, never an override (`math.max`).

`Evolution:Apply` fires `Evolved` on the instance Bus. `Presentation` subscribes and writes the
`EvolutionTier` model attribute, which the client reads to swap animation/VFX sets.

---

## 5. Spawn-time catch-up (was blueprint §18)

A monster spawned after an evolution hour has already passed will never hear the
`MatchTimeEvents` dispatch for that hour. It must therefore apply every tier whose hour is
`<= MatchTimeService.GetHour()` at spawn, **in ascending hour order** — applying out of order
would multiply a later tier onto a base an earlier one was supposed to have raised.

Idempotency (§3.3) is what makes this safe against the scheduled dispatch also reaching the
same monster later, so there is no ordering requirement between catch-up and registry insertion.

---

## 6. What already exists on disk

Implemented before parking, and currently inert because it is driven entirely by config:

| File | State |
| --- | --- |
| `Monster/Components/Evolution.luau` | Built. `Apply` / `Reapply` / `Destroy`. **Stats multipliers only.** |
| `Monster/MonsterEvolution.luau` | Built. `MatchTimeEvents` registration + `ApplyCurrentTiers` spawn catch-up. |
| `Monster/MonsterInstance.luau` | `:Evolve(tierName)`; `SetStage` calls `Evolution:Reapply()`. |
| `Monster/MonsterService.luau` | Calls `MonsterEvolution.ApplyCurrentTiers` at spawn. |
| `Monster/MonsterFramework.luau` | Calls `MonsterEvolution.Start()`. |
| `MonsterConfig.luau` | `Validate` asserts tier shape; `ClampStats` is public for reuse. |
| `Components/init.luau` | `Evolution` moved from `planned` to `modules`. |

**Never built** — the non-`Stats` half of the tier schema in §2. Each is blocked on machinery
that does not exist:

- `Capabilities.Grant` / `States.Enable` — `Brain.candidates` is built **once** in `Brain.new`
  and never rebuilt, so a state enabled at runtime is never scored. Dynamic capability grants
  also imply constructing a component mid-life, which nothing supports.
- `Abilities.Unlock` — there is no `Abilities` component.
- `Presentation` — no animation/SFX assets confirmed to exist.
- `Aggression` / `Perception` tier overrides — mechanically straightforward, but untested and
  unused, so not written.

**To fully park it:** remove the `Evolution` block from `Configs/Monster1.luau`. Everything
above then does nothing. **Do not do this without asking** — it changes live monster tuning.

---

## 7. If unparked, verify

1. Set a tier's `AtHour` to an hour reachable early in a test match.
2. Watch the monster's `EvolutionTier` model attribute flip at that hour.
3. Spawn a monster *after* that hour — it must already carry the attribute (catch-up).
4. Force a stage change after evolving — multipliers must survive (`Reapply`).
5. Confirm the tier applies exactly once across both paths (no ×1.69).
