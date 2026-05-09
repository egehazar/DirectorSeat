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
            if i > 0, Self.shouldDissolve(prev: orderedShots[i - 1].shot, curr: entry.shot) {
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
                    transitionToAppend = TimelineTransition(
                        kind: .crossfade,
                        duration: crossfade,
                        timeRange: transitionRange,
                        outgoingSegmentIndex: i - 1,
                        incomingSegmentIndex: i
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

            let timelineTimeRange = CMTimeRange(start: timelineStart, duration: sourceDuration)
            // Track choice: switch tracks only when a dissolve actually happens
            // (dissolves need outgoing + incoming visible simultaneously, which
            // requires separate tracks). For cuts, stay on the same track so the
            // composition keeps each track contiguous. iOS 26's MediaValidator
            // rejects exports where a video track has time gaps mid-timeline.
            let trackIndex: Int
            if i == 0 {
                trackIndex = 0
            } else if dissolvedFromPrevious {
                trackIndex = 1 - lastTrackIndex
            } else {
                trackIndex = lastTrackIndex
            }
            lastTrackIndex = trackIndex

            segments.append(TimelineSegment(
                shotGlobalNumber: entry.globalNumber,
                sourceURL: take.sourceURL,
                sourceTimeRange: sourceTimeRange,
                timelineTimeRange: timelineTimeRange,
                trackIndex: trackIndex
            ))
            if let t = transitionToAppend { transitions.append(t) }

            currentTimelineTime = timelineTimeRange.end
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
        let baseRegions = segments.enumerated().map { (i, segment) -> AudioRegion in
            let treatment = orderedShots[i].shot.audioTreatment ?? .dialoguePriority
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
            let sceneSegmentIndices = orderedShots.enumerated()
                .filter { $0.element.sceneIndex == sceneIdx }
                .map { $0.offset }
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
