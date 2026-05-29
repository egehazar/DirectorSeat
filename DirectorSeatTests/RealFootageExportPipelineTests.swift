import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
import CoreGraphics
@testable import DirectorSeat

/// Diagnostics are mirrored to an absolute host path because xcodebuild's
/// result-bundle stdout capture is unreliable in this environment (the
/// result-bundle CAS DB fails `mkstemp` against the non-standard TMPDIR, and
/// Xcode buffers test `print()` into that bundle — so console output is lost
/// on save failure). The iOS simulator writes to host absolute paths directly,
/// so this file lands on the Mac regardless of result-bundle health.
fileprivate enum DiagFile {
    static let path = "/tmp/ds_pipeline_diag.txt"
    static func reset() {
        try? "".write(toFile: path, atomically: true, encoding: .utf8)
    }
    static func log(_ s: String) {
        print(s)
        let line = s + "\n"
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile()
            if let d = line.data(using: .utf8) { h.write(d) }
            try? h.close()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

/// Pipeline tests against real iPhone footage in
/// `Fixtures/RealFootage/`. The synthesized AVAssetWriter clips used by
/// `AssemblyEngineIntegrationTests` don't reproduce iPhone's preferredTransform
/// (rotation + translation baked together) — these fixtures do, so failures
/// here mean failures on real hardware.
final class RealFootageExportPipelineTests: XCTestCase {

    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RealFootageIT_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    private var fixtureURLs: [URL] {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/RealFootage")
        return [
            base.appendingPathComponent("shot_1_portrait.mov"),
            base.appendingPathComponent("shot_2_portrait.mov"),
            base.appendingPathComponent("shot_3_portrait.mov"),
        ]
    }

    // MARK: - Fixture sanity

    func testRealFootageFixturesArePresentAndPortrait() async throws {
        for url in fixtureURLs {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "Missing fixture: \(url.path)")
            let extent = try await postTransformExtent(of: url)
            XCTAssertGreaterThan(extent.height, extent.width,
                                 "Fixture \(url.lastPathComponent) is not portrait after preferredTransform: \(extent.width)x\(extent.height)")
        }
    }

    // MARK: - Diagnostic: side-by-side metadata dump (no assertions)

    func testDiagnostic_DumpPipelineMetadataRealVsSynthesized() async throws {
        DiagFile.reset()
        DiagFile.log("========== PIPELINE METADATA DIAGNOSTIC ==========")
        DiagFile.log("written to \(DiagFile.path)")

        let engine = AssemblyEngine()

        // Each stage is isolated so a throw in one does not abort the dump —
        // a recorded error IS diagnostic. extents are captured for the final
        // real-vs-synth disagreement summary.
        var realEngineExtent: CGSize?
        var realExportExtent: CGSize?
        var synthEngineExtent: CGSize?
        var synthExportExtent: CGSize?

        // ---- REAL footage path -------------------------------------------------
        DiagFile.log("\n--- STAGE: source takes (real iPhone hardware) ---")
        for url in fixtureURLs {
            do { try await dumpMetadata(label: url.lastPathComponent, url: url) }
            catch { DiagFile.log("  [\(url.lastPathComponent)] ERROR: \(error)") }
        }

        let realEngineURL = workDir.appendingPathComponent("real_engine_output.mov")
        DiagFile.log("\n--- STAGE: AssemblyEngine intermediate output (real source) ---")
        do {
            _ = try await engine.assembleFromOrderedURLs(
                plan: makeThreeShotPlan(holdSeconds: 5.0),
                takeURLs: fixtureURLs,
                musicURL: nil,
                outputURL: realEngineURL,
                progress: { _ in }
            )
            try await dumpMetadata(label: "real_engine_output.mov", url: realEngineURL)
            realEngineExtent = try? await postTransformExtent(of: realEngineURL)
        } catch { DiagFile.log("  ENGINE(real) ERROR: \(error)") }

        DiagFile.log("\n--- STAGE: VideoExportService final output (real source) ---")
        do {
            let realExportURL = try await runExportService(
                assembledURL: realEngineURL,
                plan: makeThreeShotPlan(holdSeconds: 5.0)
            )
            try await dumpMetadata(label: realExportURL.lastPathComponent, url: realExportURL)
            realExportExtent = try? await postTransformExtent(of: realExportURL)
        } catch { DiagFile.log("  EXPORT(real) ERROR: \(error)") }

        // ---- SYNTHESIZED footage path -----------------------------------------
        DiagFile.log("\n\n--- STAGE: synthesized takes (AVAssetWriter, rotation-only) ---")
        var synthURLs: [URL] = []
        do {
            synthURLs = try await TestClipFactory.makeRotatedPortraitClips(
                count: 3, durationSeconds: 2.0, in: workDir
            )
            for url in synthURLs {
                try await dumpMetadata(label: url.lastPathComponent, url: url)
            }
        } catch { DiagFile.log("  SYNTH-CLIPS ERROR: \(error)") }

        let synthEngineURL = workDir.appendingPathComponent("synth_engine_output.mov")
        DiagFile.log("\n--- STAGE: AssemblyEngine intermediate output (synthesized source) ---")
        if !synthURLs.isEmpty {
            do {
                _ = try await engine.assembleFromOrderedURLs(
                    plan: makeThreeShotPlan(holdSeconds: 2.0),
                    takeURLs: synthURLs,
                    musicURL: nil,
                    outputURL: synthEngineURL,
                    progress: { _ in }
                )
                try await dumpMetadata(label: "synth_engine_output.mov", url: synthEngineURL)
                synthEngineExtent = try? await postTransformExtent(of: synthEngineURL)
            } catch { DiagFile.log("  ENGINE(synth) ERROR: \(error)") }

            DiagFile.log("\n--- STAGE: VideoExportService final output (synthesized source) ---")
            do {
                let synthExportURL = try await runExportService(
                    assembledURL: synthEngineURL,
                    plan: makeThreeShotPlan(holdSeconds: 2.0)
                )
                try await dumpMetadata(label: synthExportURL.lastPathComponent, url: synthExportURL)
                synthExportExtent = try? await postTransformExtent(of: synthExportURL)
            } catch { DiagFile.log("  EXPORT(synth) ERROR: \(error)") }
        }

        // ---- Disagreement summary ---------------------------------------------
        func fmt(_ s: CGSize?) -> String {
            guard let s else { return "n/a" }
            let orient = s.height > s.width ? "PORTRAIT" : (s.width > s.height ? "LANDSCAPE" : "SQUARE")
            let ratio = s.width > 0 ? String(format: "%.1f%%", Double(min(s.width, s.height) / max(s.width, s.height)) * 100) : "?"
            return "\(Int(s.width))x\(Int(s.height)) [\(orient)] short/long=\(ratio)"
        }
        DiagFile.log("\n--- SUMMARY: engine output vs final export ---")
        DiagFile.log("  REAL  engine=\(fmt(realEngineExtent))  ->  export=\(fmt(realExportExtent))")
        DiagFile.log("  SYNTH engine=\(fmt(synthEngineExtent))  ->  export=\(fmt(synthExportExtent))")
        if let e = realEngineExtent, let x = realExportExtent {
            let widthFill = e.width / x.width
            DiagFile.log("  REAL content-width / export-canvas-width = \(Int(e.width))/\(Int(x.width)) = \(String(format: "%.1f%%", Double(widthFill) * 100))")
        }

        DiagFile.log("\n========== END DIAGNOSTIC ==========")
    }

    // MARK: - Engine-only: real footage should yield portrait

    func testAssemblyEnginePreservesPortraitFromRealTakes() async throws {
        let outputURL = workDir.appendingPathComponent("engine_only_real.mov")
        let engine = AssemblyEngine()
        _ = try await engine.assembleFromOrderedURLs(
            plan: makeThreeShotPlan(holdSeconds: 5.0),
            takeURLs: fixtureURLs,
            musicURL: nil,
            outputURL: outputURL,
            progress: { _ in }
        )
        let extent = try await postTransformExtent(of: outputURL)
        XCTAssertEqual(Int(extent.width), 1080,
                       "AssemblyEngine output width should be 1080; got \(extent.width)")
        XCTAssertEqual(Int(extent.height), 1920,
                       "AssemblyEngine output height should be 1920; got \(extent.height)")
        XCTAssertGreaterThan(extent.height, extent.width,
                             "AssemblyEngine output should be portrait")
    }

    // MARK: - Full pipeline: engine + VideoExportService must preserve portrait
    //
    // This test is the regression target for the title-card-canvas bug.
    // Currently FAILS: VideoExportService inherits a 1920x1080 landscape
    // canvas from its hardcoded title card, then non-uniformly stretches
    // the engine's 1080x1920 portrait output into it.

    func testFullPipelinePreservesPortraitFromRealTakes() async throws {
        let engineURL = workDir.appendingPathComponent("pipeline_engine.mov")
        let engine = AssemblyEngine()
        _ = try await engine.assembleFromOrderedURLs(
            plan: makeThreeShotPlan(holdSeconds: 5.0),
            takeURLs: fixtureURLs,
            musicURL: nil,
            outputURL: engineURL,
            progress: { _ in }
        )
        let exportURL = try await runExportService(
            assembledURL: engineURL,
            plan: makeThreeShotPlan(holdSeconds: 5.0)
        )

        // Canvas must be the assembled video's portrait 1080x1920, NOT the legacy
        // 1920x1080 landscape inherited from the hardcoded title card.
        let extent = try await postTransformExtent(of: exportURL)
        XCTAssertEqual(Int(extent.width), 1080,
                       "Export width should be 1080 (portrait); got \(extent.width)x\(extent.height)")
        XCTAssertEqual(Int(extent.height), 1920,
                       "Export height should be 1920 (portrait); got \(extent.width)x\(extent.height)")
        XCTAssertGreaterThan(extent.height, extent.width,
                             "Full pipeline must preserve portrait. Got \(extent.width)x\(extent.height).")

        // Sample a pixel near the right edge of a mid-film frame. Under the bug,
        // portrait content filled only the left 56% of a landscape canvas and the
        // right edge was solid black. A non-black right-edge pixel proves the
        // content now spans the full (portrait) width.
        let rightEdge = try await sampleRightEdgePixelOfMainContent(url: exportURL)
        XCTAssertGreaterThan(rightEdge.maxChannel, 12,
                             "Right-edge pixel is black (\(rightEdge)) — content not filling the frame width.")
    }

    // MARK: - Helpers

    @MainActor
    private func runExportService(assembledURL: URL, plan: FilmmakingPlan) async throws -> URL {
        let state = PostProductionState()
        state.titleCardsEnabled = true
        state.filmTitle = "Diag Title"
        state.directorName = "Diag Director"
        let service = VideoExportService()
        return try await service.export(
            assembledURL: assembledURL,
            state: state,
            includeWatermark: false,
            plan: plan,
            outputDirectory: workDir
        )
    }

    private func dumpMetadata(label: String, url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            DiagFile.log("  [\(label)] MISSING at \(url.path)")
            return
        }
        let asset = AVURLAsset(url: url)
        let dur = try await asset.load(.duration)
        let vtracks = try await asset.loadTracks(withMediaType: .video)
        let atracks = try await asset.loadTracks(withMediaType: .audio)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        DiagFile.log("  [\(label)] dur=\(String(format: "%.3f", dur.seconds))s vtracks=\(vtracks.count) atracks=\(atracks.count) size=\(fileSize)B")
        for (i, t) in vtracks.enumerated() {
            let n = try await t.load(.naturalSize)
            let pt = try await t.load(.preferredTransform)
            let fps = try await t.load(.nominalFrameRate)
            let extent = CGRect(origin: .zero, size: n).applying(pt)
            DiagFile.log("    vtrack[\(i)] naturalSize=\(Int(n.width))x\(Int(n.height)) fps=\(fps)")
            DiagFile.log("                preferredTransform [a=\(pt.a) b=\(pt.b) c=\(pt.c) d=\(pt.d) tx=\(pt.tx) ty=\(pt.ty)]")
            DiagFile.log("                post-transform extent: \(abs(extent.width))x\(abs(extent.height)) (signed \(extent.width)x\(extent.height)) origin=(\(extent.minX),\(extent.minY))")
        }
    }

    private func postTransformExtent(of url: URL) async throws -> CGSize {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return .zero
        }
        let n = try await track.load(.naturalSize)
        let pt = try await track.load(.preferredTransform)
        let rect = CGRect(origin: .zero, size: n).applying(pt)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    struct PixelSample: CustomStringConvertible {
        let r: Int, g: Int, b: Int
        var maxChannel: Int { max(r, max(g, b)) }
        var description: String { "rgb(\(r),\(g),\(b))" }
    }

    /// Samples a pixel ~5px in from the right edge, vertical centre, of a frame
    /// 10s into the film — comfortably inside the main footage (past the ~2s
    /// title card, before the end card), so it reflects real content, not the
    /// near-black title canvas.
    private func sampleRightEdgePixelOfMainContent(url: URL) async throws -> PixelSample {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 2)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 2)
        let cgImage = try await generator.image(at: CMTime(seconds: 10, preferredTimescale: 600)).image
        let x = max(0, cgImage.width - 5)
        let y = cgImage.height / 2
        return try pixel(in: cgImage, x: x, y: y)
    }

    private func pixel(in cgImage: CGImage, x: Int, y: Int) throws -> PixelSample {
        let width = cgImage.width
        let height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "PixelSample", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create CGContext"])
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let idx = (y * width + x) * 4
        return PixelSample(r: Int(data[idx]), g: Int(data[idx + 1]), b: Int(data[idx + 2]))
    }

    private func makeThreeShotPlan(holdSeconds: Double) -> FilmmakingPlan {
        let shots = (1...3).map { n in
            Shot(
                shotNumber: n,
                shotType: "wide",
                directionText: "real \(n)",
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
            description: "real test",
            locationDescription: "anywhere",
            castCount: 1,
            shots: shots,
            pacingProfile: nil,
            musicCueIn: nil,
            musicCueOut: nil
        )
        return FilmmakingPlan(
            logline: "real footage test",
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
}
