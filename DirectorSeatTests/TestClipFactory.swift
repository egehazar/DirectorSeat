import AVFoundation
import CoreVideo
import Foundation

/// Shared helpers for synthesizing test clips via AVAssetWriter.
enum TestClipFactory {

    /// Three solid-colour clips at 1920x1080 with a 90° rotation transform —
    /// mimics how the iPhone records portrait video onto a landscape sensor,
    /// but with no translation baked in (the synthetic counterpart to real
    /// hardware footage that DOES include the translation).
    static func makeRotatedPortraitClips(
        count: Int,
        durationSeconds: Double,
        in workDir: URL
    ) async throws -> [URL] {
        var urls: [URL] = []
        let baseColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (180, 60, 60), (60, 130, 80), (60, 80, 160),
        ]
        let rotation = CGAffineTransform(rotationAngle: .pi / 2)
        for i in 0..<count {
            let url = workDir.appendingPathComponent("synth_portrait_clip_\(i).mov")
            let color = baseColors[i % baseColors.count]
            try await writeSolidColorVideo(
                to: url,
                durationSeconds: durationSeconds,
                size: CGSize(width: 1920, height: 1080),
                rgb: color,
                preferredTransform: rotation
            )
            urls.append(url)
        }
        return urls
    }

    static func writeSolidColorVideo(
        to url: URL,
        durationSeconds: Double,
        size: CGSize,
        rgb: (r: UInt8, g: UInt8, b: UInt8),
        preferredTransform: CGAffineTransform = .identity
    ) async throws {
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(url: url, fileType: .mov)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = preferredTransform

        let pixelAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelAttrs
        )

        guard writer.canAdd(videoInput) else {
            throw NSError(domain: "TestClipFactory", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let pixelBuffer = try makeSolidColorPixelBuffer(size: size, rgb: rgb)
        let fps: Int32 = 30
        let totalFrames = Int(durationSeconds * Double(fps))

        for frame in 0..<totalFrames {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let pts = CMTime(value: Int64(frame), timescale: fps)
            if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
                throw writer.error ?? NSError(
                    domain: "TestClipFactory", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "adaptor.append returned false at frame \(frame)"]
                )
            }
        }

        videoInput.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? NSError(
                domain: "TestClipFactory", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "AssetWriter status \(writer.status.rawValue)"]
            )
        }
    }

    static func makeSolidColorPixelBuffer(
        size: CGSize,
        rgb: (r: UInt8, g: UInt8, b: UInt8)
    ) throws -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )
        guard status == kCVReturnSuccess, let buffer = pb else {
            throw NSError(domain: "TestClipFactory", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "CVPixelBufferCreate failed: \(status)"])
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw NSError(domain: "TestClipFactory", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "No base address"])
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = Int(size.height)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            var x = 0
            while x < bytesPerRow {
                row[x] = rgb.b
                row[x + 1] = rgb.g
                row[x + 2] = rgb.r
                row[x + 3] = 0xFF
                x += 4
            }
        }
        return buffer
    }
}
