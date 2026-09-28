# Design bar

What "good enough to build" means for a design document. `docs/review-bar.md`
judges code; this judges design. A reviewer measures against this, not against
taste. Written 2026-08-13, when the GDD research round began.

## The two standards

Set by Rafe, 2026-08-13, recorded verbatim because they are the acceptance
criteria and they are easy to drift from:

> the bar is to be the best indie solo-developer entry in this field, and be fun

Both halves are load-bearing and they pull against each other. "Best in field"
tempts scope; "solo developer, background project" forbids it. **A design that
wins on ambition and cannot be built by one person in small time slices has
failed this bar, not exceeded it.**

## The one sentence

**A stranger could build this game from the document, and a player who finishes
one run would start a second.**

The first half is a test of specification. The second is a test of fun. A GDD
that passes only the first is a spec for something nobody plays; one that passes
only the second is a pitch.

## Fun is a claim that has to be made checkable

"Fun" cannot be asserted. It can be decomposed, and each part can be checked:

1. **Name the decision.** For every system, what decision does the player make,
   how often, and with what information? A system where the player has no
   decision is a cutscene. A system where the decision is obvious is a chore. A
   system where the decision is invisible in its consequences is a slot machine.
2. **Name the cost.** An interesting decision costs something the player cares
   about and cannot undo. In Nostos that is usually people — which is the design
   working as intended, but it must be *chosen*, not levied.
3. **Name the story it produces.** The v0 test — "does losing specific people
   hurt, and did the player choose to risk them?" — generalises: what sentence
   does the player say to a friend afterwards? If a system generates no such
   sentence, it is bookkeeping.
4. **Name the second-run reason.** What does a player know or want on run two
   that they did not on run one? If the answer is only "numbers went up", the
   design is leaning on meta-progression to do what depth should.
5. **Name what it feels like on a phone, in four minutes, one-handed, on a bus,
   interrupted.** This is the actual play context (v0: mobile-first, portrait,
   small time slices). A loop that only works in a 40-minute uninterrupted
   sitting is not this game's loop.

## Evidence: the rule that matters most in this round

This document is being built on research into what players love and hate about
comparable games. That research is worthless if any of it is invented, and
**invented research is the single most likely way this project goes wrong**,
because a plausible fabricated player quote is indistinguishable from a real one
and will sit in the document shaping decisions for years.

- **Every claim about what players think cites a source that was actually
  retrieved.** A URL that was fetched, with what it says. Not a remembered
  review, not a plausible paraphrase, not a synthesised "players often say".
- **A fabricated quote, review, sales figure, or player count is a BLOCKER and
  is treated as the most serious category of finding in this project.** Not an
  inaccuracy — a corruption of the evidence base.
- **Model recall is allowed, and must be labelled as such.** "From training
  knowledge, unverified" is a legitimate and useful contribution. Presenting it
  as sourced is not. Where a claim is load-bearing and only recalled, say that it
  needs verifying before it drives a decision.
- **Numbers get their basis or they do not appear.** No invented review counts,
  no invented revenue, no invented retention figures.
- A reviewer's first job on any research section is to pick the most
  decision-shaping claim and try to break its evidence.

## Scope realism

- **Every system is priced in content.** How many encounters, items, enemies,
  strings, sprites does it need to not feel thin? A system whose content bill is
  unpayable by one person is a cut, not a stretch goal.
- **Every system states what it costs to build and what it costs to keep.**
  Maintenance is the hidden killer of solo projects.
- **The v0 guardrails are constraints, not suggestions**: one biome family, no
  overworld simulation, a handful of squads, minimal meta-progression, art that
  is sustainable solo.
- **A cut list is part of the document, not an appendix.** Name what goes if the
  schedule halves, in order. A GDD with no cut list has not been costed.

## The three north stars are a filter, and the filter must bite

From v0, and unchanged:

1. The army is the largest it will ever be. Attrition is the core tension.
2. Knowledge of the way home is the win condition. Progress is learning.
3. The undefended homeland is the clock.

**A feature that serves none of these is out.** A reviewer that finds a feature
in the document serving none of them and not marked for cutting has found a
BLOCKER. Equally: a north star that no mechanic actually implements is a slogan,
and that is also a BLOCKER — north star 3 is the one most at risk of it, because
"ambient pressure never directly shown" is one edit away from "does nothing".

## Named risks need kill criteria

The v0 already names its biggest one: plan-then-watch combat may not be fun.

- Every named risk states **the cheapest experiment that would kill it**, and
  **what result means abandon rather than iterate.** "Prototype it and see" is
  not a kill criterion.
- A design that hides its riskiest assumption inside a section about something
  else is worse than one that states it badly.
- Where two candidate designs exist, the document says what evidence would
  choose between them, and does not quietly pick one by writing more words about
  it.

## Anti-patterns, each of which has sunk a real game

- **A feature list pretending to be a loop.** Systems listed without the minute
  they occupy in the player's session.
- **Depth claimed through quantity.** Twenty items that do not interact are
  shallower than five that do.
- **Systems that only talk to themselves.** A resource that only feeds its own
  subsystem is a tax.
- **Difficulty as content.** Harder numbers are not more game.
- **Meta-progression covering for a thin run.** If run one is not fun, unlocks
  do not fix it; they postpone the discovery.
- **Narrative as apology.** Text that explains why a mechanic is unsatisfying
  rather than a mechanic that is satisfying.
- **The dread register as an excuse for player helplessness.** "Desperate,
  finite, precious" is a feeling to produce through choices, not through
  removing them. This is the specific way Nostos could fail while executing its
  stated tone perfectly.

## Verdicts

- **ACCEPT** — good enough to build from. Say it plainly.
- **SEND BACK** — one or more BLOCKERs.
- **BLOCKER** — fabricated or misattributed evidence; a system with no player
  decision; a feature serving no north star and not marked for cut; a north star
  no mechanic implements; an unpayable content bill; a named risk with no kill
  criterion; or a claim about players with no basis given.
- **SHOULD-FIX** — real, not blocking. Carried into the task file with a trigger.
- **NIT** — taste. A round returning only NITs is a clean round.

Lead with **the single largest gap between what exists and what this bar asks
for**, before the ranked list. On a document this size the through-line matters
more than the list, and a list of thirty findings hides it.
