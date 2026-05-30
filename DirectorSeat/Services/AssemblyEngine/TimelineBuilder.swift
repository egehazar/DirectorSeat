import CoreMedia
import Foundation

/// Layer 1 of the assembly engine. Pure-data transformation:
/// `(FilmmakingPlan, [SelectedTake]) -> EditorialTimeline`. No AVFoundation.
///
/// The timeline encodes every editorial decision (source slices, overlaps,
/// transitions, audio levels, music regions, fades). Layer 2 mechanically
/// translates this plan into AVFoundation objects.
struct TimelineBuilder {

    func build(
        plan: FilmmakingPlan,
        takes: [SelectedTake],
        hasMusicURL: Bool
    ) throws -> EditorialTimeline {

        let orderedShots = Self.flattenShots(plan: plan)
        guard !orderedShots.isEmpty else {
            throw AssemblyError.emptyPlan
        }

        let takesByGlobal = Dictionary(uniqueKeysWithValues: takes.map { ($0.shotGlobalNumber, $0) })

        var diagnostics: [AssemblyDiagnostic] = []

        for entry in orderedShots {
            guard let take = takesByGlobal[entry.globalNumber] else {
                throw AssemblyError.missingTakeForShot(shotGlobalNumber: entry.globalNumber)
            }
            guard FileManager.default.fileExists(atPath: take.sourceURL.path) else {
                throw AssemblyError.missingSourceFile(shotGlobalNumber: entry.globalNumber)
            }
        }

        var segments: [TimelineSegment] = []
        var transitions: [TimelineTransition] = []
        var currentTimelineTime = CMTime.zero
        var lastTrackIndex = 0  // segment 0 starts on track 0

        for (i, entry) in orderedShots.enumerated() {
            // Coverage MEMBER shots (separate angles referenced by a cropZoomSource
            // driver via .separateAngle(globalShotNumber:)) are pulled into the
            // driver's beat; they emit no standalone segment. A driver shot
            // (cropZoomSource) and linear shots (coverage == nil) fall through.
            if entry.shot.coverage?.kind == .separateAngle { continue }

            let take = takesByGlobal[entry.globalNumber]!
            let assetDuration = take.duration

            // ---- Source range
            let sourceDuration: CMTime
            if let recommended = entry.shot.recommendedHoldSeconds {
                let recommendedTime = CMTime.seconds(recommended)
                if assetDuration < recommendedTime {
                    sourceDuration = assetDuration
                    diagnostics.append(AssemblyDiagnostic(
                        severity: .warning,
                        shotGlobalNumber: entry.globalNumber,
                        message: "Take is shorter than recommendedHoldSeconds (\(recommended)s); using full take of \(assetDuration.seconds.rounded(toPlaces: 3))s."
                    ))
                } else {
                    sourceDuration = recommendedTime
                }
            } else {
                let cap = CMTime.seconds(AssemblyConstants.defaultMaxHoldSeconds)
                sourceDuration = assetDuration < cap ? assetDuration : cap
            }
            let sourceTimeRange = CMTimeRange(start: .zero, duration: sourceDuration)

            // ---- Timeline range + transition decision
            var timelineStart = currentTimelineTime
            var transitionToAppend: TimelineTransition?
            var dissolvedFromPrevious = false
            if i > 0, !segments.isEmpty, Self.shouldDissolve(prev: orderedShots[i - 1].shot, curr: entry.shot) {
                let crossfade = CMTime.seconds(AssemblyConstants.crossfadeDuration)
                let prevDuration = segments.last!.timelineTimeRange.duration
                let shorter = prevDuration < sourceDuration ? prevDuration : sourceDuration
                if crossfade > shorter {
                    diagnostics.append(AssemblyDiagnostic(
                        severity: .warning,
                        shotGlobalNumber: entry.globalNumber,
                        message: "Dissolve skipped between shots #\(orderedShots[i - 1].globalNumber) and #\(entry.globalNumber): crossfade (\(crossfade.seconds)s) is longer than shorter clip (\(shorter.seconds.rounded(toPlaces: 3))s). Forcing cut."
                    ))
                } else {
                    timelineStart = currentTimelineTime - crossfade
                    let transitionRange = CMTimeRange(start: timelineStart, duration: crossfade)
                    // Use SEGMENT indices, not the shot index. For linear films
                    // segment index == shot index so this is byte-identical; under
                    // coverage one shot emits several segments, so the incoming
                    // index is the beat's first sub-segment (= current count).
                    transitionToAppend = TimelineTransition(
                        kind: .crossfade,
                        duration: crossfade,
                        timeRange: transitionRange,
                        outgoingSegmentIndex: segments.count - 1,
                        incomingSegmentIndex: segments.count
                    )
                    dissolvedFromPrevious = true
                }
            }

            // Warn if non-boundary fadeToBlack/fadeFromBlack appear (V1 ignores them).
            if i > 0, entry.shot.transitionInType == .fadeFromBlack {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    shotGlobalNumber: entry.globalNumber,
                    message: "fade_from_black on a non-first shot is unsupported in V1; treating as cut."
                ))
            }
            if i < orderedShots.count - 1, entry.shot.transitionOutType == .fadeToBlack {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    shotGlobalNumber: entry.globalNumber,
                    message: "fade_to_black on a non-last shot is unsupported in V1; treating as cut."
                ))
            }

            // Track choice: switch tracks only when a dissolve actually happens
            // (dissolves need outgoing + incoming visible simultaneously, which
            // requires separate tracks). For cuts, stay on the same track so the
            // composition keeps each track contiguous. iOS 26's MediaValidator
            // rejects exports where a video track has time gaps mid-timeline.
            // (`segments.isEmpty` rather than `i == 0` so a leading skipped
            // coverage member can't claim track 0; identical for linear films.)
            let trackIndex: Int
            if segments.isEmpty {
                trackIndex = 0
            } else if dissolvedFromPrevious {
                trackIndex = 1 - lastTrackIndex
            } else {
                trackIndex = lastTrackIndex
            }
            lastTrackIndex = trackIndex

            // ---- Emit segment(s)
            if let coverage = entry.shot.coverage, coverage.kind == .cropZoomSource {
                // Coverage beat: expand into intercut sub-segments tiling
                // [timelineStart, timelineStart + sourceDuration) as hard cuts on
                // one track. `sourceDuration` already honors recommendedHoldSeconds
                // (computed above) so the beat respects the planned hold.
                segments.append(contentsOf: Self.intercutSegments(
                    coverage: coverage,
                    beatGlobalNumber: entry.globalNumber,
                    wideURL: take.sourceURL,
                    beatDuration: sourceDuration,
                    beatTimelineStart: timelineStart,
                    trackIndex: trackIndex,
                    takesByGlobal: takesByGlobal,
                    diagnostics: &diagnostics
                ))
            } else {
                // Linear shot — one segment, exactly as before (cropRect defaults nil).
                segments.append(TimelineSegment(
                    shotGlobalNumber: entry.globalNumber,
                    sourceURL: take.sourceURL,
                    sourceTimeRange: sourceTimeRange,
                    timelineTimeRange: CMTimeRange(start: timelineStart, duration: sourceDuration),
                    trackIndex: trackIndex
                ))
            }
            if let t = transitionToAppend { transitions.append(t) }

            currentTimelineTime = timelineStart + sourceDuration
        }

        // ---- Fade from black (first shot only)
        if let firstShot = orderedShots.first?.shot,
           firstShot.transitionInType == .fadeFromBlack,
           let firstSegment = segments.first {
            let target = CMTime.seconds(AssemblyConstants.fadeFromBlackDuration)
            let actual = target < firstSegment.timelineTimeRange.duration ? target : firstSegment.timelineTimeRange.duration
            transitions.insert(TimelineTransition(
                kind: .fadeFromBlack,
                duration: actual,
                timeRange: CMTimeRange(start: .zero, duration: actual),
                outgoingSegmentIndex: nil,
                incomingSegmentIndex: 0
            ), at: 0)
        }

        // ---- Fade to black (last shot only)
        if let lastShot = orderedShots.last?.shot,
           lastShot.transitionOutType == .fadeToBlack,
           let lastSegment = segments.last {
            let target = CMTime.seconds(AssemblyConstants.fadeToBlackDuration)
            let actual = target < lastSegment.timelineTimeRange.duration ? target : lastSegment.timelineTimeRange.duration
            let lastEnd = lastSegment.timelineTimeRange.end
            let fadeStart = lastEnd - actual
            transitions.append(TimelineTransition(
                kind: .fadeToBlack,
                duration: actual,
                timeRange: CMTimeRange(start: fadeStart, duration: actual),
                outgoingSegmentIndex: segments.count - 1,
                incomingSegmentIndex: nil
            ))
        }

        // ---- Audio regions (per segment, then boundary ramps)
        // Map each segment back to its originating shot by global number rather
        // than by position: under coverage one shot yields several segments, so
        // positional `orderedShots[i]` would misalign. For linear films segment i
        // still maps to orderedShots[i], so this is byte-identical.
        let shotByGlobal = Dictionary(uniqueKeysWithValues: orderedShots.map { ($0.globalNumber, $0.shot) })
        let baseRegions = segments.map { segment -> AudioRegion in
            let treatment = shotByGlobal[segment.shotGlobalNumber]?.audioTreatment ?? .dialoguePriority
            let curves = Self.volumeCurves(for: treatment)
            return AudioRegion(
                timeRange: segment.timelineTimeRange,
                videoVolume: curves.video,
                musicVolume: curves.music
            )
        }
        let audioRegions = Self.insertBoundaryRamps(regions: baseRegions)

        // ---- Music regions
        let musicRegions = Self.buildMusicRegions(
            plan: plan,
            orderedShots: orderedShots,
            segments: segments
        )

        // If music cues exist but no music URL, log a diagnostic. Music regions
        // remain in the timeline so debugging tools can see the intent; Layer 2
        // omits the music track from the export.
        if !musicRegions.isEmpty, !hasMusicURL {
            diagnostics.append(AssemblyDiagnostic(
                severity: .info,
                shotGlobalNumber: nil,
                message: "Music cues present but no musicURL provided; music track will be omitted from export."
            ))
        }

        let totalDuration = segments.last?.timelineTimeRange.end ?? .zero

        return EditorialTimeline(
            segments: segments,
            transitions: transitions,
            audioRegions: audioRegions,
            musicRegions: musicRegions,
            totalDuration: totalDuration,
            diagnostics: diagnostics
        )
    }

    // MARK: - Helpers

    struct ShotEntry {
        let globalNumber: Int   // 1-indexed
        let sceneIndex: Int
        let shotIndexInScene: Int
        let scene: FilmScene
        let shot: Shot
    }

    static func flattenShots(plan: FilmmakingPlan) -> [ShotEntry] {
        var out: [ShotEntry] = []
        var counter = 0
        for (sceneIdx, scene) in plan.scenes.enumerated() {
            for (shotIdx, shot) in scene.shots.enumerated() {
                counter += 1
                out.append(ShotEntry(
                    globalNumber: counter,
                    sceneIndex: sceneIdx,
                    shotIndexInScene: shotIdx,
                    scene: scene,
                    shot: shot
                ))
            }
        }
        return out
    }

    static func shouldDissolve(prev: Shot, curr: Shot) -> Bool {
        prev.transitionOutType == .dissolve || curr.transitionInType == .dissolve
    }

    // MARK: - Coverage intercut (Layer 1, pure)

    /// Expands a crop-zoom coverage beat into a sequence of intercut segments —
    /// the cut decisions only; the actual crop is rendered later (Phase 3), this
    /// records the rect on each segment.
    ///
    /// Placement is PROPORTIONAL and deliberately diarization-free: each
    /// `LineRun.estimatedSeconds` is a RELATIVE WEIGHT, scaled onto the beat's
    /// real (already hold-trimmed) `beatDuration`. Cuts will drift from the actual
    /// speech — that is the accepted tradeoff of not analyzing audio.
    ///
    /// A jitter floor (`minCoverageSegmentSeconds`) prevents sub-second strobing:
    /// a slice below the floor is absorbed into the current block (the previous
    /// angle holds through the too-short run). After the forward pass only the
    /// first block can still be below the floor; it is forward-merged into the
    /// next (the next angle covers the short opening). The only segment that may
    /// end up below the floor is a whole beat that is itself shorter than the
    /// floor (unavoidable). Segment durations always sum to EXACTLY `beatDuration`
    /// (the last segment absorbs rounding), and `wide`/`cropZoom` runs reference
    /// the same wide URL with contiguous source ranges so the original audio
    /// reconstructs continuously across the intercut.
    static func intercutSegments(
        coverage: CoverageRole,
        beatGlobalNumber: Int,
        wideURL: URL,
        beatDuration: CMTime,
        beatTimelineStart: CMTime,
        trackIndex: Int,
        takesByGlobal: [Int: SelectedTake],
        diagnostics: inout [AssemblyDiagnostic]
    ) -> [TimelineSegment] {
        let runs = coverage.lineRuns

        // Degenerate: no runs declared → one wide segment spanning the beat,
        // i.e. equivalent to a linear shot.
        guard !runs.isEmpty else {
            return [TimelineSegment(
                shotGlobalNumber: beatGlobalNumber,
                sourceURL: wideURL,
                sourceTimeRange: CMTimeRange(start: .zero, duration: beatDuration),
                timelineTimeRange: CMTimeRange(start: beatTimelineStart, duration: beatDuration),
                trackIndex: trackIndex
            )]
        }

        // 1) Proportional slice (seconds) per run from relative weights.
        let beatSeconds = beatDuration.seconds
        let weights = runs.map { Swift.max(0, $0.estimatedSeconds) }
        let totalWeight = weights.reduce(0, +)
        let sliceSeconds: [Double] = totalWeight > 0
            ? weights.map { beatSeconds * $0 / totalWeight }
            : runs.map { _ in beatSeconds / Double(runs.count) }   // all-zero weights → equal split

        // 2) Forward pass: build angle blocks, absorbing any sub-floor slice into
        //    the current block. After this, only block 0 can be below the floor.
        let floor = AssemblyConstants.minCoverageSegmentSeconds
        struct Block { var angle: CoverageAngle; var seconds: Double }
        var blocks: [Block] = []
        for (idx, run) in runs.enumerated() {
            let s = sliceSeconds[idx]
            if blocks.isEmpty {
                blocks.append(Block(angle: run.angle, seconds: s))
            } else if s < floor {
                blocks[blocks.count - 1].seconds += s
            } else {
                blocks.append(Block(angle: run.angle, seconds: s))
            }
        }

        // 3) Leading-block fix: forward-merge a sub-floor opening block into the
        //    next (the next angle covers the short opening). A lone sub-floor block
        //    means the whole beat is shorter than the floor — emit it as one
        //    segment (the floor cannot be satisfied).
        if blocks.count >= 2, blocks[0].seconds < floor {
            blocks[1].seconds += blocks[0].seconds
            blocks.removeFirst()
        }

        // 4) Materialize. Source/timeline ranges are contiguous on the master
        //    (wide) timeline; the last segment absorbs rounding so the total is
        //    exactly `beatDuration`.
        var result: [TimelineSegment] = []
        var cursor = CMTime.zero
        for (bi, block) in blocks.enumerated() {
            let isLast = bi == blocks.count - 1
            let segDuration = isLast ? (beatDuration - cursor) : CMTime.seconds(block.seconds)
            let resolved = Self.resolveAngle(
                block.angle,
                wideURL: wideURL,
                sourceStart: cursor,
                segDuration: segDuration,
                takesByGlobal: takesByGlobal,
                beatGlobalNumber: beatGlobalNumber,
                diagnostics: &diagnostics
            )
            result.append(TimelineSegment(
                shotGlobalNumber: beatGlobalNumber,
                sourceURL: resolved.url,
                sourceTimeRange: CMTimeRange(start: resolved.sourceStart, duration: segDuration),
                timelineTimeRange: CMTimeRange(start: beatTimelineStart + cursor, duration: segDuration),
                trackIndex: trackIndex,
                cropRect: resolved.cropRect
            ))
            cursor = cursor + segDuration
        }
        return result
    }

    /// Resolves a `CoverageAngle` to a concrete (source URL, source start, crop).
    /// - `.wide`: the wide take at the beat offset, no crop (audio-continuous).
    /// - `.cropZoom`: the wide take at the beat offset, with the crop rect recorded
    ///   for Phase 3 to punch in (still the same URL, so audio stays continuous).
    /// - `.separateAngle`: a different take by global number, sampled at the same
    ///   offset (assumed roughly time-aligned), clamped to fit that take. Falls
    ///   back to the wide (with a diagnostic) if the take is missing or too short.
    ///
    /// Audio-continuity note: the caller advances a TIMELINE cursor, not a source
    /// cursor, so a `.separateAngle` run is interposed on the timeline without
    /// breaking the wide's source continuity — every `.wide`/`.cropZoom` run still
    /// sources from its own beat offset in the wide, so those slices remain
    /// globally contiguous on the wide and its audio reconstructs across them. A
    /// `.separateAngle` window simply carries its own take's audio for its slot.
    private static func resolveAngle(
        _ angle: CoverageAngle,
        wideURL: URL,
        sourceStart: CMTime,
        segDuration: CMTime,
        takesByGlobal: [Int: SelectedTake],
        beatGlobalNumber: Int,
        diagnostics: inout [AssemblyDiagnostic]
    ) -> (url: URL, sourceStart: CMTime, cropRect: NormalizedRect?) {
        switch angle {
        case .wide:
            return (wideURL, sourceStart, nil)
        case .cropZoom(let region):
            return (wideURL, sourceStart, region)
        case .separateAngle(let globalShotNumber):
            guard let take = takesByGlobal[globalShotNumber] else {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    shotGlobalNumber: beatGlobalNumber,
                    message: "Coverage references missing separate-angle shot #\(globalShotNumber); falling back to the wide."
                ))
                return (wideURL, sourceStart, nil)
            }
            // Clamp the source window into the separate-angle take's bounds.
            let maxStart = take.duration - segDuration
            if maxStart < .zero {
                diagnostics.append(AssemblyDiagnostic(
                    severity: .warning,
                    shotGlobalNumber: beatGlobalNumber,
                    message: "Separate-angle shot #\(globalShotNumber) (\(take.duration.seconds.rounded(toPlaces: 3))s) is shorter than its \(segDuration.seconds.rounded(toPlaces: 3))s slot; falling back to the wide."
                ))
                return (wideURL, sourceStart, nil)
            }
            let clampedStart = sourceStart < maxStart ? sourceStart : maxStart
            return (take.sourceURL, clampedStart, nil)
        }
    }

    static func volumeCurves(for treatment: AudioTreatment) -> (video: VolumeCurve, music: VolumeCurve) {
        switch treatment {
        case .dialoguePriority:
            return (.constant(AssemblyConstants.dialoguePriorityVideoVolume),
                    .constant(AssemblyConstants.dialoguePriorityMusicVolume))
        case .musicPriority:
            return (.constant(AssemblyConstants.musicPriorityVideoVolume),
                    .constant(AssemblyConstants.musicPriorityMusicVolume))
        case .ambientOnly:
            return (.constant(AssemblyConstants.ambientOnlyVideoVolume),
                    .constant(AssemblyConstants.ambientOnlyMusicVolume))
        case .silent:
            return (.constant(AssemblyConstants.silentVideoVolume),
                    .constant(AssemblyConstants.silentMusicVolume))
        case .crescendo:
            return (.constant(AssemblyConstants.crescendoVideoVolume),
                    .ramp(from: AssemblyConstants.crescendoMusicRampStart,
                          to: AssemblyConstants.crescendoMusicRampEnd))
        }
    }

    /// Walks pairs of adjacent regions; where the level at the boundary differs,
    /// shrinks each by half the ramp duration and inserts a ramp region in
    /// between. If either neighbouring region is too short to absorb the shrink
    /// (less than 2× the ramp), the ramp is skipped.
    static func insertBoundaryRamps(regions input: [AudioRegion]) -> [AudioRegion] {
        guard input.count >= 2 else { return input }

        let rampDuration = CMTime.seconds(AssemblyConstants.boundaryAudioRampDuration)
        let halfRamp = CMTimeMultiplyByRatio(rampDuration, multiplier: 1, divisor: 2)
        let minRoom = CMTimeMultiplyByRatio(rampDuration, multiplier: 2, divisor: 1)

        var result: [AudioRegion] = []
        var pending = input[0]

        for i in 1..<input.count {
            let next = input[i]
            let outgoingVideo = pending.videoVolume.endLevel
            let outgoingMusic = pending.musicVolume.endLevel
            let incomingVideo = next.videoVolume.startLevel
            let incomingMusic = next.musicVolume.startLevel
            let differs = outgoingVideo != incomingVideo || outgoingMusic != incomingMusic

            // Sanity: only ramp where the regions actually meet.
            let pendingEnd = pending.timeRange.end
            let nextStart = next.timeRange.start
            let touching = pendingEnd == nextStart
            let pendingFitsRamp = pending.timeRange.duration >= minRoom
            let nextFitsRamp = next.timeRange.duration >= minRoom

            if differs && touching && pendingFitsRamp && nextFitsRamp {
                // Shrink pending end by halfRamp.
                let newPendingDur = pending.timeRange.duration - halfRamp
                let shrunkPending = AudioRegion(
                    timeRange: CMTimeRange(start: pending.timeRange.start, duration: newPendingDur),
                    videoVolume: pending.videoVolume,
                    musicVolume: pending.musicVolume
                )
                result.append(shrunkPending)

                let rampStart = pendingEnd - halfRamp
                let rampRegion = AudioRegion(
                    timeRange: CMTimeRange(start: rampStart, duration: rampDuration),
                    videoVolume: .ramp(from: outgoingVideo, to: incomingVideo),
                    musicVolume: .ramp(from: outgoingMusic, to: incomingMusic)
                )
                result.append(rampRegion)

                let nextNewStart = nextStart + halfRamp
                let nextNewDur = next.timeRange.duration - halfRamp
                pending = AudioRegion(
                    timeRange: CMTimeRange(start: nextNewStart, duration: nextNewDur),
                    videoVolume: next.videoVolume,
                    musicVolume: next.musicVolume
                )
            } else {
                result.append(pending)
                pending = next
            }
        }
        result.append(pending)
        return result
    }

    static func buildMusicRegions(
        plan: FilmmakingPlan,
        orderedShots: [ShotEntry],
        segments: [TimelineSegment]
    ) -> [MusicRegion] {
        guard !segments.isEmpty else { return [] }

        let fadeIn = CMTime.seconds(AssemblyConstants.musicFadeInDuration)
        let fadeOut = CMTime.seconds(AssemblyConstants.musicFadeOutDuration)

        var regions: [MusicRegion] = []
        var openSegmentIndex: Int?

        for (sceneIdx, scene) in plan.scenes.enumerated() {
            // Find this scene's segments by global shot number rather than by
            // position (one covered shot can yield several segments). For linear
            // films this resolves to the same indices as before — byte-identical.
            let sceneGlobals = Set(orderedShots.filter { $0.sceneIndex == sceneIdx }.map { $0.globalNumber })
            let sceneSegmentIndices = segments.indices.filter { sceneGlobals.contains(segments[$0].shotGlobalNumber) }
            guard let firstIdx = sceneSegmentIndices.first,
                  let lastIdx = sceneSegmentIndices.last else { continue }

            if scene.musicCueIn == true && openSegmentIndex == nil {
                openSegmentIndex = firstIdx
            }
            if scene.musicCueOut == true, let openIdx = openSegmentIndex {
                let regionStart = segments[openIdx].timelineTimeRange.start
                let regionEnd = segments[lastIdx].timelineTimeRange.end
                regions.append(MusicRegion(
                    timeRange: CMTimeRange(start: regionStart, end: regionEnd),
                    fadeInDuration: fadeIn,
                    fadeOutDuration: fadeOut
                ))
                openSegmentIndex = nil
            }
        }

        // Close any unclosed cue at the end of the film.
        if let openIdx = openSegmentIndex {
            let regionStart = segments[openIdx].timelineTimeRange.start
            let regionEnd = segments.last!.timelineTimeRange.end
            regions.append(MusicRegion(
                timeRange: CMTimeRange(start: regionStart, end: regionEnd),
                fadeInDuration: fadeIn,
                fadeOutDuration: fadeOut
            ))
        }

        return regions
    }
}

// MARK: - Small utilities

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let m = pow(10.0, Double(places))
        return (self * m).rounded() / m
    }
}
