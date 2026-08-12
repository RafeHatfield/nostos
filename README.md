# Nostos

A game. Scaffold stage — the engine has not been chosen and no gameplay code
exists yet.

## What is here

| Path | What it is |
|---|---|
| `CLAUDE.md` | Conventions, the four-layer architecture, and the one structural rule |
| `docs/review-bar.md` | **The quality standard.** What "good enough to land" means |
| `docs/ai-development-practices.md` | How the agent loop and the guards work |
| `tasks/` | Task files, the id rule, and `known-gaps.md` |
| `scripts/claude-hooks/` | Git and task guards wired into `.claude/settings.json` |
| `.claude/` | Agent definitions, the `/review-pr` command, the `create-issue` skill |

## The standard

The bar is AAA execution, not AAA scope. `docs/review-bar.md` is the full
statement; the one sentence it reduces to is:

> **Nothing the player experiences may be explained by how the game was made.**

The player does not know and does not care that the team was small or the engine
unfamiliar. They know the game stuttered. AAA quality is the absence of seams.

**Visually the reference is Shattered Pixel Dungeon**, at or above its quality.
Art comes from three places — Oryx packs, PixelLab generations, and hand-authored
work — and reconciling them is the hard part, so the bar states the test plainly:
a player must not be able to sort the game's assets into piles by where they came
from. `docs/review-bar.md` §7.

## The one structural rule

**The simulation does not know that rendering exists.** Game state advances from
a fixed timestep and an input snapshot. It does not draw, play a sound, read a
file, ask what time it is, or know the window size.

Everything expensive this project needs depends on that: headless tests that run
faster than real time, golden replays, frame-rate independence that is proven
rather than argued, and a determinism guarantee that survives a physics change.

## Working here

```bash
./scripts/claude-hooks/test-hooks.sh   # shellcheck + the guard case tables
```

Branch → PR → merge. Direct commits and pushes to `main` are blocked by a hook,
not merely discouraged. One working copy per session — use `EnterWorktree` for an
isolated copy rather than sharing a checkout.

The `build` / `test` / `lint` / `typecheck` / `perf` commands are specified in
`CLAUDE.md` §Commands and land with the engine decision (`tasks/phase-0-foundations.md`
TASK-001, TASK-006).

## What has to happen next

In order, from `tasks/phase-0-foundations.md`:

1. **Choose the engine** — everything else is downstream. The hard filter is that
   the simulation must run headless, deterministically, faster than real time,
   with no window and no GPU.
   **In parallel: write the style bible** (TASK-008) — the one task not gated on
   the engine. Every asset made before it exists is an asset that gets redrawn.
2. Stand up the four-layer skeleton with the dependency direction enforced by the
   build, not by convention.
3. Fixed-timestep loop, golden replay harness, atomic versioned saves.
4. CI, then define min-spec and put the frame budget under test.

Known deferrals and the trigger for each are in `tasks/known-gaps.md`. Git LFS in
particular is **not yet installed** and must be before the first binary asset is
committed.
