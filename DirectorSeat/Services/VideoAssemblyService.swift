import AVFoundation
import CoreImage

enum ColorPreset: String, CaseIterable, Identifiable {
    case original, warm, cool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: "Original"
        case .warm: "Warm"
        case .cool: "Cool"
        }
    }
}

enum VideoAssemblyError: Error, LocalizedError {
    case noClips
    case insufficientClips
    case assetFailure
    case exportFailure(String)

    var errorDescription: String? {
        switch self {
        case .noClips: "No clips to assemble."
        case .insufficientClips: "Not enough valid clips to assemble."
        case .assetFailure: "Could not read one or more video clips."
        case .exportFailure(let msg): "Export failed: \(msg)"
        }
    }
}

class VideoAssemblyService {
    func assembleClips(urls: [URL], outputURL: URL) async throws -> URL {
        guard !urls.isEmpty else { throw VideoAssemblyError.noClips }

        let validURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard validURLs.count >= 2 else { throw VideoAssemblyError.insufficientClips }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw VideoAssemblyError.assetFailure }

        var currentTime = CMTime.zero

        for url in validURLs {
            let asset = AVURLAsset(url: url)
            let duration: CMTime
            do {
                duration = try await asset.load(.duration)
            } catch {
                throw VideoAssemblyError.assetFailure
            }

            if let assetVideo = try? await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetVideo,
                    at: currentTime
                )
            }

            if let assetAudio = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetAudio,
                    at: currentTime
                )
            }

            currentTime = CMTimeAdd(currentTime, duration)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else { throw VideoAssemblyError.exportFailure("Could not create export session.") }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw VideoAssemblyError.exportFailure(
                exportSession.error?.localizedDescription ?? "Unknown error"
            )
        }

        return outputURL
    }

    func assembleClips(urls: [URL], outputURL: URL, colorPreset: ColorPreset) async throws -> URL {
        guard colorPreset != .original else {
            return try await assembleClips(urls: urls, outputURL: outputURL)
        }

        guard !urls.isEmpty else { throw VideoAssemblyError.noClips }

        let validURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard validURLs.count >= 2 else { throw VideoAssemblyError.insufficientClips }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw VideoAssemblyError.assetFailure }

        var currentTime = CMTime.zero

        for url in validURLs {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)

            if let assetVideo = try? await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetVideo,
                    at: currentTime
                )
            }
            if let assetAudio = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetAudio,
                    at: currentTime
                )
            }
            currentTime = CMTimeAdd(currentTime, duration)
        }

        let videoComposition = try await AVMutableVideoComposition.videoComposition(
            with: composition
        ) { request in
            let source = request.sourceImage.clampedToExtent()
            guard let filter = CIFilter(name: "CIColorControls") else {
                request.finish(with: request.sourceImage, context: nil)
                return
            }
            filter.setValue(source, forKey: kCIInputImageKey)

            switch colorPreset {
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

            let output = (filter.outputImage ?? source).cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: nil)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else { throw VideoAssemblyError.exportFailure("Could not create export session.") }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw VideoAssemblyError.exportFailure(
                exportSession.error?.localizedDescription ?? "Unknown error"
            )
        }

        return outputURL
    }
}
