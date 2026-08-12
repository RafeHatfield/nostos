# Known gaps

Work deliberately not done. Each entry records what it costs to leave it and what
would trigger doing it. A gap nobody wrote down gets rediscovered as a bug.

Check here before reporting something as missing. If it is listed, it is a
decision, not a discovery — say so rather than raising it as new.

## ENGINE-1: The engine has not been chosen

- **What**: no engine, language, or renderer is picked. Most of `CLAUDE.md` is
  provisional until it is.
- **Cost**: nothing can be built. Every day this stays open is a day of
  scaffolding that may need redoing.
- **Constraint the choice must satisfy**: the structural rule in `CLAUDE.md` —
  simulation runnable headless, deterministically, faster than real time, with
  no window and no GPU. An engine that cannot do this rules out golden replays
  and every determinism proof in `docs/review-bar.md`, so it is not a
  preference, it is a filter.
- **Trigger**: the first line of gameplay code. Resolve it before, not during.
  Record the decision and the rejected options in `docs/decisions/`.

## PERF-1: Min-spec is not defined

- **What**: every frame-time, memory and load-time budget in
  `docs/review-bar.md` is stated "on min-spec", and min-spec does not exist.
- **Cost**: performance findings are unfalsifiable. A reviewer measuring on a
  workstation and a reviewer measuring on a laptop reach opposite verdicts and
  both are defensible, which makes the budgets decorative.
- **Interim rule**: measure on the lowest-powered machine available and name it
  in the report. A number with no hardware named is not a finding.
- **Trigger**: the first performance-sensitive system, or the first platform
  commitment — whichever is sooner.

## ASSET-1: Git LFS is not installed or enabled

- **What**: `git-lfs` is absent on this machine. `.gitattributes` carries the
  LFS block commented out, and marks binary types `binary -merge` so git will at
  least not corrupt one by trying to merge it.
- **Cost**: none while the repo is text-only. The moment a texture, a sound, or
  a model is committed without LFS, the repo carries that blob and every future
  version of it forever, and fixing it means rewriting history that other people
  have already pulled.
- **Trigger**: **before the first binary asset is committed.** Install
  `git-lfs`, run `git lfs install`, uncomment the block in `.gitattributes` as a
  whole, and confirm the remote has LFS enabled. Do not enable it for a subset
  of the types — a repo where half the binaries are in LFS is the hardest state
  to reason about later.

## STYLE-1: There is no style bible, so the canonical grid and palette are undecided

- **What**: `docs/review-bar.md` §7 sets the standard at Shattered Pixel Dungeon
  or better, and every rule in it — one density, a closed palette, one outline
  convention, one light direction — refers to a specification that has not been
  written. The tile grid, the palette, and the animation frame budget are all
  open.
- **Cost**: art cannot be reviewed. Worse, art can be *made*, which is the actual
  danger: assets authored before the bible exists are authored against three
  different implicit bibles (Oryx's, PixelLab's defaults, and whatever the
  hand-authored piece assumed), and reconciling them later is redrawing them.
- **Trigger**: **before the second asset lands.** Not the first — one asset can
  be the reference the bible is written from. Twenty cannot.

## ART-1: No asset provenance or licence register, on a public repository

- **What**: nothing records where an asset came from — which Oryx pack and under
  what licence, which PixelLab prompt/model/seed, or which hand-authored source
  file. `docs/review-bar.md` §7 and §10 both require it; no mechanism exists.
- **Cost**: two distinct failures, each able to sink a release.
  1. **Licence.** Oryx licences generally permit shipping the art inside a game
     and forbid redistributing it as art. **This repository is public**, so
     committing a raw pack is plausibly redistribution. Nobody can currently
     check what is in the tree or under what terms.
  2. **Regeneration.** A PixelLab asset whose prompt and seed were not recorded
     cannot have a matching sibling generated later — no walk cycle, no damaged
     variant, no recolour. That quietly constrains design six months on, and the
     constraint looks like a design decision rather than a bookkeeping failure.
- **Trigger**: **before the first non-hand-authored asset is committed.** Read
  the Oryx licence actually purchased before that commit, not after. If it
  forbids redistribution, the pack is fetched at build time and never enters the
  repo.

## HOOK-1: `guard-git.sh` only inspects `git`, so `gh` can push around it

- **What**: the guard gates on a command matching `git<space>`. `gh` subcommands
  that push, merge, or move refs — `gh repo create --push`, `gh pr merge` — never
  match, so the branch protection does not see them. Discovered 2026-08-12 while
  publishing this repo: `gh repo create --public --source=. --push` put the first
  commit on `main` on the remote without the guard being consulted, where the
  equivalent `git push origin main` is denied.
- **Cost**: the branch → PR → merge rule is enforced against one of the two tools
  in routine use here. An agent that hits the deny on `git push` and reaches for
  `gh` next is one substitution away from doing exactly what the guard exists to
  prevent — and `gh` is the tool the `/review-pr` and `create-issue` workflows
  already push agents toward.
- **Not fixed on the spot deliberately**: widening the matcher is a change to a
  guard with a 72-case table, and it wants its own cases (`gh pr merge`,
  `gh repo sync`, `gh api` calls that write refs) rather than a hurried regex
  bolted on during setup.
- **Trigger**: before a second person or a long-running agent works in this repo.
  Until then the exposure is that someone bypasses it by accident, and the people
  here know it is there.

## CI-1: There is no CI

- **What**: `scripts/claude-hooks/test-hooks.sh` runs the guards, but only when
  someone runs it. Nothing gates a merge.
- **Cost**: a guard that runs only locally runs nowhere that stops a bad merge.
  `docs/review-bar.md` asserts perf budgets "in CI"; today that assertion has no
  enforcement behind it.
- **Trigger**: the first PR from a second contributor or agent, or the engine
  decision — whichever is sooner. The CI job must invoke `test-hooks.sh` itself
  rather than re-listing the guards, so the two cannot drift.

## DOC-1: No design document, so `CLAUDE.md` has no design rules

- **What**: the "Design rules" section of `CLAUDE.md` holds only the two rules
  the review bar already fixes (save integrity, accessibility). There is nothing
  about what the game is.
- **Cost**: a reviewer cannot catch a change that contradicts the design,
  because the design is not written down. Everything found will be a correctness
  finding; nothing will be a design finding.
- **Trigger**: the first gameplay system. A system built against an unwritten
  design gets rebuilt.
