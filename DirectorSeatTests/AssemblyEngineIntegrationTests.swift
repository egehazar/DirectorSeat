import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
@testable import DirectorSeat

/// Layer 2/3 integration tests that exercise the full pipeline on simulator.
/// Generates short solid-color MOV files via AVAssetWriter, assembles them
/// through the engine, and verifies the resulting file is playable and the
/// expected duration.
final class AssemblyEngineIntegrationTests: XCTestCase {

    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssemblyEngineIT_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: - Tests

    /// Diagnostic: verify that the synthesized test clips we generate are themselves
    /// exportable via plain AVAssetExportSession. If this fails, the test fixtures
    /// are bad (not the engine). If it passes, any failure in the next test is the
    /// engine's fault.
    func testGeneratedTestClipIsExportable() async throws {
        let clipURL = try await makeTestClips(count: 1, durationSeconds: 2.0).first!
        let outputURL = workDir.appendingPathComponent("plain_export.mov")
        try? FileManager.default.removeItem(at: outputURL)

        let asset = AVURLAsset(url: clipURL)
        let composition = AVMutableComposition()
        guard let vt = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let avt = try await asset.loadTracks(withMediaType: .video).first
        else { XCTFail("could not set up composition"); return }
        let dur = try await asset.load(.duration)
        try vt.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: avt, at: .zero)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            XCTFail("could not create export session"); return
        }
        try await session.export(to: outputURL, as: .mov)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path),
                      "Plain export of test clip failed to produce file.")
    }

    /// Diagnostic: insert 3 test clips back-to-back on a single track manually
    /// (no engine), then plain-export. If this fails, the test fixtures don't
    /// concatenate cleanly. If it passes, something in CompositionAssembler is
    /// the issue.
    func testThreeTestClipsManuallyConcatenatedAreExportable() async throws {
        let urls = try await makeTestClips(count: 3, durationSeconds: 2.0)
        let outputURL = workDir.appendingPathComponent("manual_concat.mov")
        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()
        guard let vt = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { XCTFail("vt"); return }
        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let dur = try await asset.load(.duration)
            let avt = try await asset.loadTracks(withMediaType: .video).first!
            try vt.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: avt, at: cursor)
            cursor = cursor + dur
        }
        print("[diag-manual] composition.duration=\(composition.duration.seconds)")

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            XCTFail("session"); return
        }
        try await session.export(to: outputURL, as: .mov)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    /// Diagnostic: build the engine's composition + videoComposition + audioMix,
    /// then export them with a plain AVAssetExportSession. Bypasses our Exporter
    /// so we can isolate whether failure is in Layer 2 vs Layer 3.
    func testEngineCompositionIsExportableDirectly() async throws {
        let clipDuration: Double = 2.0
        let urls = try await makeTestClips(count: 3, durationSeconds: clipDuration)

        let plan = makeFastTestStylePlan(holdSeconds: clipDuration)
        var takes: [SelectedTake] = []
        for (i, url) in urls.enumerated() {
            let asset = AVURLAsset(url: url)
            let dur = try await asset.load(.duration)
            takes.append(SelectedTake(shotGlobalNumber: i + 1, sourceURL: url, duration: dur))
        }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)
        print("[diag] segments=\(timeline.segments.count) transitions=\(timeline.transitions.count) totalDur=\(timeline.totalDuration.seconds)")
        for (i, s) in timeline.segments.enumerated() {
            print("[diag] seg[\(i)] track=\(s.trackIndex) src=[\(s.sourceTimeRange.start.seconds), \(s.sourceTimeRange.end.seconds)] tl=[\(s.timelineTimeRange.start.seconds), \(s.timelineTimeRange.end.seconds)]")
        }

        let assembled = try await CompositionAssembler().assemble(timeline: timeline, musicURL: nil)
        print("[diag] composition.duration=\(assembled.composition.duration.seconds)")
        print("[diag] videoComposition.instructions=\(assembled.videoComposition.instructions.count)")
        for (i, inst) in assembled.videoComposition.instructions.enumerated() {
            print("[diag] inst[\(i)] range=[\(inst.timeRange.start.seconds), \(inst.timeRange.end.seconds)]")
        }

        let outputURL = workDir.appendingPathComponent("direct_export.mov")
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: assembled.composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            XCTFail("Could not create export session"); return
        }
        session.videoComposition = assembled.videoComposition
        if let mix = assembled.audioMix { session.audioMix = mix }

        try await session.export(to: outputURL, as: .mov)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path),
                      "Direct export of engine composition failed.")
    }

    /// Three-shot all-cuts assembly via the engine — same shape as the X-button
    /// fast-test path. Uses 2-second clips per shot so the export finishes quickly.
    func testThreeShotAllCutsAssemblyProducesPlayableFile() async throws {
        let clipDuration: Double = 2.0
        let urls = try await makeTestClips(count: 3, durationSeconds: clipDuration)

        let plan = makeFastTestStylePlan(holdSeconds: clipDuration)
        let outputURL = workDir.appendingPathComponent("assembled_\(UUID().uuidString).mov")

        let engine = AssemblyEngine()
        let result = try await engine.assembleFromOrderedURLs(
            plan: plan,
            takeURLs: urls,
            musicURL: nil,
            outputURL: outputURL,
            progress: { _ in }
        )

        XCTAssertEqual(result.path, outputURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path),
                      "Engine reported success but no file at \(outputURL.path)")

        let exported = AVURLAsset(url: outputURL)
        let duration = try await exported.load(.duration)
        let expected = clipDuration * Double(urls.count) // 3 cuts of 2s = 6s
        let toleranceSeconds = 0.10
        XCTAssertEqual(duration.seconds, expected, accuracy: toleranceSeconds,
                       "Output duration \(duration.seconds)s should be within ±\(toleranceSeconds)s of expected \(expected)s")

        let videoTracks = try await exported.loadTracks(withMediaType: .video)
        XCTAssertGreaterThan(videoTracks.count, 0, "Output has no video track")
    }

    /// Backward-compat smoke: plan with all editorial fields nil should still
    /// produce a file without crashing. We don't bit-compare against
    /// VideoAssemblyService — that's an aspiration the spec calls out as a
    /// real-iPhone exercise.
    func testLegacyPlanWithNoEditorialMetadataAssembles() async throws {
        let clipDuration: Double = 2.0
        let urls = try await makeTestClips(count: 3, durationSeconds: clipDuration)

        let plan = makeLegacyStylePlan()
        let outputURL = workDir.appendingPathComponent("legacy_\(UUID().uuidString).mov")

        let engine = AssemblyEngine()
        let result = try await engine.assembleFromOrderedURLs(
            plan: plan,
            takeURLs: urls,
            musicURL: nil,
            outputURL: outputURL,
            progress: { _ in }
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path),
                      "Legacy plan failed to produce output")

        let exported = AVURLAsset(url: outputURL)
        let duration = try await exported.load(.duration)
        // Legacy default: full take capped at 6s. With 2s takes the cap doesn't
        // kick in, so total = 6s.
        XCTAssertEqual(duration.seconds, 6.0, accuracy: 0.10)
    }

    // MARK: - Plan helpers

    private func makeFastTestStylePlan(holdSeconds: Double) -> FilmmakingPlan {
        let shots = (1...3).map { n in
            Shot(
                shotNumber: n,
                shotType: "wide",
                directionText: "test \(n)",
                cameraPlacement: "anywhere",
                actorDirection: "stand still",
                dialogueDirection: nil,
                estimatedDurationSeconds: Int(holdSeconds),
                soloShootable: true,
                audioRisk: "low",
                recommendedHoldSeconds: holdSeconds,
                transitionInType: nil,
                transitionOutType: nil,
                pacingRole: nil,
                audioTreatment: .dialoguePriority,
                editingNote: nil
            )
        }
        let scene = FilmScene(
            sceneNumber: 1,
            description: "test",
            locationDescription: "anywhere",
            castCount: 1,
            shots: shots,
            pacingProfile: nil,
            musicCueIn: nil,
            musicCueOut: nil
        )
        return FilmmakingPlan(
            logline: "integration test",
            estimatedDurationMinutes: 1,
            estimatedTotalShootMinutes: 5,
            scenes: [scene],
            cast: [],
            requiredStoryProps: [],
            optionalSetupHelpers: [],
            locationRequirements: [],
            musicMood: "test"
        )
    }

    private func makeLegacyStylePlan() -> FilmmakingPlan {
        let shots = (1...3).map { n in
            Shot(
                shotNumber: n,
                shotType: "wide",
                directionText: "test \(n)",
                cameraPlacement: "anywhere",
                actorDirection: "stand still",
                dialogueDirection: nil,
                estimatedDurationSeconds: 2,
                soloShootable: true,
                audioRisk: "low",
                recommendedHoldSeconds: nil,
                transitionInType: nil,
                transitionOutType: nil,
                pacingRole: nil,
                audioTreatment: nil,
                editingNote: nil
            )
        }
        let scene = FilmScene(
            sceneNumber: 1,
            description: "legacy",
            locationDescription: "anywhere",
            castCount: 1,
            shots: shots,
            pacingProfile: nil,
            musicCueIn: nil,
            musicCueOut: nil
        )
        return FilmmakingPlan(
            logline: "legacy test",
            estimatedDurationMinutes: 1,
            estimatedTotalShootMinutes: 5,
            scenes: [scene],
            cast: [],
            requiredStoryProps: [],
            optionalSetupHelpers: [],
            locationRequirements: [],
            musicMood: "test"
        )
    }

    // MARK: - Async helpers

    // Sequential async map (preserves order).

    // MARK: - Test video generation

    private func makeTestClips(count: Int, durationSeconds: Double) async throws -> [URL] {
        var urls: [URL] = []
        let baseColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (180, 60, 60),  // muted red
            (60, 130, 80),  // muted green
            (60, 80, 160),  // muted blue
        ]
        for i in 0..<count {
            let url = workDir.appendingPathComponent("clip_\(i).mov")
            let color = baseColors[i % baseColors.count]
            try await writeSolidColorVideo(
                to: url,
                durationSeconds: durationSeconds,
                size: CGSize(width: 1280, height: 720),
                rgb: color
            )
            urls.append(url)
        }
        return urls
    }

    private func writeSolidColorVideo(
        to url: URL,
        durationSeconds: Double,
        size: CGSize,
        rgb: (r: UInt8, g: UInt8, b: UInt8)
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
            throw NSError(domain: "AssemblyEngineIT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let pixelBuffer = try makeSolidColorPixelBuffer(size: size, rgb: rgb)
        let fps: Int32 = 30
        let totalFrames = Int(durationSeconds * Double(fps))

        for frame in 0..<totalFrames {
            // AVAssetWriter input occasionally back-pressures; wait until ready.
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            }
            let pts = CMTime(value: Int64(frame), timescale: fps)
            if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
                throw writer.error ?? NSError(
                    domain: "AssemblyEngineIT", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "adaptor.append returned false at frame \(frame)"]
                )
            }
        }

        videoInput.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? NSError(
                domain: "AssemblyEngineIT", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "AssetWriter status \(writer.status.rawValue)"]
            )
        }
    }

    private func makeSolidColorPixelBuffer(
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
            throw NSError(domain: "AssemblyEngineIT", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "CVPixelBufferCreate failed: \(status)"])
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw NSError(domain: "AssemblyEngineIT", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "No base address"])
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = Int(size.height)
        // BGRA: write B, G, R, 0xFF per pixel
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
