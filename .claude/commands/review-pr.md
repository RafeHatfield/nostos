# /review-pr Command

Review a pull request in this repository and post findings as inline comments.

## Usage

```
/review-pr REPO: <owner/repo> PR_NUMBER: <n>
```

---

## REVIEW PROMPT

Review pull request $ARGUMENTS in this repository.

Report every issue you find, including ones you are uncertain about or consider
low-severity. Do not filter for importance — it is better to surface a finding
that a human dismisses than to silently drop a bug. For each finding include
confidence and severity so the reviewer can rank.

End the first line of every finding with exactly this marker:

    _(severity: high|medium|low · confidence: high|medium|low)_

Those six words and nothing else — not "important", not "minor", not a range
like "minor-important". A reporting step counts the severities and publishes the
breakdown, and it can only do that if the vocabulary is fixed. Pick the nearer of
two levels rather than inventing a third.

This is Nostos, a game project. Read `CLAUDE.md` first — it carries the
structural rule and the constraints that are not inferable from the code, and it
marks which parts of the project are still undecided. Read `docs/review-bar.md`
second: it is the acceptance criterion, and it is stricter than "does this work".
If `.claude/agents/reviewer.md` is present, follow its review order and its
"always critical" list rather than duplicating judgement here.

Priority checks for this repo:

1. **The layer boundary.** Game rules, state and physics live in `simulation`;
   drawing, audio, UI and camera in `presentation`; the window, devices and
   filesystem in `platform`; inert values in `data`. A gameplay value computed in
   a renderer or a UI widget is a bug **even when it is correct**, because it is
   invisible to every test in the project. This is the one structural rule the
   codebase has.

2. **Determinism and timestep.** Gameplay logic must not read the render delta,
   the wall clock, or an unseeded RNG. Flag any gameplay value multiplied by a
   variable delta, any iteration over an unordered collection whose order affects
   the result, and any physics or settling change with no replay proving old
   traces still produce old end states. This defect is invisible on the author's
   machine and appears on everyone else's, which is why it is second.

3. **Player data.** A save write that is not temp → fsync → rename. A format
   change with no version bump and no migration. A load path that starts a new
   game on corrupt data instead of reporting it and offering the backup. Losing a
   save is the one defect in this project that cannot be apologised for.

4. **Frame budget.** Allocation added to the frame loop — in a garbage-collected
   runtime that is a collection later and a hitch after that. Per-frame work that
   could be per-tick or once. Unbounded caches and containers that only grow. A
   performance claim with no measurement behind it is not a justification.

5. **Input.** Sampled at least once per simulation tick, never only on the render
   frame — sampling on the render frame drops presses exactly when frames are
   slow, which is when the player is pressing hardest. Every new action
   remappable; every hold with a toggle alternative; device connect and
   disconnect handled.

6. **Tests that would fail if the code were wrong.** For each test guarding a
   claim, ask what happens if the mechanism it guards is deleted. Flag goldens or
   snapshots that are regenerable as part of the normal workflow (regeneration
   turns a wrong value into the expected value), assertions made vacuous by an
   empty or absent input, and any assertion weakened to make something pass
   without the premise being explained.

7. **Art and presentation.** The look is low-resolution pixel art at or above
   Shattered Pixel Dungeon's quality, assembled from three sources — Oryx packs,
   PixelLab generations, and hand-authored work — which is precisely why it
   drifts. Flag: an asset whose dimensions are not an exact multiple of the
   canonical grid; any colour outside the palette; fractional scaling, bilinear
   filtering, sub-pixel sprite placement, or a camera not quantised to whole
   pixels (fine in a screenshot, shimmers in motion); a generated or purchased
   asset that entered the tree without normalisation to `docs/style-bible.md`;
   and any asset with no provenance and licence recorded — **this repository is
   public**, so an unrecorded pack asset is a licence question nobody can answer.

8. **Player-facing quality.** A player-visible number changed by something
   claiming to be a refactor. A string that is concatenated, baked into an asset,
   or not externalised. A UI element with no keyboard path, no text alternative,
   or state signalled by colour alone. A progress indicator that cannot
   distinguish "working" from "hung".

9. **Decisions taken by accident.** `CLAUDE.md` marks several things TBD and
   `tasks/known-gaps.md` records the rest. A PR that resolves one of those as a
   side effect — picking a save format, a min-spec, an engine-specific
   dependency — is acquiring a constraint nobody chose. Flag it even when the
   choice is a good one.

Post findings as inline comments on the specific lines.

**Always post a summary comment, including when you found nothing.** Title it
exactly `## Review summary`, as its first line. That heading is not cosmetic: the
reporting step counts findings by counting your comments, and it identifies the
summary by that string alone. Title it anything else and your summary is counted
as a finding against itself.

State plainly what you reviewed and what you concluded. "I read the diff across
N files and found nothing worth raising" is a useful result and a legitimate one
— silence is not, because from the pull request page a clean review and a
reviewer that never ran look identical. If you were unable to review something
(a file too large to read, a binary asset, a generated artefact), say which and
why rather than omitting it.

Do not report your own runtime, token cost, or number of turns. You cannot
observe them, and a plausible-looking invented figure is worse than none.

Do not approve or request changes — a human makes that call.

## Closing findings out

**This section is not for you.** You are the CI reviewer and you have no Bash. It
is here because this file is also read by whoever fixes the findings, and the
loop is only closed when they do this.

Findings are not done when they are posted. A pull request carrying twelve
unresolved threads looks like twelve open problems regardless of how many were
fixed, and from the Files tab "fixed in the next commit" and "ignored" are
indistinguishable.

When a finding has been dealt with, reply to its thread saying which of these it
was, then resolve it:

- **Fixed** — what changed, and how it was verified
- **Not an issue** — what you checked that the finding did not account for
- **Deferred** — the `tasks/known-gaps.md` entry it became, so it stays tracked

Leave a thread open when it is a genuine disagreement or a decision someone else
has to make.

---

## Where The Code Lives

The engine is not chosen yet (`tasks/known-gaps.md` ENGINE-1), so these are
module roles rather than paths. Update this section when TASK-002 lands the
skeleton.

- `simulation` — game state, rules, physics. Fixed timestep, seeded RNG, no I/O
- `presentation` — render, audio, UI, camera, feel
- `platform` — window, input devices, filesystem, platform services
- `data` — tuning values, content definitions, save schemas. Inert
- `scripts/claude-hooks/` — the git and task guards
- `tasks/known-gaps.md` — work deliberately deferred. **Check here before
  reporting something as missing**; if it is listed, say so rather than
  re-reporting it as new
