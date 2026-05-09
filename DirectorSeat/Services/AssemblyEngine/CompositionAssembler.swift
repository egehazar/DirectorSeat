import AVFoundation
import CoreMedia
import Foundation

/// Layer 2 of the assembly engine. Mechanical translation:
/// `EditorialTimeline -> (AVMutableComposition, AVMutableVideoComposition, AVMutableAudioMix?)`.
/// No editorial decisions made here — just turning the timeline plan into AVFoundation objects.
struct CompositionAssembler {

    struct Output {
        let composition: AVMutableComposition
        let videoComposition: AVMutableVideoComposition
        let audioMix: AVMutableAudioMix?
        let renderSize: CGSize
    }

    func assemble(timeline: EditorialTimeline, musicURL: URL?) async throws -> Output {

        let composition = AVMutableComposition()

        // Only allocate video tracks the timeline actually uses. Allocating a
        // never-used track is harmless on most iOS versions but iOS 26's
        // MediaValidator can flag the composition as unsupported during export.
        let usedTrackIndices = Set(timeline.segments.map { $0.trackIndex }).sorted()
        var videoTracks: [Int: AVMutableCompositionTrack] = [:]
        for idx in usedTrackIndices {
            guard let track = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            else {
                throw AssemblyError.compositionSetupFailed("Could not allocate video track \(idx).")
            }
            videoTracks[idx] = track
        }
        // Audio track allocated lazily — adding an empty audio track to a
        // composition causes export to fail on iOS 26 with MediaValidator
        // err=-12783.
        var sourceAudioTrack: AVMutableCompositionTrack?

        // ---- Insert source video + audio for each segment

        var firstRenderSize: CGSize?

        for segment in timeline.segments {
            let asset = AVURLAsset(url: segment.sourceURL)

            guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw AssemblyError.missingVideoTrack(shotGlobalNumber: segment.shotGlobalNumber)
            }

            // Dimension consistency check (V1 requires identical resolution).
            let naturalSize = try await assetVideoTrack.load(.naturalSize)
            let preferredTransform = try await assetVideoTrack.load(.preferredTransform)
            let renderSize = naturalSize.applying(preferredTransform).abs()
            if let firstSize = firstRenderSize {
                if !firstSize.approximatelyEquals(renderSize) {
                    throw AssemblyError.inconsistentSourceDimensions
                }
            } else {
                firstRenderSize = renderSize
            }

            let track = videoTracks[segment.trackIndex]!

            try track.insertTimeRange(
                segment.sourceTimeRange,
                of: assetVideoTrack,
                at: segment.timelineTimeRange.start
            )

            // Carry through the transform so a portrait take stays portrait in render.
            track.preferredTransform = preferredTransform

            if let assetAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                if sourceAudioTrack == nil {
                    sourceAudioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                }
                try? sourceAudioTrack?.insertTimeRange(
                    segment.sourceTimeRange,
                    of: assetAudioTrack,
                    at: segment.timelineTimeRange.start
                )
            }
        }

        let renderSize = firstRenderSize ?? CGSize(width: 1920, height: 1080)

        // ---- Music track (only if URL provided AND there is at least one region)
        var musicCompositionTrack: AVMutableCompositionTrack?
        if let musicURL = musicURL, !timeline.musicRegions.isEmpty {
            let musicAsset = AVURLAsset(url: musicURL)
            if let musicAssetTrack = try? await musicAsset.loadTracks(withMediaType: .audio).first,
               let track = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            {
                musicCompositionTrack = track
                let musicAssetDuration = try await musicAsset.load(.duration)

                for region in timeline.musicRegions {
                    let needed = region.timeRange.duration
                    let useDuration = needed < musicAssetDuration ? needed : musicAssetDuration
                    let sourceRange = CMTimeRange(start: .zero, duration: useDuration)
                    try? track.insertTimeRange(
                        sourceRange,
                        of: musicAssetTrack,
                        at: region.timeRange.start
                    )
                }
            }
        }

        // ---- Build video composition instructions
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: AssemblyConstants.frameRate)
        videoComposition.renderSize = renderSize
        videoComposition.instructions = buildVideoInstructions(
            timeline: timeline,
            videoTracks: videoTracks
        )

        // ---- Build audio mix
        let audioMix = buildAudioMix(
            timeline: timeline,
            sourceAudioTrack: sourceAudioTrack,
            musicTrack: musicCompositionTrack
        )

        return Output(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            renderSize: renderSize
        )
    }

    // MARK: - Video instructions

    private func buildVideoInstructions(
        timeline: EditorialTimeline,
        videoTracks: [Int: AVMutableCompositionTrack]
    ) -> [AVMutableVideoCompositionInstruction] {

        guard !timeline.segments.isEmpty else { return [] }

        // Build sorted unique event times: every segment + transition boundary, plus 0 and totalDuration.
        var times = Set<CMTime>()
        times.insert(.zero)
        times.insert(timeline.totalDuration)
        for s in timeline.segments {
            times.insert(s.timelineTimeRange.start)
            times.insert(s.timelineTimeRange.end)
        }
        for t in timeline.transitions {
            times.insert(t.timeRange.start)
            times.insert(t.timeRange.end)
        }

        let sortedTimes = times.sorted()
        var instructions: [AVMutableVideoCompositionInstruction] = []

        for i in 0..<(sortedTimes.count - 1) {
            let t1 = sortedTimes[i]
            let t2 = sortedTimes[i + 1]
            if t1 == t2 { continue }
            let interval = CMTimeRange(start: t1, end: t2)

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = interval

            // Is this interval fully inside a transition?
            if let transition = timeline.transitions.first(where: { $0.timeRange.contains(interval) }) {
                instruction.layerInstructions = layerInstructions(
                    forTransition: transition,
                    timeline: timeline,
                    videoTracks: videoTracks
                )
            } else {
                // Stable interval: find the active segment(s).
                let activeSegments = timeline.segments.filter { $0.timelineTimeRange.contains(interval) }
                instruction.layerInstructions = layerInstructions(
                    forStableSegments: activeSegments,
                    videoTracks: videoTracks
                )
            }
            instructions.append(instruction)
        }
        return instructions
    }

    private func layerInstructions(
        forStableSegments segments: [TimelineSegment],
        videoTracks: [Int: AVMutableCompositionTrack]
    ) -> [AVVideoCompositionLayerInstruction] {
        let activeIndices = Set(segments.map { $0.trackIndex })
        return videoTracks.keys.sorted().map { idx in
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[idx]!)
            let opacity: Float = activeIndices.contains(idx) ? 1.0 : 0.0
            layer.setOpacity(opacity, at: .zero)
            return layer
        }
    }

    private func layerInstructions(
        forTransition transition: TimelineTransition,
        timeline: EditorialTimeline,
        videoTracks: [Int: AVMutableCompositionTrack]
    ) -> [AVVideoCompositionLayerInstruction] {

        var rampedTrackIndices = Set<Int>()
        var rampedLayers: [AVVideoCompositionLayerInstruction] = []

        switch transition.kind {
        case .crossfade:
            if let outgoing = transition.outgoingSegmentIndex {
                let trackIdx = timeline.segments[outgoing].trackIndex
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[trackIdx]!)
                layer.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
            if let incoming = transition.incomingSegmentIndex {
                let trackIdx = timeline.segments[incoming].trackIndex
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[trackIdx]!)
                layer.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
        case .fadeFromBlack:
            if let incoming = transition.incomingSegmentIndex {
                let trackIdx = timeline.segments[incoming].trackIndex
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[trackIdx]!)
                layer.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
        case .fadeToBlack:
            if let outgoing = transition.outgoingSegmentIndex {
                let trackIdx = timeline.segments[outgoing].trackIndex
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[trackIdx]!)
                layer.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
        }

        // Add inactive tracks at opacity 0.0 to keep all tracks declared.
        for idx in videoTracks.keys.sorted() where !rampedTrackIndices.contains(idx) {
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[idx]!)
            layer.setOpacity(0.0, at: .zero)
            rampedLayers.append(layer)
        }
        return rampedLayers
    }

    // MARK: - Audio mix

    private func buildAudioMix(
        timeline: EditorialTimeline,
        sourceAudioTrack: AVMutableCompositionTrack?,
        musicTrack: AVMutableCompositionTrack?
    ) -> AVMutableAudioMix? {

        guard !timeline.audioRegions.isEmpty else { return nil }
        // Without any audio tracks at all, no mix to build.
        guard sourceAudioTrack != nil || musicTrack != nil else { return nil }

        let mix = AVMutableAudioMix()
        var inputParams: [AVMutableAudioMixInputParameters] = []

        if let sourceAudioTrack {
            let sourceParams = AVMutableAudioMixInputParameters(track: sourceAudioTrack)
            applyVolume(to: sourceParams, regions: timeline.audioRegions, pickVideo: true)
            inputParams.append(sourceParams)
        }

        if let musicTrack {
            let musicParams = AVMutableAudioMixInputParameters(track: musicTrack)
            applyVolume(to: musicParams, regions: timeline.audioRegions, pickVideo: false)
            inputParams.append(musicParams)
        }

        mix.inputParameters = inputParams
        return mix
    }

    private func applyVolume(
        to params: AVMutableAudioMixInputParameters,
        regions: [AudioRegion],
        pickVideo: Bool
    ) {
        for region in regions {
            let curve = pickVideo ? region.videoVolume : region.musicVolume
            switch curve {
            case .constant(let v):
                params.setVolume(v, at: region.timeRange.start)
                // Hold the value through the region by setting again at the end (cheap insurance).
                params.setVolume(v, at: region.timeRange.end - CMTime(value: 1, timescale: AssemblyConstants.timeScale))
            case .ramp(let from, let to):
                params.setVolumeRamp(fromStartVolume: from, toEndVolume: to, timeRange: region.timeRange)
            }
        }
    }
}

// MARK: - Helpers

private extension CMTimeRange {
    func contains(_ other: CMTimeRange) -> Bool {
        start <= other.start && other.end <= end
    }
}

private extension CGSize {
    func abs() -> CGSize { CGSize(width: Swift.abs(width), height: Swift.abs(height)) }
    func approximatelyEquals(_ other: CGSize) -> Bool {
        Swift.abs(width - other.width) < 1.0 && Swift.abs(height - other.height) < 1.0
    }
}
