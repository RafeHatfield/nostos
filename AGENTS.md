# Nostos — Codex configuration

The conventions and constraints that are load-bearing and not inferable from the
code. Read this before writing anything.

**The quality standard lives in `docs/review-bar.md`.** This file says how the
code is organised; that file says whether a change is good enough to land. They
are different questions and a change can pass this one and fail that one.

> **This project is at scaffold stage.** The engine has not been chosen. Sections
> below marked **TBD** are genuinely undecided, not undocumented — do not infer
> an answer from them and do not write code that silently picks one. If a task
> forces a TBD to be resolved, resolve it in the open: record the decision and
> the alternatives in `docs/decisions/` and update this file in the same change.

## Tech stack

**TBD — engine not chosen.** See `tasks/known-gaps.md` ENGINE-1, which names the
decision, the candidates, and what each would cost. This is the first real
decision the project has to make and most of the rest of this file is downstream
of it.

What is already fixed, regardless of engine:

| Concern | Decision |
|---|---|
| Version control | Git, GitHub, branch → PR → merge. Never a direct commit to `main`. |
| Binary assets | Git LFS, **not yet installed** — `tasks/known-gaps.md` ASSET-1. Must land before the first binary asset is committed. |
| Simulation | Deterministic, fixed-timestep, headless-runnable. Non-negotiable; see the structural rule below. |
| Target frame rate | 60 fps at p99 on min-spec. Min-spec itself is `tasks/known-gaps.md` PERF-1. |
| Art direction | Low-resolution pixel art in the register of **Shattered Pixel Dungeon**, at or above its quality. Sources: Oryx packs, PixelLab generations, hand-authored. The style bible that reconciles them is `tasks/known-gaps.md` STYLE-1. |
| Presentation | Integer scaling, nearest neighbour, camera and sprites quantised to whole pixels. Non-negotiable — it is what makes the art style hold up in motion. |

## Architecture

**TBD in its specifics, fixed in its shape.** Whatever engine is chosen, the
project is built as four layers with a one-way dependency arrow:

```
platform  ─→  presentation  ─→  simulation  ─→  data
(window,      (render, audio,   (game state,     (tuning values,
 input,        UI, feel)         rules, physics)  content, saves)
 files)
```

- **Arrows point one way only.** `simulation` may not reference anything to its
  left. This is what makes headless tests, golden replays, and determinism
  proofs possible; every one of those capabilities dies the first time a
  gameplay system reads a renderer.
- **`data` is inert.** Tuning values, content definitions, and save schemas.
  No behaviour.
- **`platform` is the only place the outside world exists** — the filesystem,
  the clock, the window, devices. Everything else receives what it needs.

## Layout

Provisional; the engine decision will rename the leaves, not the shape.

```
nostos/
  AGENTS.md              this file — conventions and structure
  README.md              what the project is, how to run it
  docs/
    review-bar.md        the quality standard a change is judged against
    style-bible.md       the art specification — TASK-008, not written yet
    ai-development-practices.md   how the agent loop is run here
    decisions/           one file per decision that closed an option
  tasks/
    README.md            task file format and the id rule
    known-gaps.md        work deliberately deferred, each with a trigger
    phase-0-foundations.md
  scripts/
    Codex-hooks/        the guards wired into .Codex/settings.json
  .Codex/
    agents/              planner, builder, tester, reviewer, documenter
    commands/            /review-pr
    skills/              create-issue
```

## The one structural rule

**The simulation does not know that rendering exists.**

Game state advances from a fixed timestep and an input snapshot, and produces a
new state. It does not draw, does not play a sound, does not read a file, does
not ask what time it is, and does not know the window size. Presentation reads
the state and shows it.

Everything expensive that this project needs depends on that one rule:

- Headless tests that run faster than real time
- Golden replays — an input trace producing a byte-identical end state
- Frame-rate independence, provable rather than argued
- A determinism guarantee that survives a physics change

Concretely, in simulation code:

- No `deltaTime` in a gameplay rule. The tick length is fixed and known.
- No wall-clock reads. If a system needs elapsed time, it counts ticks.
- No unseeded randomness. Every consumer takes an explicit seeded stream.
- No I/O. Saving is something done *to* the state from outside it.
- No engine singletons, no service locator reach-through, no static mutable
  state. A system takes what it needs as a parameter.

**A gameplay value computed in a renderer or a UI widget is a bug even when it
is correct** — it is invisible to every test in the project.

## Conventions

Language-level conventions are TBD with the engine. These are not:

- **Read before writing.** Match the neighbouring file. A change that is
  stylistically foreign costs every future reader.
- **Comments explain *why*, never *what*.** A comment that asserts a property
  the code does not enforce ("this is always non-empty") is a defect in itself —
  the next author will trust it.
- **Minimum complexity that fully does the task.** No speculative abstraction.
  The second use case is when the abstraction gets built, not the first.
- **Tuning values live in data, next to a note about intent.** A magic number
  someone spent an afternoon finding will be changed in five minutes by someone
  who does not know that.
- **Every function that needs "now" takes it as a parameter.** Never reach for
  the clock.
- **Errors say what failed and what the caller can do.** Never swallow, never
  log a whole object, never let a path or a token reach a player-visible string.
- **A player-visible number changed by a refactor is a failed refactor.** Prove
  equivalence with a replay or a byte comparison.
- **One logical change per commit**, with a message that says why.

## Design rules

**TBD — there is no design document yet.** When one exists it belongs in
`docs/`, and the rules a change may not break get restated here, the way the
structural rule above is.

Two are already fixed by the review bar and are not open for a change to
relitigate:

1. **Player data is never lost, never silently reset.** Atomic writes, versioned
   format, rolling backup, corruption surfaced rather than swallowed.
2. **Accessibility is a shipping requirement.** Full remapping, subtitles on by
   default, colour never the only channel, no unavoidable flashing above 3 Hz.
3. **The art reads as one hand.** One pixel density, one closed palette, one
   outline convention, whatever the asset's origin. A player must not be able to
   sort the game's assets into piles by where they came from — Oryx, PixelLab,
   or hand-drawn. `docs/review-bar.md` §7 is the full statement.

## Environment

**TBD with the engine.** When the first environment variable or local config
file exists it is documented here, in `README.md`, and in `.env.example`
simultaneously — a variable documented in one of the three is a variable
somebody will miss.

Secrets never enter the repo. Signing keys, platform SDK credentials, and store
tokens are excluded in `.gitignore`; if one is ever committed, treat it as
compromised and rotate rather than reverting.

## Commands

**TBD with the engine.** Whatever is chosen must expose these five, by these
names, so that agents, hooks, and CI do not each learn a different incantation:

| Command | Must do |
|---|---|
| `build` | Produce a runnable build. Non-zero exit on any asset validation failure. |
| `test` | Unit and headless simulation tests, including golden replays. |
| `lint` | Static analysis and formatting check. |
| `typecheck` | Whatever the language's equivalent is; may fold into `lint`. |
| `perf` | Run the perf scenes and assert the budgets in `docs/review-bar.md`. |

Available today:

```bash
./scripts/Codex-hooks/test-hooks.sh   # shellcheck + the guard case tables
```

## Workflow

**Branch → PR → merge. Never a direct commit or push to `main`.** This is
enforced by `scripts/Codex-hooks/guard-git.sh`, not merely requested, because
an agent that has been working for an hour will occasionally decide that just
this once it is fine.

**One working copy per session.** A second session in the same checkout will
commit the first one's half-finished edits. `claim-working-copy.sh` warns at
session start and `guard-git.sh` blocks the mutating commands; use
`EnterWorktree` for an isolated copy.

**The default loop for behaviour-changing work is the `reviewed-change` skill:**
build, then hand it to `hyper-critical-reviewer` with the risks you want attacked
named explicitly, and cycle until it clears `docs/review-bar.md`. The reviewer
reads that file by name — keep it current, because a stale bar is a review that
measures the wrong thing.

Off for docs, comments, formatting, and config values. Say which you judged it to
be, in one clause, so it can be disagreed with cheaply.

**Findings are not done when they are posted.** When a review finding is dealt
with, reply saying which it was — fixed (and how it was verified), not an issue
(and what the finding did not account for), or deferred (and the
`tasks/known-gaps.md` entry it became) — then resolve the thread. A PR carrying
twelve unresolved threads looks like twelve open problems no matter how many were
fixed.

## Agent rules

- **Read `docs/review-bar.md` before starting work, not after being sent back.**
  It is the acceptance criterion.
- **Do not commit, push, post, or delete without being asked.** A reviewer's
  ACCEPT is a quality judgement, not authorisation to act.
- **Raise, do not absorb.** Found a bug next door? Add a `pending` task. Do not
  fix it in this change.
- **Do not resolve a TBD by accident.** Picking an engine, a save format, or a
  min-spec target inside an unrelated change is how a project acquires
  constraints nobody chose. Name the decision and stop.
- **A claim is not a verification.** "All fixed" goes back to the reviewer.
- **Concurrent agents own disjoint files, stated explicitly in each brief.**
  Within one coupled subsystem, take sequential ownership even when the file
  lists look disjoint — the type signatures are not.
