---
name: create-issue
description: Use when creating, filing, or opening a GitHub issue for Nostos — covers the label taxonomy, when type:bug applies, and body discipline. Also use when correcting an existing issue's labels.
---

# Issue creation

Work tracking lives in GitHub Issues on `neighbourhood-holdings/nostos`.

> **The remote does not exist yet.** The slug above follows the convention of the
> sibling repos (`neighbourhood-holdings/starfish`,
> `neighbourhood-holdings/insanity-peppers`) and is an assumption until someone
> creates it. Confirm with `git remote -v` before relying on it, and correct this
> file rather than working around it if it is wrong. The label taxonomy below
> also has to be created once — `gh label create` — or every command here fails
> on an unknown label.

```bash
gh issue create --repo neighbourhood-holdings/nostos \
  --title "…" --body "…" --label "area:<name>"
# add --label "type:bug" when behaviour is wrong relative to intent
```

## Before creating: check it is not already known

Two places, in this order:

1. **`tasks/known-gaps.md`** — deliberately deferred work. If it is there, it is
   already a decision, not a discovery. Do not open a duplicate issue; if the
   trigger condition in that entry has now been met, say so in the entry.
2. `gh issue list --search "<keywords>"`.

## Area — exactly one `area:*` label

| Label | Covers |
|---|---|
| `area:simulation` | Game state, rules, physics, determinism, the fixed timestep |
| `area:presentation` | Rendering, camera, animation, audio, UI, feel |
| `area:input` | Devices, sampling, latency, remapping, connect/disconnect |
| `area:platform` | Window, filesystem, saves, suspend/resume, platform services |
| `area:art` | Sprites, tiles, palette, the style bible, asset provenance and licensing |
| `area:content` | Levels, encounters, the import pipeline and its budgets |
| `area:perf` | Frame budget, memory, load times, soak, profiling |
| `area:a11y` | Accessibility and localisation |
| `area:tooling` | Build, CI, hooks, the agent setup, editor tooling |
| `area:docs` | README, `docs/`, `AGENTS.md`, `docs/review-bar.md` |

Cross-cutting work takes the area where the *change* lands, not every area it
touches, and names the coordination in the body. Never a second area label, and
never a duplicate issue under the other area.

## Type — one optional label

`type:bug` when current behaviour is **wrong relative to intent**: a regression,
a contract the code does not honour, a hitch above the budget in
`docs/review-bar.md`, a lost input, a save that does not round-trip, or output
that is incorrect rather than merely unfinished. Everything else carries no type
label — "work to be done" is the default and does not need marking.

`type:idea` marks a backlog item nobody has committed to.

`type:decision` marks something that closes an option — an engine, a save format,
a min-spec. These get a `docs/decisions/` file when they land, not just a closed
issue.

## Meta labels

`blocked`, `needs-decision`, `good-first-issue`.

## Body discipline

Current factual state only. No historical narrative — that is what git log is
for.

Two to five lines covering:

- what is true now
- what "done" looks like
- a link to the relevant code, doc section, or `tasks/` entry

For `type:bug`, replace the first line with a reproduction: the input, the
observed output, and the expected output. For this project that usually means
one of:

- **A gameplay bug**: the input trace or the exact sequence, the tick it goes
  wrong on, the state observed, and the state expected. A replay fixture is
  better than a description.
- **A performance bug**: the scene, **the hardware**, the frame-time percentile
  observed, and the budget from `docs/review-bar.md` it misses. A frame-time
  figure with no hardware named is not a report.
- **A save or data bug**: the save file's version, what was lost, and whether the
  backup survived.
- **An art bug**: the asset, its source (Oryx pack / PixelLab / hand-authored),
  and which `docs/style-bible.md` rule it breaks — off-grid dimensions,
  off-palette colour, wrong outline weight. Attach the asset beside the ones it
  appears next to; a sprite judged in isolation is judged against nothing. For
  anything about motion — shimmer, judder — attach video, not a screenshot.

A bug report without a repro is a suspicion.

Do not restate definitions that live in `AGENTS.md`, `docs/review-bar.md`, or
`tasks/README.md`. Link them. Duplicated definitions drift, and then nobody knows
which is current.
