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

Before reporting a task complete: run the project's tests or typecheck if one
exists, or state in one line why you didn't (no test setup, non-code change).
"It should work" is not done. This is not optional under budget pressure —
an unverified patch costs a whole second session.

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

Read only what the graph surfaces. One re-query max on a miss, then fall back to
grep, say "graph missed" in one line, and continue.

Run `graphify update` once per completed unit of work — after a multi-file change,
before a query that depends on this session's edits, before an architecture review.
Skip for comments, strings, formatting, test bodies.

# Reporting

For code-changing tasks, end with this and nothing else:
1. Files changed (paths only)
2. Verification: what you ran, result
3. Deviations from plan/approach, and why
4. `## Found, not fixed` if applicable

No summaries of code you just wrote. No "next steps" unless asked.

# Roblox

- ModuleScripts over duplicated logic.
- Server and client responsibilities stay separate.
- Preserve existing service boundaries; no circular dependencies.
- Follow Roblox conventions for RemoteEvents, networking, replication.