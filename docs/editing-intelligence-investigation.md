# Editing Intelligence Investigation — Shot-Aware, Dialogue-Driven Cutting

**Type:** Read-and-analyze. No code changed; this doc is the only artifact.
**Date:** 2026-05-30.
**Question:** Can assembled films cut *intelligently* — to whoever's speaking, with
varied shot sizes and real pacing — instead of concatenating one take per planned
shot in linear order?

**Reference point:** Kling 3.0's "AI Director" makes editorial cut decisions
automatically. The critical difference: **Kling cuts among AI-generated shots
(infinite coverage on demand); DirectorSeat must cut among the real takes the user
actually filmed (finite — only the coverage they shot).** We are borrowing the idea
(AI makes editorial decisions), not generating any video.

---

## CENTRAL FINDING — Does DirectorSeat produce coverage?

**No. DirectorSeat plans exactly one linear, non-overlapping shot per story beat.
There is no coverage anywhere in the system — not in the plan, not in the templates,
not in the model, not in the engine. Every shot is a distinct moment in story time
with its own framing and (usually) its own single speaker. No two shots cover the
same dialogue from different angles such that an editor could choose between them or
intercut them.**

This is the constraint Kling never faces, and it is decisive for everything below.
The "AI director" idea presupposes alternatives to choose among. DirectorSeat's
material has none: each beat has exactly one angle. So editing intelligence over the
*current* material cannot mean *selecting* among shots — it can only mean
*presenting* a fixed cut-order more skillfully (trim, pace, audio). Selection-based
intelligence (Tier 2/3) requires first manufacturing the alternatives, which is the
epic.

Four independent lines of evidence, each conclusive:

### 1. Plan generation actively designs *against* coverage

`DirectorSeat/Services/PlanGenerationService.swift` — the system prompt makes
one-shot-per-beat a hard rule and coverage structurally impossible:

- **Shot budget kills coverage.** Line 65: *"Maximum 8 shots total across all
  scenes."* A single 4-line exchange in shot/reverse-shot is 8 shots for one beat.
  Coverage and an 8-shot film are mutually exclusive.
- **Framing bias is explicitly anti-coverage** (lines 87–88):
  > "When a shot does not have a designated camera operator … bias toward framings
  > that work from a static phone position. **Prefer two-shots (both actors in one
  > frame) over over-shoulder reverses.** Over-shoulder should only be used when the
  > user has confirmed a camera operator is available."

  The canonical coverage pattern (over-shoulder reverses) is the thing the prompt
  steers away from, by design, for solo-shootability.
- **The schema is one-beat-per-shot.** `dialogue_direction` carries a *single*
  `speaker` per shot (lines 31–38). There is no field expressing "this shot covers
  the same lines as that shot from another angle."
- **The prompt frames each shot as a unique narrative beat,** not redundant
  coverage: *"too many 'establishing' shots in a row is boring"* (line 118),
  *"Aim for variety: some dialogue-bearing shots, some silent ones"* (line 163).

### 2. The templates — even the most dialogue-heavy — are pure beat sequences

Each `TemplateShot` (`DirectorSeat/Models/FilmTemplate.swift:37`) has one `shotType`
and an optional `dialogueIntent` with one `speaker`. Reading the three most
dialogue-dense templates verbatim (`FilmTemplate+Library.swift`):

**The Argument (`the_argument`, 6 shots, lines 273–373).** Six *different moments*,
each its own line:
| Shot | Type | Speaker | Beat |
|---|---|---|---|
| 1 | wide | A | opens on the surface topic |
| 2 | medium | B | pushback, raises temperature |
| 3 | medium | A | escalation, surface cracks |
| 4 | close-up | B | the line that crosses into truth |
| 5 | medium | A | absorbs it / reaction |
| 6 | wide | — (silent) | aftermath |

Shot 4 (CU of B) and shot 5 (medium of A) are **sequential, different lines at
different times** — not the same exchange shot two ways. Nothing an editor could
intercut; they are already the intended cut order.

**Piece to Camera (`piece_to_camera`, 4 shots, lines 873–946).** One actor, four
beats — composed (medium) → crack (CU) → recovery (medium) → hold (CU). The
shot-size changes track the *emotional arc over time*, not two angles on one line.
This is the closest any template comes to "same subject, multiple sizes," yet it is
still strictly linear: each size belongs to a different moment of the monologue.

**The Apology (`the_apology`, 6 shots, lines 1030–1123).** The tempting case —
apologizer and receiver. But the receiver's CUs (shot 3 *"listening"*, shot 5
*"speaks"*) are **distinct beats in story time**, not simultaneous coverage of the
apologizer's shot-2/shot-4 lines. The template direction for shot 3 is *"Close-up of
[CHARACTER B] **listening**"* — a separate reaction beat the editor is meant to play
*after* shot 2, not an alternate angle on shot 2's delivery. There is no instruction
to film B's reaction *across the same time span* as A's apology.

**Verdict:** zero of the 14 templates produce coverage. Asymmetric beat design
(speech beat → reaction beat) is *not* coverage — coverage means the *same* dialogue
captured from ≥2 angles so a cut can fall anywhere in the line. No template does
this.

### 3. The model has no concept of coverage — and "multiple takes" ≠ coverage

`Shot` / `DialogueDirection` (`Models/FilmmakingPlan.swift`) record: `shotNumber`,
`shotType`, `directionText`, one `dialogueDirection.speaker`, one `draft_line`,
timing (`estimatedDurationSeconds`, `recommendedHoldSeconds`), and editorial
metadata. **There is no field linking two shots as covering one beat** — no
`coverageGroupId`, no `coversShot`, no angle/size pairing.

There *is* a multiple-clips-per-shot structure, and it is important not to mistake it
for coverage:
- `ShootingModeViewModel.capturedTakes: [Int: [URL]]` holds **many clips per shot** —
  but these are **retries of the identical shot** (`beginActualRecording()` names
  files `shot_<n>_take_<k>_…`, ViewModel line 199). Take 1, take 2, take 3 are the
  *same framing of the same beat*, reshot until satisfactory.
- `selectedTakes: [Int: URL]` collapses each shot to **exactly one chosen clip**.

Retakes are "do that line again, better." Coverage is "shoot that line *also* from
another angle." The app captures the former and has no representation for the latter.

### 4. The engine maps one selected take per shot, in plan order

`TimelineBuilder.build()` (`Services/AssemblyEngine/TimelineBuilder.swift`):
- `flattenShots(plan:)` (line 221) walks scenes→shots and assigns a 1-indexed
  `globalNumber`. Strictly linear.
- `takesByGlobal = Dictionary(uniqueKeysWithValues: takes.map { ($0.shotGlobalNumber, $0) })`
  (line 23) — **one `SelectedTake` per global shot number** (`SelectedTake.swift`
  has no notion of alternates).
- The build loop (line 41) emits **exactly one `TimelineSegment` per shot, in
  order** (line 125). There is no branch that chooses among alternates, no intercut,
  no speaker-driven re-ordering.

So the timeline is a 1:1:1 chain: plan shot *i* → selected take *i* → segment *i*.

---

## What the engine ALREADY does (the real baseline)

A crucial nuance the headline "concatenates one take per shot" undersells: the
assembled film is **not** a raw concatenation. The just-stabilized engine already
applies real editorial polish to that linear chain:

- **Hold trimming.** `TimelineBuilder` lines 47–62 trim each take to
  `recommendedHoldSeconds` (or cap at `defaultMaxHoldSeconds`). Beginners over-shoot;
  the cut is already tightened to the planned hold.
- **Transitions.** Dissolves are honored (`shouldDissolve`, line 239); boundary
  `fadeFromBlack`/`fadeToBlack` honored at film head/tail (lines 137–167);
  mid-timeline fades and `match_cut` are deliberately downgraded to cuts with
  diagnostics.
- **Audio treatment + boundary ramps.** `audioTreatment` per shot drives
  video/music volume curves, with smoothing ramps inserted at level changes
  (`volumeCurves`, `insertBoundaryRamps`, lines 243–325).
- **Music regions.** `musicCueIn`/`musicCueOut` produce faded music spans
  (`buildMusicRegions`, line 327).

So today's output is: **trimmed, audio-mixed, transition-aware, music-cued —
linear.** The gap is not "no editing"; it's "no *shot-to-shot* intelligence."

---

## Three-tier scope analysis

### Tier 1 — Editing intelligence needing NO coverage *(the V1-plausible tier)*

Works on the single linear take per shot that already exists. Sub-divided by what's
done, cheap, or risky:

**(1a) Already shipped.** Hold-trimming, transition honoring, audio ducking, music
fades (above). State plainly: the baseline already clears "raw concatenation."

**(1b) Cheap win — wire up planned-but-ignored pacing data.** The LLM already emits
`pacing_role` per shot and `pacing_profile` per scene, and the prompt *claims*
*"The engine uses this to ensure pacing variety"* (PlanGenerationService line 118) —
**but the engine never reads either field.** `TimelineBuilder` consumes only
`recommendedHoldSeconds`, `audioTreatment`, transitions, and music cues. Closing
this gap is pure Layer-1 arithmetic on data already present: e.g. `rising_tension`
shortens successive holds; `quick_beats` caps holds at ~3s; `slow_burn` lets closure
holds breathe. **No planning, shooting, model, or AVFoundation changes.** Scope:
~1–3 days, confined to the pure-data `TimelineBuilder`, fully unit-testable without
footage.

**(1c) Medium win — auto-trim dead air (leading/trailing silence).** Today the hold
is a *plan estimate*; the engine doesn't know where speech actually starts/ends in
the recorded take. Trimming leading/trailing silence per take (Voice Activity
Detection via audio-energy thresholds — the same core technique behind Descript /
Auto-Editor / Premiere's silence removal) tightens cuts to the actual performance.
Scope: new audio-analysis helper reading sample buffers; per-take, does **not**
change cut *structure* (still one segment per shot). ~1–2 weeks. Moderate risk: new
code path, but it only adjusts each segment's `sourceTimeRange` — the riskiest engine
surfaces (track layout, render size, export) are untouched.

**(1d) Highest "feels like a movie" payoff, highest risk — J/L cuts.** Letting audio
lead (J) or lag (L) across a cut is *the* technique that makes dialogue cutting feel
professional (confirmed as foundational continuity editing). The audio track is
already separate from video in the composition, so the data model can express it —
but it requires the audio segment to stop being co-terminous with its video segment,
which is **net-new timing logic in an engine stabilized only days ago** (the
orientation + empty-audio-track fixes). It also interacts with the iOS-26
MediaValidator track-contiguity constraints the engine works hard to satisfy.

**Tier 1 honest read:** real and the only V1-plausible tier. **(1b) is the safe,
high-confidence V1 win** — it activates intelligence the plan already describes, in
the pure data layer, with no footage dependency and near-zero regression surface.
(1c) is a credible fast-follow. (1d) is genuinely the biggest perceptual upgrade but
should wait until the engine has more hardware-validated mileage — it is the one
Tier-1 item that can reintroduce the class of bug we just spent three sessions
killing.

### Tier 2 — Full intercut, IF coverage already existed

The algorithm: per dialogue beat, cut to the active speaker via
`dialogueDirection.speaker`, intercut reaction shots, vary shot sizes, respect the
180-degree rule and pacing. **This is moot today: coverage does not exist, so there
is nothing to intercut** (Central Finding). It is blocked on Tier 3's planning +
shooting changes.

Even granting coverage, Tier 2 is **not small**, because cutting "to whoever's
speaking" requires knowing *when* each person speaks *within* each take — i.e.
speech-timing with speaker attribution (transcription/diarization or VAD aligned to
the planned `speaker`). That is a substantial analysis subsystem on top of the
intercut logic itself. Rough scope *assuming coverage and timing metadata exist*:
2–4 weeks for the selection/intercut layer in `TimelineBuilder` + `CompositionAssembler`
(it would move from 1 segment/shot to N candidate segments with a chooser). Without
the timing subsystem it cannot actually find the speaker. Realistic total once
unblocked: **6+ weeks**, and it meaningfully expands the engine's responsibility.

### Tier 3 — The epic, since coverage does NOT exist

To get speaker-driven intercutting for real, all three of these must be built:

1. **Plan generation must produce coverage.** Rewrite the prompt/schema to emit
   multiple angles per beat and a grouping (`coverageGroupId`). This directly
   collides with the 8-shot budget (line 65) and the deliberate two-shot/anti-reverse
   bias (lines 87–88). Coverage for even a short scene multiplies shot count 2–3×.

2. **A shooting flow that gets *beginners* to film multiple angles of one scene
   without confusion.** This is the real killer, and it fights the product's spine
   (CLAUDE.md: *"the user should feel guided, never lost… beginner-first… when in
   doubt, simplify"*). Coverage demands: reposition the phone for each angle,
   **re-perform the identical lines** take after take, and hold continuity
   (eyeline, wardrobe, props, the 180-degree line) across angles so the cuts
   actually match. Asking a solo beginner with no operator to re-perform a scene 3×
   from 3 positions and keep it matchable is precisely the "lost and overwhelmed"
   experience Shooting Mode exists to prevent. It also breaks solo-shootability
   (over-shoulder reverses need a second person — the prompt already says so).

3. **Intercut + speech-timing logic in the engine** — all of Tier 2, plus the
   coverage-aware selection.

**Blunt verdict: Tier 3 is not a contained feature — it is a multi-system epic that
touches every layer (prompt, schema, templates, Shooting-Mode UX, the engine) *and*
adds a new speech-analysis subsystem, while pushing against the app's core
constraints (beginner-first, solo, household, ≤8 shots).** It is closer to a product
pivot than a feature. The Kling analogy breaks exactly here: Kling sidesteps the
shooting-UX problem entirely by *generating* coverage; DirectorSeat would have to
*extract* it from a confused beginner. That is the hardest problem in the whole
space and it is a *human/UX* problem, not an algorithm problem.

---

## V1-vs-V2 recommendation per tier

Weighing **risk to the just-stabilized AssemblyEngine** (orientation + empty-audio
fixes landed 2026-05-29/30, `useAssemblyEngine` only now trusted `true`) and
**time-to-launch**:

| Tier | Item | Risk to engine | Verdict |
|---|---|---|---|
| 1a | trim/transition/audio (done) | none | **shipped** |
| **1b** | **consume `pacing_role`/`pacing_profile`** | **very low (pure Layer 1)** | **V1 — safely shippable** |
| 1c | auto-trim dead air (VAD) | low–moderate | V1 fast-follow (post-launch) |
| 1d | J/L cuts | moderate–high | V1.x, only after more hardware mileage |
| 2 | speaker-driven intercut | high (engine scope ↑) + blocked | **V2 — blocked on Tier 3** |
| 3 | coverage plan+shoot+intercut | very high (all layers) | **V2+ / not V1 — epic** |

**The only safely V1-shippable item is Tier 1b** (activate the pacing metadata the
plan already produces). Tier 1c is a strong, contained fast-follow. Everything that
*sounds* like "Kling for your real footage" (Tiers 2–3) is gated behind a beginner
coverage-shooting UX that contradicts the product's reason for existing — defer.

---

## Recommended next step

**Ship Tier 1b for V1:** make `TimelineBuilder` consume `pacing_role` (per shot) and
`pacing_profile` (per scene) to modulate hold durations, honoring the contract the
system prompt already advertises. Concretely:
- Pure-data change confined to `TimelineBuilder` (Layer 1); no AVFoundation, no
  Shooting-Mode, no plan-generation, no `FeatureFlags` changes.
- Behind a small internal toggle, validated with `TimelineBuilder` unit tests (no
  footage needed) plus one real-footage export through `RealFootageExportPipelineTests`
  to confirm no regression to the orientation/audio fixes.
- Deliverable a beginner can feel: a `rising_tension` scene visibly accelerates; a
  `slow_burn` ending visibly breathes — "edited like a film" from material that
  already exists.

Hold Tiers 2–3 for a dedicated V2 exploration that leads with the **coverage-shooting
UX problem** (can a beginner be guided to shoot matchable coverage at all?) before
any engine work — because if that UX can't be solved, the intercut engine has nothing
to cut.

---

## Constraints honored

No feature code written. `AssemblyEngine`, plan generation, and `FeatureFlags`
untouched. External grounding limited to two searches on dialogue-coverage
conventions (shot/reverse-shot, 180-degree rule, J/L cuts) and automatic
silence/speech-based editing (VAD; Descript/Auto-Editor/Premiere), used only to
inform what is realistically automatable over *real* footage. No research into AI
video generators.
