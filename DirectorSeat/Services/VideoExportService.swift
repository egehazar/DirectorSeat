import AVFoundation
import CoreImage
import UIKit

enum VideoExportError: Error, LocalizedError {
    case noInput
    case assetLoadFailed
    case exportFailed(String)
    case titleCardFailed

    var errorDescription: String? {
        switch self {
        case .noInput: "No video to export."
        case .assetLoadFailed: "Could not load the assembled video."
        case .exportFailed(let msg): "Export failed: \(msg)"
        case .titleCardFailed: "Could not generate title cards."
        }
    }
}

class VideoExportService {
    func export(
        assembledURL: URL,
        state: PostProductionState,
        includeWatermark: Bool,
        plan: FilmmakingPlan,
        outputDirectory: URL? = nil
    ) async throws -> URL {
        let mainAsset = AVURLAsset(url: assembledURL)
        let mainDuration = try await mainAsset.load(.duration)

        // Single source of truth for the export canvas: the assembled video's
        // real displayed size = naturalSize after its preferredTransform.
        // Orientation-agnostic — portrait in yields a portrait canvas, landscape
        // in yields landscape. Never fall back to a hardcoded/landscape frame.
        guard let mainVideoTrack = try await mainAsset.loadTracks(withMediaType: .video).first else {
            throw VideoExportError.assetLoadFailed
        }
        let mainNaturalSize = try await mainVideoTrack.load(.naturalSize)
        let mainPreferredTransform = try await mainVideoTrack.load(.preferredTransform)
        let displayRect = CGRect(origin: .zero, size: mainNaturalSize).applying(mainPreferredTransform)
        let renderSize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))

        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw VideoExportError.assetLoadFailed }

        // Audio track allocated lazily — an empty audio track causes export to
        // fail on iOS 26 (MediaValidator err=-12783), so only create it once
        // there is real audio to insert. Mirrors CompositionAssembler's approach.
        var compAudioTrack: AVMutableCompositionTrack?

        var insertTime = CMTime.zero

        // Title card
        if state.titleCardsEnabled, !state.filmTitle.isEmpty {
            if let titleURL = try? await createTitleCard(
                text: state.filmTitle,
                subtitle: nil,
                duration: 2.0,
                size: renderSize
            ) {
                let titleAsset = AVURLAsset(url: titleURL)
                let titleDuration = try await titleAsset.load(.duration)
                if let vt = try? await titleAsset.loadTracks(withMediaType: .video).first {
                    try? compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: titleDuration), of: vt, at: insertTime)
                }
                insertTime = CMTimeAdd(insertTime, titleDuration)
            }
        }

        // Main video (track already loaded above for the render-size derivation)
        try compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: mainDuration), of: mainVideoTrack, at: insertTime)
        if let mainAudio = try? await mainAsset.loadTracks(withMediaType: .audio).first {
            if compAudioTrack == nil {
                compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            }
            try? compAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: mainDuration), of: mainAudio, at: insertTime)
        }
        let mainEndTime = CMTimeAdd(insertTime, mainDuration)

        // End card
        if state.titleCardsEnabled, !state.directorName.isEmpty {
            if let endURL = try? await createTitleCard(
                text: "Directed by \(state.directorName)",
                subtitle: "Made with DirectorSeat",
                duration: 2.0,
                size: renderSize
            ) {
                let endAsset = AVURLAsset(url: endURL)
                let endDuration = try await endAsset.load(.duration)
                if let vt = try? await endAsset.loadTracks(withMediaType: .video).first {
                    try? compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: endDuration), of: vt, at: mainEndTime)
                }
            }
        }

        // Music
        var audioMix: AVMutableAudioMix?
        if let trackId = state.musicTrackId,
           let track = MusicTrack.library.first(where: { $0.id == trackId }),
           let fileName = track.fileName,
           let musicURL = Bundle.main.url(forResource: fileName, withExtension: nil),
           state.musicVolume > 0
        {
            let musicAsset = AVURLAsset(url: musicURL)
            if let musicAudioTrack = try? await musicAsset.loadTracks(withMediaType: .audio).first,
               let compMusicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            {
                let musicDuration = try await musicAsset.load(.duration)
                let targetDuration = min(musicDuration, composition.duration)
                try? compMusicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: targetDuration), of: musicAudioTrack, at: .zero)

                let mix = AVMutableAudioMix()
                var inputParams: [AVMutableAudioMixInputParameters] = []
                // Only duck the original audio if a source audio track exists.
                if let compAudioTrack {
                    let originalParams = AVMutableAudioMixInputParameters(track: compAudioTrack)
                    originalParams.setVolume(Float(1.0 - state.musicVolume), at: .zero)
                    inputParams.append(originalParams)
                }
                let musicParams = AVMutableAudioMixInputParameters(track: compMusicTrack)
                musicParams.setVolume(Float(state.musicVolume), at: .zero)
                inputParams.append(musicParams)
                mix.inputParameters = inputParams
                audioMix = mix
            }
        }

        // Color + watermark via CIFilter
        let needsFilter = state.colorPreset != .original || includeWatermark
        let videoComposition: AVMutableVideoComposition

        if needsFilter {
            let watermarkCIImage: CIImage? = includeWatermark ? renderWatermarkCIImage() : nil

            videoComposition = try await AVMutableVideoComposition.videoComposition(with: composition) { request in
                var output = request.sourceImage.clampedToExtent()

                if state.colorPreset != .original, let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    switch state.colorPreset {
                    case .warm:
                        filter.setValue(1.15, forKey: kCIInputSaturationKey)
                        filter.setValue(0.04, forKey: kCIInputBrightnessKey)
                    case .cool:
                        filter.setValue(0.85, forKey: kCIInputSaturationKey)
                        filter.setValue(-0.02, forKey: kCIInputBrightnessKey)
                        filter.setValue(1.05, forKey: kCIInputContrastKey)
                    case .original:
                        break
                    }
                    output = filter.outputImage ?? output
                }

                var final = output.cropped(to: request.sourceImage.extent)

                if let wm = watermarkCIImage {
                    let positioned = wm.transformed(by: CGAffineTransform(
                        translationX: request.sourceImage.extent.width - wm.extent.width - 24,
                        y: 24
                    ))
                    final = positioned.composited(over: final)
                }

                request.finish(with: final, context: nil)
            }
        } else {
            // No color/watermark pass, but still attach a pass-through video
            // composition so the export canvas is set explicitly to the assembled
            // video's size rather than inheriting the composition track's native
            // (title-card-derived) dimensions.
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
            layer.setOpacity(1.0, at: .zero)
            instruction.layerInstructions = [layer]
            let passthrough = AVMutableVideoComposition()
            passthrough.frameDuration = CMTime(value: 1, timescale: 30)
            passthrough.instructions = [instruction]
            videoComposition = passthrough
        }

        // Canvas = the assembled video's real displayed size (single source of
        // truth). Portrait in -> portrait out; landscape in -> landscape out.
        videoComposition.renderSize = renderSize

        // Export
        let exportDir = outputDirectory ?? FileManager.default.temporaryDirectory
        let outputURL = exportDir.appendingPathComponent("export_\(UUID().uuidString).mp4")

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else { throw VideoExportError.exportFailed("Could not create export session.") }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        if let am = audioMix { session.audioMix = am }

        await session.export()

        guard session.status == .completed else {
            throw VideoExportError.exportFailed(session.error?.localizedDescription ?? "Unknown error")
        }

        return outputURL
    }

    // MARK: - Title Card Generation

    private func createTitleCard(text: String, subtitle: String?, duration: TimeInterval, size: CGSize) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("titlecard_\(UUID().uuidString).mov")

        guard let pixelBuffer = renderTextFrame(text: text, subtitle: subtitle, size: size)
        else { throw VideoExportError.titleCardFailed }

        let writer = try AVAssetWriter(url: outputURL, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input)

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let totalFrames = Int(duration * Double(fps))
        for frame in 0..<totalFrames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else { throw VideoExportError.titleCardFailed }
        return outputURL
    }

    private func renderTextFrame(text: String, subtitle: String?, size: CGSize) -> CVPixelBuffer? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(red: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let style = NSMutableParagraphStyle()
            style.alignment = .center

            let titleFont = UIFont.systemFont(ofSize: size.height * 0.045, weight: .semibold)
            (text as NSString).draw(
                in: CGRect(x: size.width * 0.1, y: size.height * 0.42, width: size.width * 0.8, height: size.height * 0.12),
                withAttributes: [.font: titleFont, .foregroundColor: UIColor.white, .paragraphStyle: style]
            )

            if let subtitle {
                let subFont = UIFont.systemFont(ofSize: size.height * 0.025, weight: .regular)
                (subtitle as NSString).draw(
                    in: CGRect(x: size.width * 0.1, y: size.height * 0.55, width: size.width * 0.8, height: size.height * 0.08),
                    withAttributes: [.font: subFont, .foregroundColor: UIColor.white.withAlphaComponent(0.6), .paragraphStyle: style]
                )
            }
        }

        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB,
                            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pb)
        guard let buffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                   bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue),
           let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    // MARK: - Watermark

    private func renderWatermarkCIImage() -> CIImage? {
        let text = "Made with DirectorSeat"
        let font = UIFont.systemFont(ofSize: 32, weight: .semibold)
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 1, height: 1)
        shadow.shadowBlurRadius = 2
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .shadow: shadow,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let canvasSize = CGSize(width: ceil(textSize.width) + 4, height: ceil(textSize.height) + 4)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { _ in
            (text as NSString).draw(at: CGPoint(x: 2, y: 2), withAttributes: attrs)
        }
        return CIImage(image: image)
    }
}
