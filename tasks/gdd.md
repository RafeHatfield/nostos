# GDD — research and design document

Status: in-progress

## Context

`docs/design/gdd-v0.md` is concept capture, not a build plan. This file tracks
turning it into a document a stranger could build from, judged against
`docs/design-bar.md` — best indie solo-developer entry in the field, and fun.

The loop is the `reviewed-change` one, applied to design rather than code:
research → draft → hyper-critical review → send back → re-review, with no
round cap set by Rafe. The bar file the reviewers measure against is
`docs/design-bar.md`, not `docs/review-bar.md`; the latter judges code and would
send a reviewer looking for the wrong defects.

**The evidence rule is the one that matters this round.** The GDD is being built
on research into player sentiment, and a fabricated player quote is
indistinguishable from a real one and would shape years of work. Every research
pass is followed by an adversarial pass that fetches the cited URLs and checks
the quotes are really on the pages.

## Tasks

- [ ] TASK-011: Genre research round 1 — 12 sourced dimensions, each verified
  - Status: in-progress
  - Detail: twelve parallel research passes on what players love and hate in
    Nostos-adjacent games, each followed by an adversarial evidence check that
    fetches the citations and annotates anything unsupported as STRUCK or
    DOWNGRADED. Then a cross-dimension synthesis, then a completeness critic
    asking what nobody looked at. Dimensions: attrition/permadeath,
    watch-combat agency, run structure and node maps, expedition/caravan games,
    knowledge-as-progress, morale/stress, mobile roguelike UX and market,
    solo-dev scope, managing decline, meta-progression, character attachment,
    setting and competition.
  - Files: `docs/research/*.md`, `docs/research/SYNTHESIS.md`
  - Verify: every claim driving a design decision carries a URL that a second
    agent fetched and confirmed. Any dimension returning EVIDENCE-CORRUPT is
    re-run rather than used.

- [ ] TASK-012: GDD v1 — draft every section from the verified research
  - Status: pending
  - Depends on: TASK-011
  - Detail: `docs/design/gdd.md`. Sections drafted in parallel by section owner,
    each required to cite the research that drove its decisions and to state the
    player decision, its cost, and the story it produces — `docs/design-bar.md`
    §"Fun is a claim that has to be made checkable".
  - Verify: reads as one document, not twelve. Every north star has at least one
    mechanic implementing it; every mechanic serves at least one north star or is
    on the cut list.

- [ ] TASK-013: Hyper-critical review rounds until ACCEPT
  - Status: pending
  - Depends on: TASK-012
  - Detail: no round cap. Each round leads with the single largest gap between
    the document and `docs/design-bar.md` before its ranked findings. Re-reviews
    go to the *same* reviewer via `SendMessage` so it checks its own findings
    rather than forming fresh opinions; a final round before locking uses a
    fresh critic with no history, because by then the question is "is this good"
    rather than "did you fix what I said".
  - Verify: a round that returns only NITs. That is a clean round and the stop
    condition — not a signal to ask for another pass without naming a new risk.

- [ ] TASK-014: Resolve the combat candidate
  - Status: pending
  - Depends on: TASK-011
  - Detail: v0 leaves plan-then-watch ("general on the hill") versus small
    tactical puzzle open, and names it the biggest scope and fun risk. The
    research round attacks it directly. This task states the kill criterion and
    runs the cheapest experiment that could fail it — paper or index cards before
    any engine work. Record the outcome in `docs/decisions/`.
  - Verify: a result that would make the leading candidate be abandoned, stated
    in advance, and then actually tested against. "Prototype it and see" is not
    a kill criterion (`docs/design-bar.md` §"Named risks need kill criteria").

- [ ] TASK-015: Paper-prototype the intel system
  - Status: pending
  - Depends on: TASK-011
  - Detail: knowledge-as-win-condition is the design's most unusual idea and its
    most fragile. The existential question the research is asked to answer: if
    intel is the win condition, what stops run two being trivial once the player
    already knows the answer? Prototype with index cards.
  - Verify: a person who has "won" once plays again and the second run is still
    a game. If it is not, the win condition needs rebuilding, not tuning.

- [ ] TASK-016: Content bill and cut list
  - Status: pending
  - Depends on: TASK-012
  - Detail: price every system in content — encounters, enemies, items, strings,
    sprites — against what comparable solo games actually shipped with. Then the
    ordered cut list: what goes first if the schedule halves.
  - Verify: the bill is payable by one person working in small time slices, with
    the arithmetic shown. A GDD with no cut list has not been costed.

- [ ] TASK-017: Decide mobile-first versus Steam-first
  - Status: pending
  - Depends on: TASK-011
  - Detail: v0 fixes mobile-first portrait with PC as a later port. The market
    dimension of the research is asked for the honest commercial picture for a
    premium mobile indie roguelike versus a Steam-first release. This may be the
    most uncomfortable finding of the round; the decision is Rafe's, and it gets
    a `docs/decisions/` file either way because it closes an option.
  - Verify: the rejected option is written down with why, so it is not
    re-litigated in six months.
