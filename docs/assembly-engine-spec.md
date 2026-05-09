# Assembly Engine — V1 Architecture Spec

## Problem

The plan generation system produces sophisticated editorial decisions: hold durations per shot, transition types between shots, pacing roles, audio treatments, scene-level pacing profiles, music cues. The current `VideoAssemblyService` ignores all of it. It selects takes, concatenates them end-to-end, and exports. The editorial metadata is theatrical — present in the data, invisible on the screen.

This is the largest remaining gap in the product. The AI generates films that *should* breathe, modulate volume, dissolve at the right moment, fade in over a held music swell — and then delivers a brick of cuts at full source volume. The user's experience of the AI's intelligence is gated almost entirely by what the assembly engine actually does with the plan.

This spec defines V1 of the assembly engine that closes that gap.

## Goals

- Honor every editorial metadata field that's currently generated: `recommendedHoldSeconds`, `transitionInType`, `transitionOutType`, `audioTreatment`, `musicCueIn`, `musicCueOut`
- Stay backward-compatible with legacy plans that have no editorial metadata (graceful defaults)
- Produce output that's measurably better than current naive concatenation on identical source takes
- Be testable without hardware (the planning logic should be a pure function)
- Drop-in replace `VideoAssemblyService` at the same call site

## Non-goals (V1)

- Slow motion, time remapping, speed ramps
- Color grading (already a separate post-pass)
- Auto-syncing dialogue, audio normalization, loudness matching
- Multi-track music, per-shot music swaps
- B-roll insert / cutaway timeline patterns
- Smart trim (finding the action moment within an over-long take) — V1 trims from the end
- Match cut visual matching — treated as a hard cut at the AVFoundation layer; the editorial intent lives in shot composition
- Music library itself (this engine accepts an optional music URL; library curation is separate work)

## Inputs and outputs

The public surface is a single async function:

```swift
final class AssemblyEngine {
    func assemble(
        plan: FilmmakingPlan,
        takes: [SelectedTake],
        musicURL: URL?,
        outputURL: URL,
        progress: @escaping (Float) -> Void
    ) async throws -> URL
}
```

`SelectedTake` already exists — it associates a shot's global number with the file URL of the chosen take. The engine returns the output URL on success and throws a typed error on failure.

The watermark pass and title card pass remain separate. They run on the output of this engine, not within it. Keep the assembly engine's job narrow: editorial decisions to a single .mov.

## Architecture: three layers

The biggest mistake would be to write the editorial logic inline against `AVMutableComposition`. AVFoundation is gnarly, hard to debug, and impossible to test without a video pipeline. So the engine is split into three sequential layers, each pure and testable on its own:

**Layer 1 — Timeline planning.** Pure-data transformation: `(plan, takes) → EditorialTimeline`. No AVFoundation. Decides what goes where on the timeline, what overlaps with what, what audio levels apply when. Fully unit-testable in the simulator. This is where 80% of the editorial intelligence lives.

**Layer 2 — Composition assembly.** Mechanical translation: `EditorialTimeline → (AVMutableComposition, AVMutableVideoComposition, AVMutableAudioMix)`. No editorial decisions made here — just turning the timeline plan into AVFoundation objects. Deterministic, easy to debug.

**Layer 3 — Export.** Hands the composition to `AVAssetExportSession`, reports progress, returns the output URL. Thin wrapper. The hard work is already done.

The reason this separation matters: when something looks wrong in the final film, you can dump the EditorialTimeline as JSON and inspect it. If the timeline is right but the output is wrong, the bug is in Layer 2 or 3 (AVFoundation issues). If the timeline is wrong, the bug is in Layer 1 (editorial logic). This separation has saved every video pipeline I've ever seen built well.

## Data structures (Layer 1 output)

```swift
struct EditorialTimeline {
    let segments: [TimelineSegment]
    let transitions: [TimelineTransition]
    let audioRegions: [AudioRegion]
    let musicRegions: [MusicRegion]
    let totalDuration: CMTime
}

struct TimelineSegment {
    let shotGlobalNumber: Int
    let sourceURL: URL
    let sourceTimeRange: CMTimeRange   // what slice of the take to use
    let timelineTimeRange: CMTimeRange // where in the final film it lives
    let trackIndex: Int                // 0 or 1 — alternating for transition support
}

struct TimelineTransition {
    enum Kind { case crossfade, fadeToBlack, fadeFromBlack }
    let kind: Kind
    let duration: CMTime
    let timeRange: CMTimeRange         // where in final timeline the transition happens
    let outgoingSegmentIndex: Int?     // nil for fadeFromBlack at film start
    let incomingSegmentIndex: Int?     // nil for fadeToBlack at film end
}

struct AudioRegion {
    let timeRange: CMTimeRange
    let videoVolume: VolumeCurve
    let musicVolume: VolumeCurve
}

enum VolumeCurve {
    case constant(Float)                       // 0.0–1.0
    case ramp(from: Float, to: Float)          // for crescendo, boundary crossfades
}

struct MusicRegion {
    let timeRange: CMTimeRange
    let fadeInDuration: CMTime
    let fadeOutDuration: CMTime
}
```

A few design notes worth flagging:

`trackIndex` exists because dissolves require the outgoing and incoming clips to be visible simultaneously, which means they have to be on different AVFoundation video tracks (you can't overlap clips on a single track). The simplest model is to always alternate: segment 0 → track 0, segment 1 → track 1, segment 2 → track 0, and so on. This means cuts between adjacent segments work fine (one track ends, the other starts at the same instant on the timeline), and dissolves work fine (both tracks are visible during the overlap window). The minor cost is a marginally larger composition graph; for 6-12 shot films this is irrelevant.

`MusicRegion` deliberately does *not* carry the music URL — the URL lives once on the engine call. This is V1's single-music-track-per-film constraint encoded in the type system.

`VolumeCurve` is a value type that supports both flat levels and linear ramps. AVFoundation supports more complex audio shaping (multi-segment ramps, automation curves) but for V1 a flat-or-linear-ramp model covers every audio treatment in the editorial vocabulary.

## Algorithm: plan to timeline

Walk the plan's scenes in order, then shots within each scene. Maintain a running `currentTimelineTime` cursor. For each shot:

**Determine source range.** Read `shot.recommendedHoldSeconds`. If nil, default to the asset's natural duration capped at 6 seconds (a reasonable maximum for a single shot in a short film). If the asset is shorter than the recommended hold, use the full asset and emit a warning to the engine's diagnostic log — don't try to slow-mo or freeze-frame in V1. If the asset is longer, trim from the *end*: keep the start because the start is where the action begins. The source time range is `CMTimeRange(start: .zero, duration: holdDuration)`.

**Determine timeline range.** This depends on the relationship to the previous shot. If the previous shot's `transitionOutType` indicates an overlap-style transition (`dissolve`), or this shot's `transitionInType` does, then the new segment starts `crossfadeDuration` (default 0.7s) before the previous segment ends. Otherwise it starts exactly when the previous segment ends. If transition specs from adjacent shots conflict (e.g., previous says `dissolve`, this says `cut`), prefer the more expressive one (`dissolve` wins) — that's the editorial intent talking.

**Append the segment.** Track index is `(segments.count) % 2`. The segment is added to `segments`.

**Append the transition (if any).** If there's an overlap with the previous shot, append a `TimelineTransition` of kind `.crossfade` covering the overlap window. If the *first* shot has `transitionInType == .fadeFromBlack`, prepend a `TimelineTransition` of kind `.fadeFromBlack` at the film start (default 1.0s). If the *last* shot has `transitionOutType == .fadeToBlack`, append one of kind `.fadeToBlack` at the film end. (Don't insert a fade-to-black on every film by default — only when the editorial layer specifies it. Many short films should end on a hard cut.)

**Skip transitions that don't fit.** If a transition's duration is longer than the shorter of its two adjacent segments, skip the transition and force a cut. Log it. A 0.7s dissolve into a 0.5s shot looks worse than no dissolve at all.

**Build audio regions.** For each segment, look at `shot.audioTreatment` and map to volume settings:

| Treatment | videoVolume | musicVolume |
|---|---|---|
| `dialogue_priority` | constant(1.0) | constant(0.25) |
| `music_priority` | constant(0.30) | constant(1.0) |
| `ambient_only` | constant(1.0) | constant(0.0) |
| `silent` | constant(0.0) | constant(0.0) |
| `crescendo` | constant(1.0) | ramp(from: 0.30, to: 1.0) |

Audio at hard cut boundaries pops audibly when adjacent regions have different levels. Insert a 50ms `ramp` audio region at every boundary between two regions with different settings, ramping each track from the outgoing level to the incoming level. This is craft — not specified by the editorial layer, but cheap insurance against amateur-sounding audio.

**Build music regions.** Walk scenes. When a scene's `musicCueIn == true`, open a music region at the start of that scene's first segment's timeline time. When a scene's `musicCueOut == true`, close it at the end of that scene's last segment. If a film has no `musicCueIn` anywhere, there are no music regions and the engine produces a music-free output. Default fade-in/fade-out durations are 1.5s — short enough to feel intentional, long enough to avoid abrupt music starts.

**Defaults for legacy plans.** If a shot has no editorial metadata at all, treat it as: full take, cut transition both ends, dialogue_priority audio. This produces output identical to the current naive concatenation, ensuring backward compatibility with films generated before the editorial layer existed.

## Algorithm: timeline to AVFoundation

This layer is mechanical. The timeline already encodes every decision; the work is just translation.

**Composition setup.** Create `AVMutableComposition`. Add two `AVMutableCompositionTrack` instances of type `.video` (track A and track B), and two of type `.audio` (the source-audio track for the takes, and the music track if `musicURL != nil`).

**Insert video and source-audio segments.** For each `TimelineSegment`, load the source asset's video track and audio track and insert them into the composition's track at index `segment.trackIndex` (video) and the single source-audio track (audio), at `timelineTimeRange.start`, using `sourceTimeRange` as the source slice. Standard `insertTimeRange(_:of:at:)` calls.

**Insert music asset.** If `musicURL` is non-nil and `musicRegions` is non-empty, load the music asset. For each `MusicRegion`, insert the music asset's audio track into the composition's music track. Music asset is reused across regions (same source, multiple insertion points).

**Build video composition instructions.** This is the trickiest part of Layer 2 and worth describing carefully.

Walk the timeline in time order. At any given moment, the timeline is in one of two states: a "stable" period where exactly one video track is contributing, or a "transition" period where both are.

For each contiguous stable period, emit one `AVMutableVideoCompositionInstruction` covering that time range, with one `AVMutableVideoCompositionLayerInstruction` per active track at constant opacity 1.0 (the active track) and 0.0 (the inactive track).

For each `TimelineTransition` of kind `.crossfade`, emit one instruction covering the transition's time range, with two layer instructions: outgoing track ramps opacity from 1.0 to 0.0 over the transition duration, incoming track ramps from 0.0 to 1.0. Use `setOpacityRamp(fromStartOpacity:toEndOpacity:timeRange:)`.

For `.fadeToBlack`: one instruction over the fade range, single layer instruction ramping the outgoing track from 1.0 to 0.0. AVFoundation's default background is black, so opacity-to-zero produces fade-to-black for free.

For `.fadeFromBlack`: same pattern, ramping from 0.0 to 1.0 on the incoming track.

Set `videoComposition.frameDuration = CMTime(value: 1, timescale: 30)` (30fps), and `videoComposition.renderSize` to match the source assets' dimensions. (For V1 assume all source takes have identical dimensions — they do, because they came from the same camera. Add a guard that throws if they don't.)

**Build audio mix.** Create one `AVMutableAudioMixInputParameters` per audio track (source-audio and music). For each `AudioRegion`, apply the volume settings to each parameters object using `setVolume(_:at:)` for constants and `setVolumeRamp(fromStartVolume:toEndVolume:timeRange:)` for ramps. AVFoundation handles the interpolation.

## Algorithm: export

`AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)`. Set `videoComposition`, `audioMix`, `outputURL`, `outputFileType = .mov`. Start export with `export(to:as:)` (the modern async/await variant). Poll `progress` and forward to the caller's progress closure. On completion, return the output URL. On failure, throw a typed error wrapping the underlying AVFoundation error.

## Edge cases (exhaustive)

**Source take is shorter than recommended hold.** Use full take. Emit warning to diagnostic log. Don't extend artificially.

**Source take is much longer than hold.** Trim from end, preserve start. (Future: smart trim using audio onset detection or motion analysis. Not V1.)

**Source take has corrupt or missing audio track.** Continue with silent audio region for that segment. Don't fail the export.

**Source file is missing entirely.** Throw `AssemblyError.missingSourceFile(shotGlobalNumber:)` *before* starting export. Pre-flight all source URLs in Layer 1 so this fails fast.

**Source files have inconsistent dimensions.** Throw `AssemblyError.inconsistentSourceDimensions`. V1 doesn't handle multi-resolution composition.

**Plan has zero shots.** Throw `AssemblyError.emptyPlan`.

**Plan has only one shot.** No transitions possible. Single segment, single audio region. Should still work — verify with a unit test.

**Editorial metadata fields are missing.** Defaults documented above (full take, cut, dialogue_priority). Backward compatible with legacy plans.

**Transition duration > shorter clip duration.** Skip transition, force cut, log warning.

**`musicCueIn` set but `musicURL` is nil.** Music regions still appear in the timeline (so debugging tools can see the intent), but the export simply doesn't include a music track. No error. This is the expected state until the music library exists.

**Two consecutive shots both specify dissolves.** Single dissolve between them at the boundary, not a dissolve-into-dissolve. Idempotent.

**The `editingNote` field.** Not consumed by V1. Reserved for a future "human review" mode that surfaces editorial notes alongside the assembly.

**Watermark and title cards.** Out of scope for this engine. The free-tier watermark and director-name title card are applied by separate post-passes on the engine's output. Don't merge them in.

## Test plan

Layer 1 tests are pure-Swift unit tests that run in seconds with no AVFoundation:

A 3-shot all-cuts plan with full-take holds produces 3 segments with no transitions, contiguous time ranges starting at zero. A plan with one dissolve between shots 2 and 3 produces a timeline with a 0.7s overlap region and one TimelineTransition of kind `.crossfade`. A plan where shot 2's hold is 3.0s but the take is 5.0s produces a segment with `sourceTimeRange.duration == 3.0s` and `timelineTimeRange.duration == 3.0s`. A plan where shot 2's hold is 3.0s but the take is 1.5s produces a segment with `sourceTimeRange.duration == 1.5s`, `timelineTimeRange.duration == 1.5s`, and an emitted warning. A plan that alternates `dialogue_priority` and `music_priority` produces audio regions with the correct volumes and 50ms ramp regions at every boundary. A legacy plan with no editorial metadata produces output equivalent to the current naive concatenation. A plan with musicCueIn on scene 2 and musicCueOut on scene 3 produces one MusicRegion spanning scenes 2-3.

Layer 2 and 3 tests require either simulator or hardware:

Assemble a 3-shot all-cuts film and verify it plays end-to-end with no glitches. Assemble a 3-shot film with one dissolve and visually confirm the crossfade at the right moment. Assemble a film with `transitionOutType == .fadeToBlack` on the last shot and verify the fade. Assemble a film with mixed audio treatments and verify audible volume differences using a recorded waveform inspection. Assemble a film with music cues and verify music fades in/out at scene boundaries. Assemble a legacy plan and bit-compare against `VideoAssemblyService`'s output (should be functionally identical except for the 50ms audio crossfades, which are an improvement either way).

Run all tests on simulator first, then verify on real iPhone before flipping the migration flag.

## Performance

`AVAssetExportSession` with editorial complexity (transitions, audio mix, two video tracks) runs roughly 10-30% slower than naive concatenation. For a typical 6-8 shot, 30-90 second film on an A15 or newer chip, expect 2-6 second export times. This is acceptable.

Memory footprint roughly doubles vs single-track composition because both video tracks hold references to source assets during the overlap windows. For 6-12 shot films this is well within bounds. For 30+ shot films this would matter — but V1's expected films are short.

Pre-validate every source URL exists in Layer 1 before starting export. Failing midway through a 4-second export with "missing file" wastes the user's time; failing in 50ms before export starts is forgivable.

## Migration

The current `VideoAssemblyService` is invoked at one place: the post-production assembly step. The new `AssemblyEngine` is a drop-in replacement at that call site.

Don't delete `VideoAssemblyService` yet. Add a feature flag `useAssemblyEngine: Bool` that defaults to `true` for new builds but can be flipped off at runtime via Settings (or a debug menu) for fallback. After two weeks of real use across several film types with no regressions, delete the old service in a single commit.

## Open questions Ege should decide

**Default transition duration.** I've specified 0.7s for crossfades, 1.0s for fade-from-black at film start, 1.0s for fade-to-black at film end. These are reasonable cinematic defaults. If the editorial layer should specify per-transition durations explicitly, we'd extend the data model. For V1 I'd keep them as engine constants and let the editorial vocabulary stay simple.

**Audio level constants.** The dialogue/music balance values (1.0 / 0.25 for dialogue priority, 0.30 / 1.0 for music priority) are reasonable starting points. They're tunable. After hearing actual assembled output, we'll likely adjust by a few hundredths in either direction. This isn't worth solving in advance — set them as named constants and tune after first hardware test.

**Match cut handling.** Currently treated as a hard cut at the AVFoundation layer. The "match" intent affects shot composition (already happens at plan generation). Is that enough? I think yes for V1 — match cuts are about visual continuity, not transition mechanics. Defer.

**Should the engine support per-segment crossfade durations?** Editorial intent might want a 0.3s blink-cut feel vs a 1.5s slow dissolve. V1 says no — single duration. If users start asking, extend the data model.

**Single-shot films.** A 1-shot film has no transitions to speak of. The engine should handle it correctly (and the test plan covers it), but worth flagging that the editorial value-add is much lower for these. Most of the engine's improvement is at boundaries.

## What this delivers

When this engine ships, the same plan that today produces a brick of cuts at full source volume will produce a film where:

- Establishing shots breathe for the time the editorial layer specified, payoff shots hold longer than transition shots
- Dissolves appear where the AI judged the emotional moment called for one (maybe 1-2 per film, not many — the editorial system's default is cut at ~80%)
- Music swells in at scene 2 over a held wide shot, ducks during the dialogue-heavy beat in scene 3, and fades out under the closing image
- A sad film fades to black at the end if the AI chose that; a comedic one ends on a hard cut
- Audio doesn't pop at boundaries because of the boundary crossfades

The user doesn't need to understand any of this. They write an idea, accept the plan, shoot the takes, and the film comes out feeling like someone with editorial taste assembled it. That's the actual product DirectorSeat has been promising. Right now we're delivering the planning and not the execution. This engine closes that.

## When iPhone is back

This spec is detailed enough to hand to Claude Code as a build prompt with minor framing additions: "Build the assembly engine described in this spec. Start with Layer 1 (TimelineBuilder) and its unit tests. Validate Layer 1 thoroughly before touching Layer 2. Use the migration flag to keep VideoAssemblyService as a fallback during initial validation."

Build order: Layer 1 + its unit tests → Layer 2 (composition assembly) on simulator → Layer 3 (export) on simulator → real iPhone integration test → migration flag flipped on. Estimated 1-2 days of focused work end to end.
