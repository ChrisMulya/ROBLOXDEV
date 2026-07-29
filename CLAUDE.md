# MCP vs Disk

Scripts live on disk and sync to Studio. Read and edit them as files.

Never use `script_read` or `script_grep` — the scripts are already on disk;
those calls duplicate file content through MCP for no reason and are the
main token cost in this workflow.

Studio MCP is for state files can't tell you: instance hierarchy, properties,
Output/runtime errors, play-test control. Use it only for that.

# Scope Contract

Scope governs what you *change*, not what you *read*. Reading a file to
understand a contract you must satisfy is always in scope.

- Do not edit, refactor, rename, or "fix while I'm here" outside the task.
- Bug found outside the task → one line under `## Found, not fixed`. Do not touch it.
- No refactors, renames, or restyles that weren't requested.

If a plan was handed to you, the plan is the spec — implement exactly it, and
STOP and ask if it's wrong or under-specified rather than improvising a design.
If no plan was handed to you, the request itself is the scope: state your approach
in one or two lines, then implement. Don't demand a plan that doesn't exist.

# Done means verified

There is no test runner or typecheck in this project. "Done" means:
state what changed, and state what to test in Studio (one line: what to do,
what you expect to see). Do not claim something works without having run it
yourself — you can't. Hand off the verification step explicitly instead of
skipping it silently.

No summaries of code you just wrote. No "next steps" unless asked.
Questions, read-only answers, and reviews are exempt — answer those normally.

# Budgets (checkpoints, not walls)

Cross a budget only by announcing it in one line first, then continue.

- Orientation before first edit: ~5 file reads. Need more →
  "Budget: reading N more for <reason>" and proceed.
- Debugging one failure: 3 fix attempts. A 4th requires a new hypothesis
  stated in one line — not a variation of the last three. No new hypothesis → stop and ask.
- Re-reading a file you edited: allowed when you need current state you
  don't hold (post-patch verification, a tool reported a conflict).
  Not allowed as a general re-orientation habit.
- Never read a file to confirm something a prior read or the graph already answered.

The announcement is the mechanism. An unannounced overrun is the bug;
an announced one is usually fine.

# Graphify

Knowledge graph in `graphify-out/`.

Use it for cross-file questions only: where is X defined, what calls X, what does
subsystem Y consist of, how does a change propagate.

- `graphify query "<term>"` — locate symbols/files by concept
- `graphify path <A> <B>` — dependency/call path
- `graphify explain <symbol>` — symbol + neighbors
- `graphify-out/GRAPH_REPORT.md` — architecture/module overview only

Do not use it for: a known file path, single-file edits, or anything one grep answers.

Never read:
- `graphify-out/cache/`
- `graphify-out/*/graph.json`

Use Graphify commands or `GRAPH_REPORT.md` instead.

Read only what the graph surfaces. One re-query max on a miss, then fall back to
grep, say "graph missed" in one line, and continue.

Run `graphify update` once per completed unit of work — after a multi-file change,
before a query that depends on this session's edits, before an architecture review.
Skip for comments, strings, formatting, test bodies.

# Work Modes

Determine the mode before acting. If a request matches more than one mode,
the least destructive mode wins — Planning/Audit over Implementation — and
state which mode you're in before proceeding.

## Planning
Triggered by: plan, blueprint, architecture, design, proposal, roadmap,
implementation plan, scope.

READ ONLY.
- Never modify files, generate code, apply edits, or enter Auto implementation.
- Read only the minimum files required.
- Prefer Graphify for architecture questions.
- End after delivering the plan. Stop. Wait for further instructions.

## Implementation
Triggered only when explicitly asked to: implement, code, build, create,
modify, edit, refactor, write, update — and a plan or clear scope already exists.

Follows the approved plan exactly.

## Bug Fix
Only fix the reported bug. Do not redesign.

## Audit
Triggered by: audit, review.

READ ONLY. Review architecture, suggest improvements. Never modify code.

# Reporting

For code-changing tasks, end with this and nothing else:
1. Files changed (paths only)
2. Verification: what to test in Studio, expected result
3. Deviations from plan/approach, and why
4. `## Found, not fixed` if applicable

# Roblox — Project Facts

- Folder encodes class: `ServerScriptService/` → Script, `StarterPlayerScripts/`
  → LocalScript, `ReplicatedStorage/Modules/` → ModuleScript. No `.server.luau`/
  `.client.luau` suffixes are used.
- `.legacy.luau` files are live, currently-running scripts, not dead code —
  do not skip or deprioritize them for that reason.
- Target-type attributes (`IsMonster`, `IsObjective`) are owned by
  `Reward/CaptureTargets.luau` — don't hardcode attribute checks elsewhere.
- `CameraSessionTracker`'s client-reported InCamera flag is a UX guard only,
  never a security boundary. Server-authoritative checks must not rely on it.
- `CurrentCamera` is a per-player `Player` attribute, server-set by
  `CameraInventory` — never write it from the client.
- ModuleScripts over duplicated logic. Server/client responsibilities stay
  separate. Preserve existing service boundaries; no circular dependencies.

# Plan files and state

## Plan files (`plans/<feature>.md`)
When a plan is large enough that it won't survive in context, write it to
`plans/<feature>.md` before ending the planning session.

A plan file references, it does not restate:
- Name the files and symbols to change, not their current contents.
- Copied code goes stale the moment the file is edited. Never paste it.
- State the contract to satisfy and the constraints, not the diff.

During implementation the plan file is the spec. Read it once at the start.
If it conflicts with the code on disk, the code wins — stop and say so
rather than implementing against a stale plan.

Plan files are archived, not maintained. Once implemented, do not update them.

## MAINHANDOFF.md — current phase only
Current state, not history. Overwrite; never append.

Contains: what phase the project is in, what exists and works, what is
half-built, what is known-broken and deliberately deferred.

Does NOT contain: how a system was built, what it used to be, per-module
prose the code already states, or a changelog. Git has the history.

