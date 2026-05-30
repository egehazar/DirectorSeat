# Intelligent Cutting & Adaptive Coverage — Design Spec

**Type:** Design exploration. No feature code; this doc is the only artifact.
**Date:** 2026-05-30.
**Builds on:** `docs/editing-intelligence-investigation.md` (the coverage finding) and
`docs/v2-ideas.md` (multi-user collaboration infra).

**Concept (confirmed):** DirectorSeat will *generate coverage* — multiple angles of
the same dialogue beat — and the AssemblyEngine will *intercut* them to "cut to
whoever's talking." Capture adapts to the declared production size:

- **Solo / single phone:** coverage from a **combination** of (1) **crop-zoom** —
  film a wide two-shot, the engine digitally punches in to fake each speaker's
  close-up; and (2) **guided coverage shots** — the plan schedules a few extra angle
  inserts the solo user films as guided steps. **Continuity-reshoot (re-filming the
  whole scene from scratch, matching performance) is OUT** and not designed around.
- **Multi-phone:** when 2+ phones are declared (via the join-code multi-user system),
  the plan generates for **simultaneous** coverage — two cameras capture one beat at
  once. No continuity problem.

**Locked decision:** the **plan dictates coverage and speakers up front**. Each
coverage shot declares which lines it covers and who speaks. **The engine NEVER
detects speech or diarizes — it follows the plan's declared map.** Everything below
is designed around plan-declared coverage.

---

## 1. What exists today (grounded in the real code)

### 1.1 Plan generation — anti-coverage by design
`Services/PlanGenerationService.swift` (system prompt):
- **8-shot hard cap:** *"Maximum 8 shots total across all scenes"* (line 65). A
  4-line exchange in shot/reverse-shot is already 8 shots.
- **Two-shot bias, anti-reverse:** *"Prefer two-shots (both actors in one frame)
  over over-shoulder reverses. Over-shoulder should only be used when the user has
  confirmed a camera operator is available"* (lines 87–88).
- **One `speaker` per shot** in `dialogue_direction` (lines 31–38). No field links a
  shot to "the same beat, another angle."
- Two entry points: `generate(idea:…)` (free-form) and `generateFromTemplate(…)`
  (`buildTemplateSystemPrompt`, line 382), the latter serializing a `FilmTemplate` to
  JSON and forbidding structural change (*"Do NOT change the number of shots"*).

### 1.2 Templates — beat sequences, never coverage
`Models/FilmTemplate.swift`: each `TemplateShot` has one `shotType` + optional
`dialogueIntent{speaker}`. The three dialogue-heaviest (`FilmTemplate+Library.swift`)
— *The Argument* (6), *Piece to Camera* (4), *The Apology* (6) — are strictly linear
beat sequences. *The Apology*'s receiver CUs are **separate reaction beats in story
time** ("Close-up of [CHARACTER B] **listening**"), not simultaneous coverage of the
apologizer's lines. No template covers one beat from two angles.

### 1.3 Model — no coverage concept; "takes" are retries
`Models/FilmmakingPlan.swift`: `Shot` carries `shotNumber, shotType, directionText,
cameraPlacement, actorDirection, dialogueDirection(one speaker, one draft_line),
estimatedDurationSeconds, soloShootable, audioRisk, recommendedHoldSeconds,
transitionIn/OutType, pacingRole, audioTreatment, editingNote`. No
`coverageGroupId`/angle/role.
`ShootingModeViewModel`: `capturedTakes: [Int:[URL]]` are **retries of the identical
framing** (`shot_<n>_take_<k>_…`, line 199); `selectedTakes: [Int:URL]` collapses to
**one chosen clip per shot**.

### 1.4 Engine — strict 1:1:1, but transform-capable
- `TimelineBuilder.build()` (`AssemblyEngine/TimelineBuilder.swift`):
  `flattenShots(plan:)` (line 221) → one `SelectedTake` per `globalNumber`
  (`takesByGlobal`, line 23) → **exactly one `TimelineSegment` per shot, in order**
  (line 125). Already consumes `recommendedHoldSeconds` (trim, lines 47–62),
  transitions, `audioTreatment`, music cues.
- **`CompositionAssembler` already applies a per-segment transform** via
  `AVMutableVideoCompositionLayerInstruction.setTransform(_:at:)` (the
  `segmentTransforms` map + `layerInstructions`). `renderSize` is derived from the
  first segment's `naturalSize.applying(preferredTransform).abs()` (1080×1920
  portrait).
- `Exporter` exports composition + videoComposition with
  `AVAssetExportPresetHighestQuality`.
- **Capture is 1080p:** `CameraService.startSession()` sets
  `session.sessionPreset = .high` (≈1920×1080) on the back wide-angle camera.

### 1.5 The architectural keystone for this whole design
**Crop-zoom needs almost no new rendering infrastructure.** A punch-in is a
scale+translate `CGAffineTransform`, and `CompositionAssembler` *already* sets a
per-segment transform. And a coverage beat can be expressed as **multiple
`TimelineSegment`s that share one `sourceURL` (the wide take), each taking a
consecutive `sourceTimeRange` sub-slice with a different transform.** Because the
slices are consecutive sub-ranges of the *same* recording, **their audio
reconstructs the original continuous take, perfectly in sync, for free.** The intercut
is therefore a *visual* operation over one continuous audio bed — no audio editing,
no diarization, no new export pass. This is what makes solo coverage tractable.

---

## 2. Coverage data model

Design goals: (a) declare which lines a shot covers, the speaker, and the shot's
role; (b) link shots covering one beat; (c) **coexist with the linear model so the
engine supports BOTH** — absence of coverage = today's behavior, byte-for-byte.

### 2.1 Additive, optional — linear stays the default
All new fields are **optional**. A plan with no coverage decodes and assembles
exactly as today. Add to `Shot`:

```swift
let coverage: CoverageRole?     // nil ⇒ linear shot (current behavior)
```

```swift
/// Declares this shot's part in a multi-angle dialogue beat.
struct CoverageRole: Codable {
    let beatId: Int               // shots sharing a beatId cover the same dialogue
    let kind: CoverageKind
    let lineRuns: [LineRun]       // ordered speaker runs THIS shot's take contains
}

enum CoverageKind: String, Codable {
    case cropZoomSource    // a wide two-shot the engine punches into (solo)
    case separateAngle     // a physically distinct take (guided solo insert, or multi-phone)
}

/// One contiguous run of a single speaker within a take. No timestamps — the engine
/// places run boundaries proportionally over the take's real duration (§5).
struct LineRun: Codable {
    let speaker: String           // matches a cast role_name / dialogueDirection.speaker
    let lineText: String?
    let estimatedSeconds: Double  // relative weight for proportional placement
    let angle: CoverageAngle      // what to SHOW during this run
}

enum CoverageAngle: Codable {
    case wide                                   // show the source wide untouched
    case cropZoom(region: NormalizedRect)       // punch into the wide
    case separateAngle(shotGlobalNumber: Int)   // cut to another physical take
}

/// Normalized 0…1 rect in the source's DISPLAY space (post-preferredTransform).
struct NormalizedRect: Codable { let x, y, width, height: Double }
```

### 2.2 How beats link and how the engine stays bimodal
- Shots with the same `coverage.beatId` form one beat. For solo crop-zoom, a beat is
  often **a single `cropZoomSource` shot** whose `lineRuns` alternate `cropZoom(left)`
  / `cropZoom(right)` / `wide` — i.e. one physical take, many virtual angles.
- For guided/multi-phone, a beat is **several shots** (one `cropZoomSource` wide +
  one or more `separateAngle` takes); `lineRuns[].angle = .separateAngle(globalN)`
  points at them.
- **Bimodal engine rule:** in `flattenShots`, an entry with `coverage == nil` expands
  to **one** segment (today's path, untouched). An entry with `coverage != nil`
  expands to **N** segments via the §5 algorithm. This is the only structural change
  to `TimelineBuilder`, and it is additive.

### 2.3 Why not store timestamps
The locked decision forbids diarization, and the plan author cannot know real line
durations in advance. `estimatedSeconds` are **relative weights**, scaled onto the
take's actual `SelectedTake.duration` at build time (§5.3). A future precision
upgrade (tap-to-advance capture, §4.4) can populate real boundaries without changing
this schema.

---

## 3. Adaptive capture — solo

### 3.1 Crop-zoom (primary solo technique)
The user films **one wide two-shot** of the whole exchange, performed once. The
engine derives each speaker's CU by punching into a declared region. Benefits:
- **No re-performance** → respects the "no continuity-reshoot" rule.
- **Audio is the wide take's continuous track** → always in sync (§1.5).
- **180-degree rule is structurally impossible to violate** — both "angles" come from
  one physical camera, so eyelines/screen-direction are inherently consistent. This is
  a genuine advantage of crop-zoom over true two-camera coverage.

### 3.2 Resolution math (the quality ceiling) — capture MUST move to 4K
A believable CU crops to roughly half each linear dimension of the wide (≈¼ frame
area), then upscales to fill the 1080×1920 render:

| Capture | Wide native | ½-linear crop region | Upscale to 1080×1920 | Result |
|---|---|---|---|---|
| **`.high` (today, 1080p)** | 1080×1920 | 540×960 | **2× linear (¼ the pixels)** | visibly soft — **not acceptable** |
| **`.hd4K3840x2160` (portrait 2160×3840)** | 2160×3840 | 1080×1920 | **1.0× (native)** | **clean 1080p CU, no loss** |

**Conclusion: crop-zoom is only acceptable if capture moves to 4K.** This is a
`CameraService` change (`sessionPreset = .hd4K3840x2160`, device-capability-gated with
a 1080p fallback). At 4K, a 2× punch-in is *lossless* at the 1080p delivery target;
even a ~2.5× punch stays at/above 1080p. The plan must therefore (a) only schedule
crop-zoom when 4K capture is available, and (b) cap declared `cropZoom` regions so the
implied upscale never drops below 1080p (region width ≥ ~0.5 in 4K).

### 3.3 Framing guidance the plan MUST emit for crop-zoom to work
Crop-zoom fails silently if the wide isn't framed for it. The plan's
`camera_placement`/`actor_direction` for a `cropZoomSource` shot must instruct:
- **Both subjects fully inside a generous wide**, with headroom and space around each
  so a CU crop doesn't clip heads.
- **Portrait two-shot tension:** DirectorSeat renders portrait (1080×1920, tall/narrow),
  which is awkward for two side-by-side people. Guidance must place subjects so each
  occupies a **croppable portrait sub-region** — e.g. seated close at a table, or one
  slightly nearer/farther, so left-region and right-region crops each yield a
  plausible single-person portrait CU. (If subjects can't both be framed croppably,
  the plan should fall back to a real two-shot with no punch-in, or schedule a guided
  separate angle.)
- **Static phone, locked framing** for the whole take (already the app's norm) — crop
  regions are fixed rectangles, so the wide cannot reframe mid-take.

### 3.4 Guided coverage shots (secondary solo technique)
For beats where crop-zoom can't carry it (e.g. a reaction the wide doesn't capture
well, or an insert), the plan schedules a **small number** of extra `separateAngle`
shots as explicit guided steps ("Now film this: a close reaction of [B]…"). These are
**single-beat inserts / cutaways**, NOT a re-performance of the whole scene. Keep them
few (see §4) and continuity-light (an insert of an object, a held reaction) so a
beginner isn't asked to match a full performance. **180-rule caveat:** a guided
separate angle *can* cross the line; the plan must instruct phone placement on the
same side as the wide, and/or rely on J/L audio bridging (§5.4) to smooth it.

---

## 4. Plan generation for coverage + shot-budget analysis

### 4.1 The budget problem
The 8-shot cap was designed for linear films. Naïve coverage (cover every beat from
2–3 angles) blows it instantly and overwhelms a beginner with "film this angle" steps.

### 4.2 Reframe the budget: count PERFORMANCES, not segments
Crop-zoom decouples *segments* (what the engine cuts) from *performances* (what the
user films). One wide take → many virtual segments at **zero extra shooting cost**.
So the real beginner-facing budget is **number of physical takes to film**, not number
of timeline segments. Proposed budgets:

- **Linear films:** unchanged — ≤8 shots.
- **Solo coverage films:** **≤ ~6 physical takes**, of which **at most 1–2 are guided
  extra angles**; everything else is crop-zoom virtual coverage off wides. The
  *timeline* may contain 12–15 segments while the *user films ~6 times*.
- **Selective coverage (recommended):** **only the single most important dialogue
  beat gets full intercut coverage**; other beats stay linear. This is the
  beginner-fun ceiling — research and product instinct both say a beginner tolerates
  only a couple of "do it again, different angle" steps before it stops being fun.

### 4.3 Prompt/schema changes (gated to coverage mode)
- A new generation mode (`generateWithCoverage` or a `coverageEnabled` flag into the
  existing methods) that swaps in coverage-aware prompt sections:
  - Raise/replace the 8-shot rule with the **performance-budget** model (§4.2).
  - **Relax the anti-reverse / two-shot bias** specifically for coverage: now the
    wide two-shot is *desired* as a crop-zoom source, and the model is told to emit
    `coverage` metadata (beatId, lineRuns, crop regions) for the chosen beat.
  - Instruct the model to pick **one** dialogue beat to cover (the dramatic peak —
    e.g. *The Argument*'s "the real thing", *The Apology*'s reckoning) and leave the
    rest linear.
  - Emit crop-region guidance (§3.3) and 4K framing instructions.
- Templates: coverage can be expressed as new optional `TemplateShot.coverageIntent`
  so specific dialogue-heavy templates (*The Argument*, *The Apology*) opt their peak
  beat into coverage without restructuring the others. Additive; linear templates
  unaffected.

### 4.4 Timing precision (optional future upgrade, schema-compatible)
Per-line cut accuracy can be improved without diarization by capturing real line
boundaries during the shoot — e.g. a teleprompter/Performer-View-style capture (the
Performer View shipped 2026-05-30 is the natural host) that records advance
timestamps. This populates `LineRun` boundaries precisely. **Not required for V1** —
V1 uses proportional placement (§5.3).

---

## 5. The intercut algorithm (pure Layer-1, over declared metadata)

Lives in `TimelineBuilder` (no AVFoundation). Runs only for entries with `coverage`.

### 5.1 Inputs
The `cropZoomSource` shot's `SelectedTake` (URL + real `duration`), its
`coverage.lineRuns` (ordered, with `estimatedSeconds` weights and per-run `angle`),
any `separateAngle` takes referenced, plus existing `recommendedHoldSeconds`,
`pacingRole`, `audioTreatment`.

### 5.2 Output
A sequence of `TimelineSegment`s replacing the single segment the linear path would
emit — consecutive on the timeline, each with `sourceURL`, a `sourceTimeRange`
sub-slice, a `timelineTimeRange`, and (carried alongside) a crop transform for
`CompositionAssembler` to apply via the existing `setTransform` path.

### 5.3 Proportional placement (no diarization)
```
let T = selectedTake.duration                  // real take length
let W = sum(run.estimatedSeconds for run in lineRuns)
var cursor = .zero
for run in lineRuns:
    let frac = run.estimatedSeconds / W
    let runDur = T * frac                       // scale weights onto the real take
    let srcRange = CMTimeRange(start: cursor, duration: runDur)
    switch run.angle:
      case .wide:           emit segment(source: wideURL, src: srcRange, transform: identity-aligned)
      case .cropZoom(r):    emit segment(source: wideURL, src: srcRange, transform: cropTransform(r, renderSize))
      case .separateAngle(n): emit segment(source: take[n].URL, src: mappedRange, transform: aligned)
    cursor = cursor + runDur
```
Because crop-zoom slices are consecutive sub-ranges of the *same* wide URL, the
concatenated audio = the original continuous take (in sync, no seams).
`cropTransform` scales the normalized region up to fill `renderSize` and translates it
to origin — the same transform algebra `CompositionAssembler` already performs for
orientation.

### 5.4 Constraints honored / required
- **Minimum-shot-duration floor (the jitter problem).** Rapid dialogue → rapid
  punches → unwatchable strobing. Enforce a floor (propose **≥1.2s** per visual
  segment; tune on device). Runs shorter than the floor are **merged** with their
  neighbor (keep the wider/safer angle) rather than emitted as a micro-cut. This is a
  pure clamp in the loop above.
- **`recommendedHoldSeconds` / `pacingRole`:** the beat's total still respects the
  planned hold; `quick_beats` may lower the floor slightly, `slow_burn` raises it.
- **J/L cuts (smoothing, optional):** because audio is one continuous bed for
  crop-zoom, J/L behavior is automatic *within* a crop-zoom beat (audio never cuts).
  Across a `separateAngle` insert, an L-cut (let the wide's audio lead under the
  incoming angle) both smooths the edit and masks any 180-line softness — a known
  convention and a cheap win once basic intercut works.
- **180-degree rule:** N/A for crop-zoom (one camera); for `separateAngle`/multi-phone
  the plan must keep cameras one side of the axis (§3.4, §6).

### 5.5 Rendering (no new pass)
`CompositionAssembler` consumes the new multi-segment list exactly as it consumes
today's segments: allocate track(s), insert each `sourceTimeRange`, set each
segment's transform. Crop-zoom segments sit on one track (consecutive, contiguous —
satisfying the iOS-26 MediaValidator gap rule the engine already respects). Only when
a `separateAngle` overlaps/dissolves is a second track needed — the existing dissolve
two-track logic already covers that.

---

## 6. Multi-phone path — dependency & sequencing

Multi-phone simultaneous coverage requires the **multi-user collaboration infra from
`docs/v2-ideas.md`, which does not exist yet**: Neon Postgres for project/collab
metadata, blob store for audio/video, Apple Sign-In identity, 6-char join codes, and
clip upload/sync (the doc's "slate-clap sync" for aligning a second camera's media).

**Honest dependency:** multi-phone intercut is *blocked* on that infra. It cannot be
built until two devices can join a project, capture the same beat, and get both clips
+ a sync offset into one engine run. By contrast, **solo crop-zoom + guided coverage
needs none of it** — it runs entirely on one device with the current capture/engine.

**Recommended sequencing:** build the **solo path first** (data model + engine
intercut + crop-zoom). When multi-phone arrives, it **reuses the same coverage data
model and the same §5 intercut algorithm** — the only new inputs are (a) a second
physical take as a `separateAngle`, and (b) a sync offset to align it (which maps to
`sourceTimeRange.start`). So multi-phone is mostly *capture/sync plumbing on top of an
already-proven intercut engine*, plus the 180-rule framing guidance for two real
cameras. Do **not** design the collaboration infra here; this spec only maps the
dependency.

---

## 7. Isolation strategy — protect the just-stabilized engine

The linear AssemblyEngine was stabilized only on 2026-05-29/30 (orientation +
empty-audio fixes; `useAssemblyEngine` newly trusted `true`). Coverage must not
endanger it.

- **New flag mirroring the precedent:** add `FeatureFlags.useCoverageCutting`
  (default **false**). Linear assembly stays the default path. *(Design note only —
  this spec changes no flags.)*
- **Bimodal by construction:** coverage logic only runs for entries with
  `coverage != nil` AND the flag on. With the flag off, or on a plan with no coverage
  metadata, `TimelineBuilder`/`CompositionAssembler` take the **exact current code
  path**. No behavioral change to linear films.
- **Plan-gen gating:** coverage metadata is only emitted in coverage mode; existing
  `generate`/`generateFromTemplate` outputs are unchanged.
- **Capture gating:** the 4K preset change is capability-gated with a 1080p fallback,
  and only requested for coverage shoots, so existing 1080p linear capture is
  untouched.
- **Regression guard:** the linear path stays covered by the existing
  `RealFootageExportPipelineTests` (orientation/audio) and `TimelineBuilderTests`;
  add coverage tests in parallel without altering linear assertions. Every coverage
  phase ends by re-running the linear real-footage export to prove no regression.

---

## 8. Phased build plan — honest scope & risk

Riskiest/most-dependent parts last. Weeks are rough, single-developer.

| Phase | Scope | Weeks | Risk to working engine |
|---|---|---|---|
| **0. Capture → 4K** | `CameraService` preset `.hd4K3840x2160` + capability gate/fallback; verify on device | 0.5–1 | **Low** (capture only; linear export already orientation-agnostic, but re-validate fixtures at 4K) |
| **1. Coverage data model** | Optional `Shot.coverage` + `CoverageRole/LineRun/CoverageAngle/NormalizedRect`; Codable; absent ⇒ linear | 0.5–1 | **Very low** (additive, optional) |
| **2. Intercut in Layer 1** | `TimelineBuilder` bimodal expansion + §5 proportional placement + min-duration floor; **pure-data, unit-tested without footage** | 1.5–2.5 | **Low–moderate** (new code path, but gated; linear branch untouched) |
| **3. Crop-zoom render** | crop `CGAffineTransform` via existing `setTransform`; multi-segment-from-one-URL; real-footage export validation | 1.5–2.5 | **Moderate** (touches `CompositionAssembler` — the file we just fixed twice; mitigated by flag + regression export) |
| **4. Plan-gen coverage mode** | coverage prompt/schema, selective-coverage (one beat), crop-region + 4K framing guidance, shot-budget model; template `coverageIntent` | 2–3 | **Low** (engine untouched; risk is plan *quality*, tunable) |
| **5. Solo UX** | guided extra-angle steps in Shooting Mode; coverage review/adjust; (optional) Performer-View tap-to-advance timing | 2–3 | **Low–moderate** (Shooting Mode UI; capture path) |
| **6. Multi-phone** | **blocked on `v2-ideas.md` collab infra**; then reuse §2 model + §5 engine with a sync-offset `separateAngle` | infra (4–6+) **+** 2–3 | **High** (new networking/identity/sync subsystem; engine reuse is the easy part) |

**Total honest scope:**
- **Solo intelligent cutting (Phases 0–5): ~8–13 weeks**, single-developer, *if* the
  quality bar holds (crop-zoom believability at 4K, intercut timing tolerable with
  proportional placement). The **engine-risk concentration is Phase 3** (crop-zoom in
  `CompositionAssembler`); everything else is additive or gated.
- **Multi-phone (Phase 6): only after the collaboration infra exists** (itself a
  multi-week subsystem per `v2-ideas.md`), then ~2–3 weeks to layer onto the proven
  solo engine.

**Biggest risks, stated plainly:**
1. **Crop-zoom believability.** Even at 4K-lossless, a digital punch-in lacks the
   lens/parallax change of a real CU; portrait two-shots are framing-constrained
   (§3.3). It may read as "zoom," not "cut." *Mitigate:* selective use (peak beat
   only), tasteful punch counts, L-cut audio bridging — and an early on-device taste
   test before committing Phases 4–5.
2. **Timing without diarization.** Proportional placement (§5.3) drifts when the user
   paces lines unevenly; a punch can land mid-word. *Mitigate:* min-duration floor,
   keep covered beats short (few runs), and offer tap-to-advance (§4.4) as the
   precision upgrade.
3. **Re-touching `CompositionAssembler`.** It was the source of both recently-killed
   bugs. *Mitigate:* flag-gated bimodal path, linear branch literally unchanged,
   mandatory real-footage regression export each phase.
4. **Beginner fatigue (UX).** Even "1–2 guided angles" may erode the "never lost"
   promise. *Mitigate:* default to crop-zoom (zero extra shooting), make guided
   angles rare and optional, measure drop-off.

**Recommended build sequence (one line):**
**4K capture → coverage data model → Layer-1 intercut → crop-zoom render → plan-gen
coverage mode → solo UX → (later, after collab infra) multi-phone** — i.e. prove the
cut on declared metadata + crop transforms entirely solo and flag-gated, and treat
multi-phone as a capture/sync layer over the already-working engine.

---

## 9. Constraints honored
No feature code written. `AssemblyEngine`, `PlanGenerationService`, the models, and
`FeatureFlags` are unchanged (this is a doc). External grounding limited to standard
dialogue-editing conventions (shot/reverse-shot, the 180-degree rule, J/L cuts —
carried from the prior investigation) used only to inform what is realistically
automatable over *real* footage; no AI-video-generator research.
