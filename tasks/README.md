# tasks/

How agents coordinate, and where deferred work is recorded so it stays visible
instead of living in someone's head.

One file per feature or theme. `known-gaps.md` holds standing items that were
deliberately not done.

## Format

```markdown
# <Feature name>

Status: planning | in-progress | needs-review | changes-requested | approved

## Context
Two or three lines: what this is for, and any decision already made.

## Tasks

- [ ] TASK-001: <one completable change>
  - Status: pending
  - Verify: <the command or observation that proves it works>

- [x] TASK-002: <another>
  - Status: complete
  - Files: <paths touched, including tests>
  - Notes: <decisions made, anything a reviewer should know>
```

## Rules

- **A task states how it will be verified.** If you cannot write that line, the
  task is not understood well enough to hand over.
- **A performance task states its budget in milliseconds**, and a gameplay task
  states the replay or scenario that proves it. "Feels better" is not a
  verification; `docs/review-bar.md` §11 says what to do instead.
- **An art task states the source, and the normalisation it needs.** Oryx,
  PixelLab or hand-authored — each arrives off-grid or off-palette in its own
  way, and `docs/review-bar.md` §7 is what it has to be brought to.
- **IDs are never reused**, even after a task is deleted. Notes elsewhere refer
  to them. `scripts/claude-hooks/check-task-ids.sh` fails the build if one is
  claimed twice — pick the next free id with:
  ```bash
  grep -ohE '^[[:space:]]*- \[[ xX]\] TASK-[0-9]+' tasks/*.md | grep -oE '[0-9]+' | sort -n | tail -1
  ```
- **Discovered work becomes a new task**, not a bigger current one. One logical
  change per commit is what keeps a PR reviewable.
- **Status moves in one direction** per pass: `planning` → `in-progress` →
  `needs-review` → `approved`, or back to `changes-requested`.
- **A `[x]` closes the record, not always the work — the Status line's first
  words say which.** A Status beginning `superseded` or `closed as duplicate`
  means the open work survives under exactly one other `- [ ]` id, named in that
  first sentence. There is deliberately no third checkbox state:
  `check-task-ids.sh` parses only `- [ ]`/`- [x]` lines, so any other marker
  would make that id invisible to the collision guard, and a `- [ ]` stub would
  count the same work as pending twice.
- **Record what you decided not to do, and why**, in `known-gaps.md` with the
  trigger that makes it due. A gap nobody wrote down gets rediscovered as a bug.
- **A surviving SHOULD-FIX from a review lands here**, not in an agent
  transcript nobody will read again.

## Who does what

| Agent | Role |
|---|---|
| `planner` | Writes the file. No write access to source, so planning cannot drift into implementing. |
| `builder` | Implements pending tasks, one at a time, with tests. |
| `tester` | Finds the cases the builder's tests miss. |
| `reviewer` | Reads only. Reports and raises fix tasks; does not repair what it finds. |
| `documenter` | Updates the docs the change invalidated. |
| `hyper-critical-reviewer` | The gate in the `reviewed-change` loop. Measures against `docs/review-bar.md` and verifies by executing, not by reading. |

The split is the point. An agent that can fix what it finds stops looking once
it has found something.
