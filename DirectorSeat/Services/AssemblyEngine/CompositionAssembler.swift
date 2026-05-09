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
        // Per-segment source transform — needed for layer instructions below.
        // When a videoComposition is set on the export session, AVFoundation
        // does NOT auto-apply the track's preferredTransform; the rotation
        // must be set explicitly via AVMutableVideoCompositionLayerInstruction.
        // setTransform(_:at:). Setting `track.preferredTransform` alone is a
        // no-op in this code path.
        var segmentTransforms: [Int: CGAffineTransform] = [:]

        for (segmentIndex, segment) in timeline.segments.enumerated() {
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

            segmentTransforms[segmentIndex] = preferredTransform

            let track = videoTracks[segment.trackIndex]!

            try track.insertTimeRange(
                segment.sourceTimeRange,
                of: assetVideoTrack,
                at: segment.timelineTimeRange.start
            )

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
            videoTracks: videoTracks,
            segmentTransforms: segmentTransforms
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
        videoTracks: [Int: AVMutableCompositionTrack],
        segmentTransforms: [Int: CGAffineTransform]
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

        // Map track index -> segment indices on that track, in time order. Used
        // to find the active segment for a given track during a stable interval
        // so we can apply that segment's source transform on the layer.
        var segmentsByTrack: [Int: [Int]] = [:]
        for (segIdx, seg) in timeline.segments.enumerated() {
            segmentsByTrack[seg.trackIndex, default: []].append(segIdx)
        }

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
                    videoTracks: videoTracks,
                    segmentTransforms: segmentTransforms
                )
            } else {
                // Stable interval: find the active segment(s).
                let activeSegmentIndices = timeline.segments.enumerated()
                    .filter { $0.element.timelineTimeRange.contains(interval) }
                    .map { $0.offset }
                instruction.layerInstructions = layerInstructions(
                    forStableSegmentIndices: activeSegmentIndices,
                    timeline: timeline,
                    videoTracks: videoTracks,
                    segmentTransforms: segmentTransforms
                )
            }
            instructions.append(instruction)
        }
        return instructions
    }

    private func layerInstructions(
        forStableSegmentIndices segmentIndices: [Int],
        timeline: EditorialTimeline,
        videoTracks: [Int: AVMutableCompositionTrack],
        segmentTransforms: [Int: CGAffineTransform]
    ) -> [AVVideoCompositionLayerInstruction] {

        let activeByTrack: [Int: Int] = segmentIndices.reduce(into: [:]) { result, segIdx in
            result[timeline.segments[segIdx].trackIndex] = segIdx
        }

        return videoTracks.keys.sorted().map { trackIdx in
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[trackIdx]!)
            if let activeSeg = activeByTrack[trackIdx] {
                layer.setOpacity(1.0, at: .zero)
                if let transform = segmentTransforms[activeSeg] {
                    layer.setTransform(transform, at: .zero)
                }
            } else {
                layer.setOpacity(0.0, at: .zero)
            }
            return layer
        }
    }

    private func layerInstructions(
        forTransition transition: TimelineTransition,
        timeline: EditorialTimeline,
        videoTracks: [Int: AVMutableCompositionTrack],
        segmentTransforms: [Int: CGAffineTransform]
    ) -> [AVVideoCompositionLayerInstruction] {

        var rampedTrackIndices = Set<Int>()
        var rampedLayers: [AVVideoCompositionLayerInstruction] = []

        func makeLayer(forSegmentIndex segIdx: Int) -> (track: Int, layer: AVMutableVideoCompositionLayerInstruction) {
            let trackIdx = timeline.segments[segIdx].trackIndex
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTracks[trackIdx]!)
            if let transform = segmentTransforms[segIdx] {
                layer.setTransform(transform, at: .zero)
            }
            return (trackIdx, layer)
        }

        switch transition.kind {
        case .crossfade:
            if let outgoing = transition.outgoingSegmentIndex {
                let (trackIdx, layer) = makeLayer(forSegmentIndex: outgoing)
                layer.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
            if let incoming = transition.incomingSegmentIndex {
                let (trackIdx, layer) = makeLayer(forSegmentIndex: incoming)
                layer.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
        case .fadeFromBlack:
            if let incoming = transition.incomingSegmentIndex {
                let (trackIdx, layer) = makeLayer(forSegmentIndex: incoming)
                layer.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: transition.timeRange)
                rampedLayers.append(layer)
                rampedTrackIndices.insert(trackIdx)
            }
        case .fadeToBlack:
            if let outgoing = transition.outgoingSegmentIndex {
                let (trackIdx, layer) = makeLayer(forSegmentIndex: outgoing)
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
