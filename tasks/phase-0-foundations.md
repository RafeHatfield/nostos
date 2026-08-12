# Phase 0 — Foundations

Status: planning

## Context

The repo is scaffolded: agent configuration, git guards, the review bar, and the
task format. Nothing else exists. This phase closes the decisions that everything
else is downstream of, in dependency order, and stops before any gameplay code.

The ordering is not arbitrary: TASK-001 decides the engine, and TASK-002 through
TASK-007 cannot be specified until it is. Do not start them in parallel.

**TASK-008 is the exception and should start now**, in parallel with TASK-001.
The style bible depends on no engine and gates every asset that gets made; art
authored before it exists is art that gets redrawn. It sits at position eight
because the ids are sequential, not because it comes eighth.

## Tasks

- [ ] TASK-001: Choose the engine and record the decision
  - Status: pending
  - Depends on: nothing
  - Detail: evaluate candidates against the hard filter in `known-gaps.md`
    ENGINE-1 — the simulation must run headless, deterministically, with no
    window and no GPU, faster than real time. Also weigh: fixed-timestep
    support, profiler quality, source access when a bug is in the engine,
    licensing, and platform targets. Write the winner *and the rejected
    options with why* to `docs/decisions/001-engine.md`.
  - Verify: a throwaway project in the chosen engine advances a trivial
    simulation 10,000 ticks headless from a recorded input trace and prints an
    identical final state on two runs and on two machines. If that cannot be
    made to work, the engine has failed the filter — say so and pick again.

- [ ] TASK-002: Stand up the four-layer skeleton
  - Status: pending
  - Depends on: TASK-001
  - Detail: create the `platform` / `presentation` / `simulation` / `data`
    boundary from `CLAUDE.md` §Architecture as real modules, with the
    dependency direction enforced by whatever the language offers (module
    visibility, an assembly definition, a lint rule) rather than by convention.
  - Verify: a deliberate reference from `simulation` to `presentation` fails
    the build. Demonstrate it failing, then remove it.

- [ ] TASK-003: Fixed-timestep loop with interpolated rendering
  - Status: pending
  - Depends on: TASK-002
  - Detail: fixed simulation tick, variable render rate, interpolation between
    the two most recent states. Accumulator clamped so a long frame cannot
    trigger an unbounded catch-up spiral.
  - Verify: an automated test drives the same input trace at simulated 30, 60,
    144 and 240 fps and asserts byte-identical end states. Prove it is not
    vacuous by making one gameplay value delta-dependent and watching the test
    fail.

- [ ] TASK-004: Golden replay harness
  - Status: pending
  - Depends on: TASK-003
  - Detail: record an input trace, replay it headless, compare the end state
    against a stored golden. This is the integration test of record for the
    whole project — `docs/review-bar.md` §Test rigour leans on it.
  - Verify: a recorded trace passes; a one-tick change to any input in the
    trace fails it. **The golden must not be regenerable as part of the normal
    workflow** — a golden that gets regenerated on failure turns a wrong value
    into the expected value, which the review bar calls out by name.

- [ ] TASK-005: Save system with atomic writes and a versioned format
  - Status: pending
  - Depends on: TASK-002
  - Detail: temp file → fsync → rename. Version field from the first byte
    written, with the migration path decided now rather than retrofitted.
    Rolling backup of the previous save. Corruption detected and surfaced.
  - Verify: a test kills the process partway through a write (or simulates it
    by truncating the temp file) and asserts the previous save still loads
    intact. A test corrupts a save and asserts the game reports it and offers
    the backup rather than starting a new game.

- [ ] TASK-006: Wire the five commands and stand up CI
  - Status: pending
  - Depends on: TASK-001
  - Detail: `build`, `test`, `lint`, `typecheck`, `perf` as named in
    `CLAUDE.md` §Commands. CI runs all five plus
    `scripts/claude-hooks/test-hooks.sh`, and gates merges. Closes
    `known-gaps.md` CI-1.
  - Verify: a PR with a failing test cannot merge. A PR that adds a duplicate
    TASK id fails the hooks job. Demonstrate both.

- [ ] TASK-007: Define min-spec and put the frame budget under test
  - Status: pending
  - Depends on: TASK-006
  - Detail: name the min-spec machine, then build the perf scene and assert the
    percentiles from `docs/review-bar.md` §1 — p50 and p99 ≤ 16.67 ms, p99.9 ≤
    33.3 ms, no frame above 50 ms. Closes `known-gaps.md` PERF-1.
  - Verify: the `perf` command fails when a deliberate 60 ms stall is inserted
    into the frame loop, and passes when it is removed.

- [ ] TASK-008: Write the style bible
  - Status: pending
  - Depends on: nothing — this is the one phase-0 task not gated on the engine,
    and it should start immediately. Art authored before it exists is art that
    gets redrawn.
  - Detail: `docs/style-bible.md`. Fixes the canonical tile grid, the closed
    palette (as an actual swatch file the validator can read, not a description),
    the outline convention, the light direction, the value structure, and the
    animation frame budget. Shattered Pixel Dungeon is the reference standard —
    state explicitly where nostos matches it and where it deliberately differs,
    because "similar to SPD" is not a specification anyone can be held to.
    Closes `known-gaps.md` STYLE-1.
  - Verify: take one Oryx sprite, one PixelLab generation, and one hand-authored
    sprite; normalise all three to the bible; show them to someone who has not
    seen them and ask which came from where. **If they can sort them, the bible
    is not specific enough yet.** That is the test in `docs/review-bar.md` §7 and
    it is the only one that matters.

- [ ] TASK-009: Asset import validators, wired to fail the build
  - Status: pending
  - Depends on: TASK-006, TASK-008
  - Detail: the mechanical half of `docs/review-bar.md` §10 — dimensions an exact
    multiple of the grid, every colour in the palette, no anti-aliased or
    semi-transparent edge pixels, outline convention held, no orphan pixels, and
    provenance plus licence metadata present or the asset does not import. Also
    the register that closes `known-gaps.md` ART-1.
  - Verify: an asset one pixel off-grid fails the build. An asset with one
    off-palette pixel fails the build. An asset with no provenance record fails
    the build. Demonstrate all three failing, then passing once fixed. A warning
    is not a check — if any of these can be ignored, the validator does not exist.

- [ ] TASK-010: Pixel-perfect presentation
  - Status: pending
  - Depends on: TASK-003, TASK-008
  - Detail: integer scaling with nearest-neighbour filtering, camera position
    quantised to whole pixels, no sub-pixel sprite placement, no pixel-art
    rotation off multiples of 90°. **This is where TASK-003's interpolation has
    to be constrained**: interpolate the simulation, then quantise the presented
    position to the pixel grid. Interpolating straight to the screen makes the
    whole scene shimmer in motion.
  - Verify: a capture of a slow diagonal camera pan shows every sprite pixel
    holding its size and position between frames — no shimmer, no uneven pixel
    edges. This one needs video; a screenshot cannot show it, and that is exactly
    why it ships broken elsewhere.
