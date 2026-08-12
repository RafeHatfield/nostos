# AI development practices

How agent-assisted work is run in this repo. Ported from the sibling projects
(`starfish`, `insanity-peppers`) at scaffold time and adapted for a game.

## The shape

Five project agents with disjoint jobs, plus a global gate:

| Agent | Writes? | Job |
|---|---|---|
| `planner` | No | Turns a request into an ordered task file with a verification per task |
| `builder` | Yes | Implements one pending task at a time, with its tests |
| `tester` | Yes | Finds the cases the builder's tests miss |
| `reviewer` | No | Reads the diff, reports, raises fix tasks |
| `documenter` | Yes | Updates the docs the change invalidated |
| `hyper-critical-reviewer` | No | The gate. Verifies by **executing**, measures against `docs/review-bar.md` |

**The split is the point.** An agent that can fix what it finds stops looking
once it has found something, so `planner` and the two reviewers have no `Write`
or `Edit`. They do have `Bash`, which can technically write; that boundary is an
instruction rather than an enforcement, and it is on them to honour it.

## The loop

The default for behaviour-changing work is the `reviewed-change` skill:

1. **Fix the bar first.** `docs/review-bar.md` is the acceptance criterion. If a
   change would meet the bar as written but the bar is wrong, change the bar
   deliberately and separately — do not argue past it in a review.
2. **Build.** One workstream at a time unless parallelism was asked for.
3. **Review** with `hyper-critical-reviewer`, and **name the risks you want
   attacked**. This is the difference between a review that finds the subtle
   defect and one that finds style nits. If you know where you made a judgment
   call, say so and ask for it to be attacked.
4. **Send back** with the reviewer's own words, verbatim where they contain a
   reproduction. Require a test that fails before the fix and passes after.
5. **Re-review with the same reviewer** via `SendMessage`, so it checks its own
   findings rather than forming fresh opinions.
6. **Land it** when a reviewer says ACCEPT. Carry surviving SHOULD-FIXes into a
   task file **with the trigger that makes them due**.

Off for documentation, comments, formatting, and config values. Say which you
judged it to be in one clause, so it can be disagreed with cheaply.

### Stop conditions, set before starting

- **Two review rounds per piece.** A third needs a reason said out loud, because
  a third round usually means the piece is wrong rather than nearly right.
- **A round returning only NITs is a clean round.** Stop; carry them forward.
- **The same blocker twice without a new strategy** means stop fixing instances
  and audit for the class at once.
- **If agents die mid-pass, stabilise before starting anything new.** Get the
  tree building and passing by hand first. A half-finished tree is worse than
  either finished state.

### Coupling beats parallelism

Broad fan-out performs worse than sequential ownership on coupled systems. In a
game this bites harder than in a web app: a simulation, its renderer, and its
tuning data look like three separable files and are one system. Parallelise
across genuinely separable systems; within one, take sequential ownership even
when the file lists look disjoint.

## The guards

Instructions are advice; hooks are rules. An agent that has been working for an
hour and is trying to be helpful will occasionally decide that just this once it
is fine to commit to `main`. The hook does not have opinions.

| Guard | Event | Enforces |
|---|---|---|
| `guard-git.sh` | PreToolUse (Bash) | Branch → PR → merge; one working copy per session |
| `claim-working-copy.sh` | SessionStart | Warns at session start if another live session holds this checkout |
| `release-working-copy.sh` | SessionEnd | Releases this session's claim so the next one is not blocked for 15 minutes |
| `check-no-conflict-markers.sh` | `test-hooks.sh` | A conflict marker in a Markdown file breaks no build and fails no test — this is the only thing that sees it |
| `check-task-ids.sh` | `test-hooks.sh` | Every `TASK-nnn` claimed exactly once. Two branches claiming one id merges cleanly and is invisible |

Run them all:

```bash
./scripts/claude-hooks/test-hooks.sh
```

### Two things `guard-git.sh` deliberately does not block

Both verified by probing the guard directly, 2026-08-12:

- **A commit before the repo has any commits.** On an unborn branch
  `git rev-parse --abbrev-ref HEAD` fails, so the guard sees no branch and
  permits the commit — its documented fail-open stance. This is a one-time
  window that closes the moment the first commit exists, and it is what allows
  the initial commit to be made on `main` at all. Every commit on `main` after
  that is blocked.
- **Nothing about the first push.** `git push origin main` is denied from the
  outset, including the push that first publishes the repo to a new empty
  remote. That one push is a legitimate human exception; make it from an
  ordinary terminal rather than weakening the guard.

Each guard has a `.test.sh` case table that runs **before** the guard itself.
This is not ceremony: a checker nobody has tried to defeat is a checker you are
guessing about, and several of these had silent bypasses that returned success
while checking nothing.

**There is no CI yet** (`tasks/known-gaps.md` CI-1), so nothing currently gates a
merge. When CI arrives it must invoke `test-hooks.sh` rather than re-listing the
guards, so the two cannot drift.

## Permission gates are not review gates

Review judges quality. It does not authorise action. Committing, pushing,
posting, deleting, spending, and anything outward-facing need a human decision
regardless of how clean a review was. A reviewer's ACCEPT is not that decision.
