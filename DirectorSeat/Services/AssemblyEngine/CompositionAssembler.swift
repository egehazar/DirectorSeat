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

            // Real iPhone preferredTransform usually includes the translation
            // that places content into the (0, 0, postTransformWidth,
            // postTransformHeight) canvas — but not always (e.g. clips made
            // with `AVAssetWriterInput.transform = .rotate(.pi/2)` have no
            // translation, leaving content at NEGATIVE x). Compute a corrective
            // translation that aligns the post-transform bounding box to (0,0)
            // and concatenate. Idempotent for already-correct transforms.
            let sourceRect = CGRect(origin: .zero, size: naturalSize)
            let bbox = sourceRect.applying(preferredTransform)
            let corrective = CGAffineTransform(translationX: -bbox.origin.x, y: -bbox.origin.y)
            let alignedTransform = preferredTransform.concatenating(corrective)

            // Phase 3 (crop-zoom). A coverage intercut segment may carry a
            // `cropRect` — a normalized sub-rectangle of the source's DISPLAY
            // frame (post-`preferredTransform`) that should be punched into and
            // scaled up to fill the render canvas. The crop is applied IN DISPLAY
            // SPACE, i.e. AFTER `alignedTransform` (which is what maps the source
            // into that display space). Composition order, in CG's row-vector
            // convention where `A.concatenating(B)` means "apply A, then B":
            //
            //   natural --[alignedTransform]--> display --[cropTransform]--> canvas
            //   composed = alignedTransform.concatenating(cropTransform)
            //
            // `renderSize` here is THIS source's display size (the same space the
            // normalized rect is expressed in), so the crop math is self-consistent
            // with the orientation transform and the close-up comes out upright
            // (it inherits `alignedTransform`'s rotation; the crop only scales +
            // translates within the already-upright display frame).
            //
            // INVARIANT — the `cropRect == nil` branch is byte-for-byte the old
            // behavior: `segmentTransforms[segmentIndex] = alignedTransform`. The
            // crop machinery never runs for linear films or `.wide` coverage
            // segments. Audio is untouched here (video-only transform); cropZoom
            // sub-slices share the wide URL with contiguous source ranges, so the
            // original take's audio still reconstructs continuously.
            if let cropRect = segment.cropRect {
                let cropTransform = Self.cropZoomTransform(for: cropRect, displaySize: renderSize)
                let composed = alignedTransform.concatenating(cropTransform)
                segmentTransforms[segmentIndex] = composed
                Self.logCropDiagnostics(
                    segmentIndex: segmentIndex,
                    shotGlobalNumber: segment.shotGlobalNumber,
                    naturalSize: naturalSize,
                    preferredTransform: preferredTransform,
                    alignedTransform: alignedTransform,
                    cropRect: cropRect,
                    cropTransform: cropTransform,
                    composed: composed,
                    displaySize: renderSize
                )
            } else {
                segmentTransforms[segmentIndex] = alignedTransform
            }

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

    // MARK: - Crop-zoom (Phase 3)

    /// Builds the crop-zoom punch-in transform, to be applied IN DISPLAY SPACE
    /// (i.e. composed AFTER the orientation `alignedTransform`). It maps the
    /// normalized sub-rect `rect` of the source's displayed frame onto the FULL
    /// render canvas: the sub-rect's origin → the canvas origin, the sub-rect →
    /// the whole canvas.
    ///
    /// Coordinate space: `rect` is normalized 0...1 in the source's DISPLAY space
    /// (post-`preferredTransform`) — exactly the space `alignedTransform` outputs
    /// into. `displaySize` is that displayed frame's pixel size (the engine's
    /// per-source `naturalSize.applying(preferredTransform).abs()`, e.g. 1080×1920
    /// portrait). The returned transform therefore lives in the same space as the
    /// orientation transform, so composing them is well-defined.
    ///
    /// Algebra (CG row-vector convention, `p' = p · M`): a display point `(X, Y)`
    /// maps to `((X - cx)/w, (Y - cy)/h)` where `(cx, cy) = (x·W, y·H)` is the crop
    /// origin in display pixels and `(w, h)` the normalized crop size. That is:
    ///
    ///   a = 1/w,  d = 1/h,  tx = -cx/w = -(x·W)·sx,  ty = -cy/h = -(y·H)·sy
    ///
    /// Worked check (display 1080×1920):
    ///   • full-frame (0,0,1,1) → (a=1,d=1,tx=0,ty=0) = identity ⇒ IDENTICAL to the
    ///     no-crop path. This is the byte-for-byte guarantee, expressed in math.
    ///   • left-half (0,0,0.5,1) → (a=2,d=1,tx=0,ty=0): display x∈[0,540] fills
    ///     x∈[0,1080]; the right half is pushed off-canvas (clipped).
    ///   • centre punch-in (0.25,0.25,0.5,0.5) → (a=2,d=2,tx=-540,ty=-960): the
    ///     centre 540×960 region fills the full 1080×1920 — a clean uniform 2×.
    ///
    /// Exact-fill semantics: the sub-rect is mapped EXACTLY onto the canvas, so the
    /// canvas is always fully covered — no letterbox/pillarbox, ever (this is the
    /// failure mode that produced the split-frame bugs; exact-fill structurally
    /// rules it out). When the sub-rect's aspect ratio matches the canvas — the
    /// production case, a CU that crops ≈half of EACH linear dimension and thus
    /// preserves 9:16 — `sx == sy` and there is no distortion. A non-aspect-matched
    /// rect is anisotropically stretched to fill rather than letterboxed; emitting
    /// aspect-correct rects is the builder's (Layer-1) responsibility, not the
    /// renderer's.
    static func cropZoomTransform(for rect: NormalizedRect, displaySize: CGSize) -> CGAffineTransform {
        // Defensive: a zero/negative/non-finite rect can't define a crop. Fall
        // back to identity ("render the take as-is") rather than divide by zero
        // or emit NaNs into the composition.
        guard rect.width > 0, rect.height > 0,
              rect.width.isFinite, rect.height.isFinite,
              rect.x.isFinite, rect.y.isFinite else {
            return .identity
        }
        let sx = 1.0 / rect.width
        let sy = 1.0 / rect.height
        let cx = rect.x * Double(displaySize.width)   // crop origin in display px
        let cy = rect.y * Double(displaySize.height)
        return CGAffineTransform(
            a: CGFloat(sx), b: 0, c: 0, d: CGFloat(sy),
            tx: CGFloat(-cx * sx), ty: CGFloat(-cy * sy)
        )
    }

    #if DEBUG
    /// When true, `assemble` prints the full transform chain for each crop
    /// segment — the same kind of instrumented dump that localized the renderSize
    /// bug. Off by default so even DEBUG builds stay quiet; tests / manual device
    /// runs flip it on to capture actual numbers. Never compiled into release.
    nonisolated(unsafe) static var cropZoomDiagnosticsEnabled = false
    #endif

    /// Logs the orientation→crop→composed transform chain for a crop segment.
    /// No-op unless DEBUG and `cropZoomDiagnosticsEnabled`; compiled out of release.
    static func logCropDiagnostics(
        segmentIndex: Int,
        shotGlobalNumber: Int,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        alignedTransform: CGAffineTransform,
        cropRect: NormalizedRect,
        cropTransform: CGAffineTransform,
        composed: CGAffineTransform,
        displaySize: CGSize
    ) {
        #if DEBUG
        guard cropZoomDiagnosticsEnabled else { return }
        func f(_ t: CGAffineTransform) -> String {
            "[a=\(t.a) b=\(t.b) c=\(t.c) d=\(t.d) tx=\(t.tx) ty=\(t.ty)]"
        }
        print("[CropZoom] seg #\(segmentIndex) shot #\(shotGlobalNumber)"
            + " display=\(Int(displaySize.width))x\(Int(displaySize.height))"
            + " natural=\(Int(naturalSize.width))x\(Int(naturalSize.height))"
            + " cropRect=(x=\(cropRect.x) y=\(cropRect.y) w=\(cropRect.width) h=\(cropRect.height))")
        print("[CropZoom]   preferred=\(f(preferredTransform))")
        print("[CropZoom]   aligned  =\(f(alignedTransform))")
        print("[CropZoom]   crop     =\(f(cropTransform))")
        print("[CropZoom]   composed =\(f(composed))")
        #endif
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
