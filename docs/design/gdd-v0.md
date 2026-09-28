# Nostos — GDD v0

*Working title: **Nostos** — the Greek word for the homecoming journey (root of "nostalgia": the pain of the return). Lineage: Xenophon's* Anabasis*, the original germ of this idea in its novel form. Draft v0 — concept capture only. Not a build plan.*

---

## One-line pitch

You command the remnants of a lost army, fighting across an unknown land to answer one question: which way is home — and will it still be there?

## The three sentences (design north star)

1. **The army is the largest it will ever be.** Every soldier lost is lost forever. Attrition is the core tension.
2. **Knowledge of the way home is the win condition.** Progress is measured in learning, not territory.
3. **The undefended homeland is the clock.** Time pressure is baked into the fiction; turtling has a cost you feel but never fully see.

If a proposed feature doesn't serve one of these three, it's out.

---

## Premise

Bronze age. An army puts to sea to strike its enemy. A storm scatters the fleet and drives the survivors onto an unknown shore. They are a fraction of their former strength — but well equipped, veteran, and desperate. They don't know where they are, how far home is, or even which direction to march. What they do know: the whole army sailed, so the homeland is undefended, and the enemy is still out there.

The only way home is forward.

## Genre & feel

- **Genre:** Roguelike expedition / squad-attrition tactics. FTL/Slay the Spire run structure; Banner Saga / Battle Brothers emotional register.
- **Feel:** Desperate, finite, precious. Small legible fights where losing eight men matters. Dread, not power fantasy. The inverse of Civ — you start at your peak and manage decline.
- **Explicitly not:** 4X, base-building, tech trees, large-scale empire play.

## Core loop (run structure)

1. **Landfall.** A run begins with a randomized surviving force (composition, equipment, notable individuals) on a procedurally assembled coastline.
2. **The map.** A node map (FTL/StS style) pushing inland or along the coast. Node types: battles, encounters, forage/rest, settlements, intel opportunities.
3. **Decisions.** Route choice, which fights to take, what lives are worth spending, whether to recruit locals, when to detour for intel vs. push on.
4. **Resolution.** A run ends in: finding the way home (win), the army's destruction (loss), or a late-run branch ending (see below).
5. **Meta-progression.** Survivors, knowledge, and legend carry forward between runs (light touch — details TBD).

## Core resources

- **Men** — HP is literally people. Squads/individuals carry skills; losing the armorer means armor degrades. People are both health *and* the skill tree.
- **Supply** — food/equipment condition. Drives forage decisions and route pressure.
- **Morale** — the army's will to continue. (Candidate for cutting if scope demands; see Open Questions.)
- **Intel** — the win-condition resource. Fragments of navigation knowledge: captured guides, charts, star lore, trade-route rumors. Accumulating enough intel (and acting on it) is how you find the way home. Mostly data + text = cheap content, high volume.

## The clock

The undefended homeland. Never directly shown. Ambient pressure via seasons passing and occasional ambiguous rumors ("a trader speaks of a war in the west…"). Mechanically: soft escalation over run length (harsher weather, emboldened locals, dwindling supply availability) rather than a hard timer.

## Combat (deliberately underspecified in v0)

Scope risk lives here. Direction: **compact and legible**, not a full tactics engine.

- **Candidate A (leading): "General on the hill" — plan, then watch.** Bronze age command had no radios; the model simulates that. Phases:
  1. *Scout* — pre-battle information quality depends on living scouts / intel skills. Bad scouting = deploying blind.
  2. *Deploy & brief* — position squads, assign behavior orders (hold, advance, skirmish, flank, reserve), and choose which leader commands each squad.
  3. *Watch* — battle resolves from orders + leader personalities. Player intervention limited to a tiny budget of **horn signals** (2–3 per battle, coarse: fall back / commit reserve / loose) so watching stays gripping without micro.
  - Leader personalities are *tags, not systems*: 2–3 traits per captain (Rash, Steady, Cautious, Vengeful…) that modify how they execute orders. Player skill = matching orders to men. Leader death = losing the only man you trusted to anchor a flank — attrition dread expressed inside combat.
  - Precedents: Dominions (scripted orders + replay), Door Kickers (plan/execute), Mechabellum (deployment), Gladiabots (behavior programming).
  - Risks: watch phase must be readable and short; needs the horn-signal pressure valve to avoid cutscene-when-it-goes-wrong feel.
- Candidate B: small tactical puzzle — a handful of squads, tiny board, few turns.
- Either way: portrait-mode friendly, playable in 2–5 minute sessions, losses visible and named.

Final decision deferred until prototyping. Whichever is chosen, the design test is: *does losing specific people hurt, and did the player choose to risk them?*

## Endings (breadth without building three games)

Same map, same systems, different final choice:

- **Home** — the primary goal. Find the way; what you find there varies (did they hold?).
- **Settle** — the fail-forward ending. Army ground down too far; survivors put down roots. Bittersweet, not a fail screen.
- **The mad option** — recruitment went unusually well; you're strong enough to sail for the *enemy* instead. Rare, earned, late-run unlock.

## Recruitment

Locals can join — the pressure valve on pure attrition. Tension: diluting the veteran bronze-age core with levies who fight differently, may not share the goal, and change the army's identity. Should feel like a meaningful trade, not free HP.

## Platform & constraints

- **Mobile first, portrait mode.** PC/Steam release open as a later port, not a design driver.
- **Solo dev, background project.** Sessions built in small time slices; systems chosen for content that's cheap to author (text encounters, data-driven intel, small battles).
- **Toolchain:** Claude Code assisted development. Engine TBD (whatever the first shipped game proves out).

## Scope guardrails (v0)

- One biome family per early build; expand later.
- No overworld simulation. The world exists only as the node map + text.
- Combat scale capped at "a handful of squads." If a feature needs a bigger battlefield, cut the feature.
- Meta-progression minimal at first: unlock-style, not economy-style.
- Art style must be sustainable solo — decide early, decide cheap.

## Open questions

1. Squads vs. named individuals as the atomic unit — or squads *containing* named specialists?
2. Is Morale a real system or folded into events/intel? (Three resources may be enough.)
3. Combat: does plan-then-watch hold up in a paper/cheap digital prototype? How few horn signals is enough agency?
4. Run length target? (Gut: 1–2 hours across many short sessions.)
5. How literal is the map? Abstract node graph vs. geographic-feeling coastline?
6. What exactly carries between runs, and how does it stay light?
7. Setting: explicitly historical-adjacent (Sea Peoples / bronze age collapse vibes) or invented world?

## Next actions (when germination ends)

- Play/study: Banner Saga (caravan attrition), FTL (run structure), Battle Brothers (named-unit loss), Slay the Spire (node map).
- Paper-prototype the intel system — can "finding the way home" be made fun with index cards?
- Tiny combat prototype: one fight, eight names, see if a loss stings.
