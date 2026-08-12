# Review bar

What "good enough to land" means here. A reviewer measures against this, not
against taste. Written 2026-08-12, when the project was scaffolded.

`CLAUDE.md` holds the conventions and the structural rules; this file holds the
standard a change is judged against once those are already satisfied. **A change
can obey every convention and still fail this bar.**

The standard is AAA. Not AAA scope — scope is a budget decision and nobody has
made it yet — but AAA *execution*: the class of polish where the seams between
what was easy to build and what was hard to build are invisible from the couch.

## The one sentence

**Nothing the player experiences may be explained by how the game was made.**

A hitch, a lost save, an input that did not register, a subtitle that runs off
its box, a menu that is unreachable without a mouse. The player does not know
and does not care that the team was small, the deadline near, or the engine
unfamiliar. They know the game stuttered. AAA quality is not more content — it
is the **absence of seams**.

Everything below is that sentence made checkable.

## Before you can review anything: name the target

Every number in this file is measured **on min-spec, in a shipping build**, and
neither of those exists yet.

- **Min-spec is not yet defined.** See `tasks/known-gaps.md` PERF-1. Until it
  is, a reviewer measures on the lowest-powered machine actually available and
  **says which machine** in the report. A frame-time figure with no hardware
  named is not a finding, it is a rumour.
- **A dev build is not the subject.** Editor overhead, debug assertions, and
  unoptimised shaders make a dev build's timings unrelated to the shipped
  ones — in both directions. Where only a dev build exists, say so and treat
  every performance number as provisional.

Reviewing against an unnamed target measures nothing, and reads exactly like
reviewing against a met one. That failure mode is the reason this section is
first.

## The bar, in order of how often it is missed

### 1. The frame budget is a contract, not an aspiration

- **60 fps means 16.67 ms, at p99, on min-spec.** Not an average. An average
  frame rate hides every hitch, and hitches are the only thing the player
  actually feels. A build averaging 62 fps with a 90 ms spike every eight
  seconds is a failing build that reports as a passing one.
- **The percentiles that must hold:** p50 ≤ 16.67 ms, p99 ≤ 16.67 ms,
  p99.9 ≤ 33.3 ms. **No single frame above 50 ms** after the first playable
  frame. Three dropped frames is where a hitch stops being a measurement and
  starts being a complaint.
- **Zero steady-state heap allocation per frame** in the simulation and render
  hot paths. In a garbage-collected runtime this is the whole ballgame: an
  allocation per frame is a collection later, and a collection is a hitch.
  Verified with a profiler, not by reading the code.
- **A performance claim is a measurement or it is nothing.** "This should be
  faster" is not a finding and not a justification. Capture before, capture
  after, report both, name the scene and the hardware.
- Any change that adds work to the frame loop states its cost in the task file
  in milliseconds. A budget nobody is spending against is not a budget.

### 2. The simulation is deterministic and frame-rate independent

This is the highest-value class of defect in a game codebase and the most often
shipped, because it is invisible on the developer's machine and only appears on
someone else's.

- **Fixed timestep for simulation, variable for render, interpolation between.**
  Gameplay logic multiplied by a variable delta produces a game that plays
  differently at 144 Hz than at 60 Hz, and the difference is usually
  advantageous, which makes it a fairness bug as well as a correctness one.
- **The proof is a replay, not an argument.** An identical input trace must
  produce an identical final state at 30, 60, 144 and 240 fps, and on a
  different machine. If that test does not exist for the system under review,
  its determinism is a claim.
- **No gameplay decision may read from the render clock, wall-clock time, or an
  unseeded RNG.** Every consumer of randomness takes an explicit, seeded stream.
  "It's only cosmetic" is how a cosmetic RNG ends up branching a spawn table.
- Physics settling, animation events, and anything integrating over time are
  where this breaks first. Attack them first.

### 3. Player data is sacred

Losing a save is the only defect in this list that cannot be apologised for. The
player does not get their forty hours back and does not come back.

- **Writes are atomic.** Write to a temp file, fsync, rename over the target.
  A save interrupted by power loss, a force-quit, or a console suspend must
  leave either the old save or the new one intact — never a truncated file.
- **The format is versioned from the first byte written**, with a forward
  migration path. Retrofitting a version field onto a shipped save format means
  guessing at what shipped.
- **A rolling backup of at least the previous save**, and an autosave that never
  overwrites the only copy.
- **Corruption is detected and reported, never silently reset.** A save that
  fails to load must say so and offer the backup. Silently starting a new game
  is the worst possible behaviour: it destroys the evidence and the data in one
  step.
- The same applies to settings and key bindings. A player who remapped every
  control and lost it will remap them once and then stop playing.

### 4. Input is never lost and never late

- **End-to-end latency ≤ 3 frames** from device event to the corresponding pixel.
  Every buffered frame the renderer holds is a frame of latency; count them and
  state the number.
- **No input is dropped**, including inputs that arrive between simulation ticks
  and inputs that arrive during a loading screen or a frame spike. A button
  press sampled once per render frame is a dropped press whenever the render
  frame is slow — which is exactly when the player is pressing hardest.
- **Every action is remappable**, including stick and trigger bindings, and a
  remap survives the game restarting.
- **Device changes mid-session are ordinary, not exceptional.** Controller
  unplugged, battery dead, a second pad connected, keyboard and pad used in
  the same session. Each must be handled without losing state and without a
  modal that eats the next input.

### 5. The states nobody chose

The set of situations a player reaches without meaning to. This is where the
seams show, because nobody plays through them during development.

First run with no save. A corrupt save. A full disk mid-write. No audio device.
No controller. The controller disconnected mid-input. Alt-tab during a loading
screen. Minimised for an hour. A resolution or monitor change while running.
Suspend and resume. A cable pulled mid-transaction. A locale the game has no
strings for.

For each: does the game say something true, or does it hang, crash, or lie?
**A wrong answer that looks exactly like a right answer is the defect class to
hunt.** A progress bar that stops moving and a game that has hung are
indistinguishable to the player; only one of them is acceptable, and the
difference has to be visible.

### 6. It survives being left running

- **An 8-hour soak with no crash, no leak, no drift.** Resident memory growth
  above ~1%/hour is a leak until proven otherwise. Frame time at hour eight
  matches frame time at minute one.
- **Crash-free session rate ≥ 99.5%**, and **zero known crashes on any path a
  player can reach in a shipping build.** A known crash with a workaround is
  still a crash.
- **Hard memory ceiling on min-spec, and nothing unbounded.** Every cache has an
  eviction policy. Every pool has a size. A container that only grows is a leak
  with a longer fuse.
- Repeated level transitions are the standard leak harness: load, unload, repeat
  fifty times, and compare.

### 7. The art reads as one hand

The look is low-resolution pixel art in the register of **Shattered Pixel
Dungeon**, and the standard is to **meet or exceed** it. SPD is the control
because it is stylistically airtight — one author, one palette, one outline
convention — and because it is a game people describe as looking good rather
than as looking cheap, at a resolution where cheap is the default outcome.

Nostos does not have one author. Art comes from three places: **Oryx** packs,
**PixelLab** generations, and hand-authored work. That is the entire risk. Three
sources with three native densities, three palettes and three ideas about
outlines will produce a game that looks assembled, and assembled is exactly the
seam this bar exists to remove.

**The test, in one sentence: a player must not be able to sort the game's assets
into piles by where they came from.**

- **The style bible is the contract, and it does not exist yet**
  (`tasks/known-gaps.md` STYLE-1). It fixes the canonical tile grid, the closed
  palette, the outline convention, the light direction, the value structure, and
  the animation frame budget. Write it **before the second asset lands**:
  normalising twenty assets is an afternoon, normalising two thousand is a
  project that never gets scheduled.

- **One pixel density, everywhere.** SPD works on a 16×16 tile grid; nostos
  picks its own once and then never mixes. Oryx packs ship at their own
  dimensions and PixelLab generates at whatever it is asked for, so **assets are
  resampled to the canonical grid at import or rejected there** — never scaled at
  runtime by a fractional factor. A 24 px tile drawn at 16 px has pixels of two
  different sizes in the same image, and that is the single loudest tell that a
  game was assembled from packs.

- **Integer scaling, nearest neighbour, no exceptions.** No bilinear filtering,
  no sub-pixel sprite positions, no rotation of pixel art off multiples of 90°,
  and the camera snaps to whole pixels. **This directly constrains §1's
  interpolated rendering:** interpolate the simulation, then quantise the
  presented position to the pixel grid. Interpolating straight to the screen
  makes the whole scene shimmer, and it is invisible in a screenshot and
  unmissable in motion.

- **The palette is closed.** Every shipped pixel is a colour the bible names.
  Both other sources violate this by default — a generator will hand back two
  hundred shades where the bible allows thirty-two, and a purchased pack arrives
  in its own palette entirely. Enforced by an import validator, **not by eye**:
  a single off-palette colour is invisible, and four hundred of them are the
  reason the game looks muddy for a reason nobody can name.

- **Outline, light and contrast are rules, not preferences.** One outline
  convention — its weight, and whether it is black or a darkened hue of the fill.
  One light direction. A value structure where every entity separates from every
  tile it can stand on. SPD's readability comes from silhouette and value
  contrast, not from detail; adding detail at this resolution subtracts
  legibility.

- **Readability is tested at native resolution, not at the zoom you author in.**
  Every entity must be identifiable **by silhouette alone at 1×**, and must
  survive being viewed in greyscale. That second test is the same one §8 asks for
  colour-blind players, and the overlap is not a coincidence: a sprite that
  relies on hue to be legible fails both.

- **Generated assets are raw material, not deliverables.** PixelLab output enters
  as a source file and does not ship until it has been quantised to the palette,
  re-outlined to the convention, cleaned of anti-aliased and orphan pixels, and
  **looked at beside the assets it will actually appear next to**. The failure
  mode is specific and repeatable: generated art looks right in isolation and
  wrong in situ, because it was generated without the context it has to sit in.
  - **Record the prompt, model and seed next to the asset.** You will need the
    walk cycle, the damaged variant, or the recoloured sibling later, and an
    asset whose companion cannot be regenerated is a dead end that quietly
    constrains design.

- **Provenance and licence are recorded per asset.** Two failure modes here can
  each sink a release on their own, and both are discovered late by default:
  - **Oryx licences permit shipping the art in a game and generally forbid
    redistributing it as art. A public repository with the raw pack committed is
    redistribution.** This repository is public. Read the licence actually
    purchased — do not infer it from this sentence — and if it forbids it, the
    pack does not go in the repo, it goes in a build-time fetch.
  - Anything whose rights are unclear cannot ship, and finding that out after the
    store page exists is not recoverable.

- **Do not take art or code from Shattered Pixel Dungeon.** A visual style is not
  copyrightable and imitating one is legitimate; SPD's actual sprites and source
  are copyrighted and GPL-3.0 licensed. Measure against it, do not copy from it,
  and do not paste its code into this project.

- **The blind comparison uses SPD as the control** (§11). Put a nostos screenshot
  beside an SPD screenshot at the same scale and have a critic say which looks
  more finished **before** being told which is which. "Meets SPD" assessed by the
  person who made the art always passes, which is why it is worth nothing.

- **UI and text are part of the art.** A pixel font at integer scale, not a
  hinted vector font at 11.3 px sitting next to 16 px sprites — that mismatch is
  the second loudest tell after mixed densities. The UI scales in integer steps
  across every supported window size, and stays legible at the smallest one.

### 8. Accessibility is a shipping requirement, not a stretch goal

This is table stakes at AAA, and in some markets it is a legal requirement.
Retrofitting it costs several times what building it in costs.

- **Subtitles on by default**, resizable, with an opaque background option and
  speaker names.
- **Full control remapping**, plus hold-to-toggle alternatives for every hold
  input, and no quick-time event that cannot be met with a single press.
- **Colour is never the only channel.** Every state distinguished by colour is
  also distinguished by shape, icon, position, or text. Check it in greyscale.
- **No unavoidable flashing above 3 Hz**, and any sequence that flashes is
  disableable. This one is a health risk, not a preference.
- **Text has a size floor** and the UI survives the largest supported size
  without clipping or overlap.
- **Difficulty and assist options exist** and never gate story content behind
  execution.

### 9. It is translatable

Cheap now, structurally expensive later. Every one of these is a rewrite if it
is discovered after the strings are written.

- **No concatenated sentences.** Word order differs by language; a sentence
  assembled from fragments is untranslatable in a way that is invisible in
  English.
- **No text baked into a texture.**
- **Layout survives +40% string expansion** (German is the usual worst case) and
  right-to-left mirroring.
- **Plurals and gendered forms go through the localisation system**, never
  through `if (n == 1)`.
- Dates, numbers, and currency are formatted by locale, never by hand.

### 10. Every asset is validated at import, and a bad one fails the build

- Budgets are enforced by the pipeline, not by memory: texture dimensions and
  compression format, audio sample rate and channel count, atlas occupancy, and
  draw-call counts per scene.
- **The §7 style rules are validators, not review notes.** Every one of these is
  mechanical and none of them is reliably caught by eye:
  - dimensions are an exact multiple of the canonical grid
  - every colour is in the project palette, no exceptions and no near-misses
  - no anti-aliased or semi-transparent edge pixels where the convention is a
    hard edge
  - the outline convention holds
  - no orphan pixels outside the silhouette
  - provenance and licence metadata present for every asset, or it does not
    import
- **A validation failure blocks the build.** A warning nobody reads is not a
  check. The reason this is non-negotiable: an uncompressed 4K texture that
  slipped through costs more frame time than a week of hand-optimisation buys
  back, and nobody finds it by looking.
- Builds are reproducible. The same commit produces the same output on CI and on
  a workstation, modulo timestamps. If it does not, nothing else in this file
  can be measured reliably.
- **`main` is always buildable and always playable.** A broken `main` blocks
  every person and every agent in the tree at once.

### 11. Feel is a specification, not a vibe

Camera, animation blending, hit feedback, audio mix, controller rumble, menu
timing, and **how the game looks in motion**. These cannot be unit-tested, which
is exactly why they need a harder process rather than a softer one.

- Where a change alters something a human judges, **produce the before and the
  after and have a critic say which is better without being told which is
  which.** This is the blind A/B from the `reviewed-change` skill, and it is the
  only thing that catches "the new version is worse in a way no rule forbids".
- Capture video for anything a screenshot cannot show. A description of how a
  jump feels is not evidence about how a jump feels. Pixel shimmer, camera
  judder, and animation that reads as floaty are all invisible in a screenshot,
  and all three are §7 failures that only motion reveals.
- Tuning values live in data with their intent recorded next to them. A magic
  number in code that someone spent an afternoon finding will be changed in five
  minutes by someone who does not know that.

### 12. Player-visible numbers are decisions, not side effects

- If a change alters damage, currency, drop rates, XP curves, timers, or
  anything a player can count, that is a **balance decision made explicitly**,
  recorded in the task file — never a side effect of a refactor.
- A refactor that changes a player-visible number is a failed refactor by
  definition. Byte-compare the outputs, or prove equivalence with a replay.
- Economy and progression changes state what they do to a player already mid-run
  under the old values.

## Test rigour

The reference for comment density and for testing behaviour rather than
implementation is **the best existing test file in the same module** — name it
in the review so the author can see what they were measured against. Once the
first well-tested module exists, name it here explicitly.

- **A test that passes against a broken implementation is worse than no test.**
  It costs maintenance and buys false confidence. Assume one is present until
  shown otherwise.
- **Non-vacuousness is proved by mutation, not by assertion.** Delete the
  mechanism the test guards, run the test, watch it fail. If it passes, the test
  is decoration. This is the single highest-value check in a review here.
- **Golden replays are the integration test of record.** A recorded input trace
  plus the expected end state catches the whole class of "it still runs but it
  plays differently" that no unit test reaches.
- **The simulation must be testable headless**, with no window, no GPU, and no
  audio device, at faster than real time. If it is not, the structural rule in
  `CLAUDE.md` has been broken somewhere and that is the finding.
- **Performance budgets are asserted in CI**, not checked by hand when someone
  remembers. A perf regression found six weeks later is found by bisecting.
- Fixtures behave like the real thing. A hand-trimmed asset that no longer
  matches what the pipeline actually produces tests your imagination.

## Platform certification

Even while this is PC-only, build to the constraint — retrofitting cert
compliance is a schedule risk that has sunk real ship dates.

Suspend and resume without losing state. Controller disconnection handled with a
pause and a clear message. User sign-out mid-session. Safe-area margins
respected. No UI within the title-unsafe region. Save-in-progress indication that
never lies, and no save write during a shutdown warning. Correct behaviour when
storage is removed.

## Verdicts

- **ACCEPT** — lands. Say it plainly. A reviewer that always finds something
  stops being read, and then the real blocker gets discounted too.
- **SEND BACK** — one or more BLOCKERs.
- **BLOCKER** — violates the bar above, or a structural rule in `CLAUDE.md`, or
  ships something the player would experience as a defect. Always a BLOCKER:
  corrupting a save, dropping an input, a hitch above 50 ms, a frame-rate-
  dependent simulation, a test that passes against a broken implementation, an
  asset off the canonical grid or off the palette, fractional scaling or
  sub-pixel positioning of pixel art, and an asset shipped without its
  provenance and licence recorded.
- **SHOULD-FIX** — real, not blocking. Carried into a task file **with the
  trigger that makes it due**, so it is scheduled rather than forgotten.
- **NIT** — taste. A round returning only NITs is a clean round; stop there.

Lead with **the single largest gap between what exists and what this bar asks
for**, before the ranked list. A list of fourteen findings hides its own
through-line, and the through-line is the thing worth fixing.
