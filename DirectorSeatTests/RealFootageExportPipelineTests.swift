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

    // MARK: - Silent source (no audio track) must still export
    //
    // Regression guard for the iOS 26 empty-audio-track export rejection.
    // Synthesized clips carry no audio, so VideoExportService must allocate its
    // audio track lazily; with an empty audio track, export previously failed
    // with exportFailed("Operation Stopped").

    func testSilentSourceExportSucceedsAndIsPortrait() async throws {
        let synthURLs = try await TestClipFactory.makeRotatedPortraitClips(
            count: 3, durationSeconds: 2.0, in: workDir
        )
        let engineURL = workDir.appendingPathComponent("silent_engine.mov")
        let engine = AssemblyEngine()
        _ = try await engine.assembleFromOrderedURLs(
            plan: makeThreeShotPlan(holdSeconds: 2.0),
            takeURLs: synthURLs,
            musicURL: nil,
            outputURL: engineURL,
            progress: { _ in }
        )
        // Must not throw — a silent source previously triggered
        // exportFailed("Operation Stopped") from an empty audio track.
        let exportURL = try await runExportService(
            assembledURL: engineURL,
            plan: makeThreeShotPlan(holdSeconds: 2.0)
        )
        let extent = try await postTransformExtent(of: exportURL)
        XCTAssertEqual(Int(extent.width), 1080,
                       "Silent-source export width should be 1080; got \(extent.width)x\(extent.height)")
        XCTAssertEqual(Int(extent.height), 1920,
                       "Silent-source export height should be 1920; got \(extent.width)x\(extent.height)")
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

// MARK: - Phase 3: crop-zoom render tests
//
// These prove the CompositionAssembler crop transform on REAL iPhone footage by
// rendering through the full Layer-1→Layer-2→Layer-3 pipeline (a coverage plan
// drives TimelineBuilder to emit a cropRect, exactly as production will) and then
// SAMPLING EXPORTED PIXELS. Correctness is checked by independent reconstruction:
// the cropped render is compared against the same source frame cropped+stretched
// in-test with CoreGraphics. Because every test rect is either full-height
// (y-origin irrelevant) or vertically symmetric about centre, the checks are
// agnostic to AVFoundation's absolute vertical origin — the one thing that still
// needs eyes-on-device confirmation (flagged in the commit).
extension RealFootageExportPipelineTests {

    private var cropFixture: URL { fixtureURLs[0] }   // shot_1_portrait.mov

    // MARK: Transform math (pure, fast) — the actual numbers, asserted

    func testCropZoomTransformMath() throws {
        DiagFile.reset()
        DiagFile.log("========== CROP-ZOOM TRANSFORM MATH ==========")
        let display = CGSize(width: 1080, height: 1920)
        func t(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGAffineTransform {
            CompositionAssembler.cropZoomTransform(
                for: NormalizedRect(x: x, y: y, width: w, height: h), displaySize: display)
        }
        func log(_ label: String, _ m: CGAffineTransform) {
            DiagFile.log("  \(label): [a=\(m.a) b=\(m.b) c=\(m.c) d=\(m.d) tx=\(m.tx) ty=\(m.ty)]")
        }

        let full = t(0, 0, 1, 1)
        log("full-frame (0,0,1,1)", full)
        XCTAssertTrue(full.isIdentity, "Full-frame crop MUST be identity (byte-for-byte == no crop).")

        let left = t(0, 0, 0.5, 1)
        log("left-half (0,0,0.5,1)", left)
        assertTransform(left, a: 2, d: 1, tx: 0, ty: 0)

        let right = t(0.5, 0, 0.5, 1)
        log("right-half (0.5,0,0.5,1)", right)
        assertTransform(right, a: 2, d: 1, tx: -1080, ty: 0)

        let centre = t(0.25, 0.25, 0.5, 0.5)
        log("centre (0.25,0.25,0.5,0.5)", centre)
        assertTransform(centre, a: 2, d: 2, tx: -540, ty: -960)

        // Degenerate rects fall back to identity (no divide-by-zero / NaN).
        XCTAssertTrue(t(0, 0, 0, 1).isIdentity, "Zero-width rect → identity fallback.")
        XCTAssertTrue(t(0, 0, 1, 0).isIdentity, "Zero-height rect → identity fallback.")
        DiagFile.log("========== END TRANSFORM MATH ==========")
    }

    // MARK: Horizontal crops — match reconstruction, disambiguate left/right

    func testCoverageCropZoom_HorizontalCropsMatchReconstruction() async throws {
        let hold = 2.5, sampleT = 1.25
        let leftRect = NormalizedRect(x: 0, y: 0, width: 0.5, height: 1)
        let rightRect = NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1)

        let uURL = try await renderEngine(makeLinearSinglePlan(holdSeconds: hold), name: "u_uncropped.mov")
        let lURL = try await renderEngine(makeCropZoomPlan(cropRect: leftRect, holdSeconds: hold), name: "c_left.mov")
        let rURL = try await renderEngine(makeCropZoomPlan(cropRect: rightRect, holdSeconds: hold), name: "c_right.mov")

        // (a) orientation guard — on CROPPED segments.
        for (label, url) in [("left", lURL), ("right", rURL)] {
            let e = try await postTransformExtent(of: url)
            XCTAssertEqual(Int(e.width), 1080, "Cropped \(label) output width should be 1080; got \(e.width)x\(e.height)")
            XCTAssertEqual(Int(e.height), 1920, "Cropped \(label) output height should be 1920; got \(e.width)x\(e.height)")
        }

        let imgU = try await cgImage(of: uURL, atSeconds: sampleT)
        let imgL = try await cgImage(of: lURL, atSeconds: sampleT)
        let imgR = try await cgImage(of: rURL, atSeconds: sampleT)

        let (cols, rows) = (16, 32)
        let sigL = try signature(of: imgL, crop: nil, cols: cols, rows: rows)
        let sigR = try signature(of: imgR, crop: nil, cols: cols, rows: rows)
        let reconL = try signature(of: imgU, crop: leftRect, cols: cols, rows: rows)
        let reconR = try signature(of: imgU, crop: rightRect, cols: cols, rows: rows)
        let sigU = try signature(of: imgU, crop: nil, cols: cols, rows: rows)

        let cLL = correlation(sigL, reconL)   // left render vs left reconstruction (should be high)
        let cLR = correlation(sigL, reconR)   // left render vs right reconstruction (should be lower)
        let cRR = correlation(sigR, reconR)
        let cRL = correlation(sigR, reconL)
        let cLU = correlation(sigL, sigU)     // left render vs uncropped (should be lower than cLL if structured)
        let lrSim = correlation(reconL, reconR)  // how different the two halves are

        DiagFile.log("\n--- HORIZONTAL CROP CORRELATIONS ---")
        DiagFile.log(String(format: "  left:  vs reconLeft=%.3f  vs reconRight=%.3f  vs uncropped=%.3f", cLL, cLR, cLU))
        DiagFile.log(String(format: "  right: vs reconRight=%.3f  vs reconLeft=%.3f", cRR, cRL))
        DiagFile.log(String(format: "  reconLeft vs reconRight (half-similarity)=%.3f", lrSim))

        // (b) crop happened with correct geometry: each render matches its own
        //     independently reconstructed half.
        XCTAssertGreaterThan(cLL, 0.85, "Left crop render does not match a reconstructed left-half crop (corr \(cLL)).")
        XCTAssertGreaterThan(cRR, 0.85, "Right crop render does not match a reconstructed right-half crop (corr \(cRR)).")

        // not black / not a flat fill.
        assertRealContent(sigL, label: "left crop")
        assertRealContent(sigR, label: "right crop")

        // directional disambiguation (not mirrored, not ignoring x): only assert
        // when the two halves are actually distinguishable in this footage.
        if lrSim < 0.97 {
            XCTAssertGreaterThan(cLL, cLR, "Left render is not closer to the left half than the right half — crop x may be mirrored/ignored.")
            XCTAssertGreaterThan(cRR, cRL, "Right render is not closer to the right half than the left half — crop x may be mirrored/ignored.")
        } else {
            DiagFile.log("  [skipped directional assertion: halves too similar (lrSim=\(lrSim))]")
        }
    }

    // MARK: Centre punch-in — aspect-matched uniform 2× zoom (exercises tx AND ty)

    func testCoverageCropZoom_CenterPunchInMatchesReconstruction() async throws {
        let hold = 2.5, sampleT = 1.25
        let centre = NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

        let uURL = try await renderEngine(makeLinearSinglePlan(holdSeconds: hold), name: "u_for_centre.mov")
        let cURL = try await renderEngine(makeCropZoomPlan(cropRect: centre, holdSeconds: hold), name: "c_centre.mov")

        let e = try await postTransformExtent(of: cURL)
        XCTAssertEqual(Int(e.width), 1080, "Centre punch-in width should be 1080; got \(e.width)x\(e.height)")
        XCTAssertEqual(Int(e.height), 1920, "Centre punch-in height should be 1920; got \(e.width)x\(e.height)")

        let imgU = try await cgImage(of: uURL, atSeconds: sampleT)
        let imgC = try await cgImage(of: cURL, atSeconds: sampleT)
        let (cols, rows) = (16, 32)
        let sigC = try signature(of: imgC, crop: nil, cols: cols, rows: rows)
        let reconC = try signature(of: imgU, crop: centre, cols: cols, rows: rows)
        let sigU = try signature(of: imgU, crop: nil, cols: cols, rows: rows)

        let cCC = correlation(sigC, reconC)
        let cCU = correlation(sigC, sigU)
        DiagFile.log("\n--- CENTRE PUNCH-IN CORRELATIONS ---")
        DiagFile.log(String(format: "  centre render vs reconCentre=%.3f  vs uncropped=%.3f", cCC, cCU))

        XCTAssertGreaterThan(cCC, 0.85, "Centre punch-in render does not match a reconstructed centre crop (corr \(cCC)). A wrong/sign-flipped ty would push content off-canvas and fail this.")
        assertRealContent(sigC, label: "centre punch-in")
    }

    // MARK: Full-frame crop == linear render (nil-path-unchanged, at the identity boundary)

    func testCoverageFullFrameCropEqualsLinearRender() async throws {
        let hold = 2.5, sampleT = 1.25
        let fullFrame = NormalizedRect(x: 0, y: 0, width: 1, height: 1)

        let linURL = try await renderEngine(makeLinearSinglePlan(holdSeconds: hold), name: "linear_baseline.mov")
        let fullURL = try await renderEngine(makeCropZoomPlan(cropRect: fullFrame, holdSeconds: hold), name: "fullframe_crop.mov")

        for (label, url) in [("linear", linURL), ("full-frame", fullURL)] {
            let e = try await postTransformExtent(of: url)
            XCTAssertEqual(Int(e.width), 1080, "\(label) width should be 1080; got \(e.width)x\(e.height)")
            XCTAssertEqual(Int(e.height), 1920, "\(label) height should be 1920; got \(e.width)x\(e.height)")
        }

        let imgLin = try await cgImage(of: linURL, atSeconds: sampleT)
        let imgFull = try await cgImage(of: fullURL, atSeconds: sampleT)
        let sigLin = try signature(of: imgLin, crop: nil, cols: 24, rows: 48)
        let sigFull = try signature(of: imgFull, crop: nil, cols: 24, rows: 48)
        let corr = correlation(sigLin, sigFull)
        DiagFile.log("\n--- FULL-FRAME vs LINEAR ---")
        DiagFile.log(String(format: "  full-frame crop vs linear correlation=%.4f", corr))
        XCTAssertGreaterThan(corr, 0.99, "A full-frame (0,0,1,1) crop must render identically to the linear path (identity transform); corr=\(corr).")
    }

    // MARK: Full pipeline (engine + VideoExportService) with a crop stays portrait

    func testCoverageCropZoom_FullPipelineExportIsPortrait() async throws {
        let hold = 3.0
        let plan = makeCropZoomPlan(
            cropRect: NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            holdSeconds: hold)
        let engineURL = workDir.appendingPathComponent("crop_pipeline_engine.mov")
        let engine = AssemblyEngine()
        _ = try await engine.assembleFromOrderedURLs(
            plan: plan, takeURLs: [cropFixture], musicURL: nil, outputURL: engineURL, progress: { _ in })
        let exportURL = try await runExportService(assembledURL: engineURL, plan: plan)

        let e = try await postTransformExtent(of: exportURL)
        XCTAssertEqual(Int(e.width), 1080,
                       "Full-pipeline cropped export width should be 1080 (portrait); got \(e.width)x\(e.height)")
        XCTAssertEqual(Int(e.height), 1920,
                       "Full-pipeline cropped export height should be 1920 (portrait); got \(e.width)x\(e.height)")
        XCTAssertGreaterThan(e.height, e.width, "Cropped full pipeline must stay portrait. Got \(e.width)x\(e.height).")
    }

    // MARK: - Crop-render helpers

    private func assertTransform(_ m: CGAffineTransform, a: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(m.a, a, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(m.b, 0, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(m.c, 0, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(m.d, d, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(m.tx, tx, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(m.ty, ty, accuracy: 1e-9, file: file, line: line)
    }

    private func renderEngine(_ plan: FilmmakingPlan, name: String) async throws -> URL {
        let url = workDir.appendingPathComponent(name)
        let engine = AssemblyEngine()
        _ = try await engine.assembleFromOrderedURLs(
            plan: plan, takeURLs: [cropFixture], musicURL: nil, outputURL: url, progress: { _ in })
        return url
    }

    private func makeLinearSinglePlan(holdSeconds: Double) -> FilmmakingPlan {
        let shot = Shot(
            shotNumber: 1, shotType: "wide", directionText: "linear",
            cameraPlacement: "anywhere", actorDirection: "stand still", dialogueDirection: nil,
            estimatedDurationSeconds: Int(holdSeconds), soloShootable: true, audioRisk: "low",
            recommendedHoldSeconds: holdSeconds, transitionInType: nil, transitionOutType: nil,
            pacingRole: nil, audioTreatment: .dialoguePriority, editingNote: nil)
        return singleShotPlan(shot)
    }

    private func makeCropZoomPlan(cropRect: NormalizedRect, holdSeconds: Double) -> FilmmakingPlan {
        let shot = Shot(
            shotNumber: 1, shotType: "wide", directionText: "crop test",
            cameraPlacement: "anywhere", actorDirection: "stand still", dialogueDirection: nil,
            estimatedDurationSeconds: Int(holdSeconds), soloShootable: true, audioRisk: "low",
            recommendedHoldSeconds: holdSeconds, transitionInType: nil, transitionOutType: nil,
            pacingRole: nil, audioTreatment: .dialoguePriority, editingNote: nil,
            coverage: CoverageRole(beatId: 1, kind: .cropZoomSource, lineRuns: [
                LineRun(speaker: "A", lineText: "a", estimatedSeconds: 1.0,
                        angle: .cropZoom(region: cropRect))
            ]))
        return singleShotPlan(shot)
    }

    private func singleShotPlan(_ shot: Shot) -> FilmmakingPlan {
        let scene = FilmScene(sceneNumber: 1, description: "crop", locationDescription: "anywhere",
                              castCount: 1, shots: [shot])
        return FilmmakingPlan(
            logline: "crop test", estimatedDurationMinutes: 1, estimatedTotalShootMinutes: 5,
            scenes: [scene], cast: [], requiredStoryProps: [], optionalSetupHelpers: [],
            locationRequirements: [], musicMood: "test")
    }

    private func cgImage(of url: URL, atSeconds seconds: Double) async throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
        gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
        return try await gen.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    }

    /// Box-averaged RGB signature of a CGImage (optionally of a normalized sub-rect
    /// of it, stretched to fill). Drawing through ONE CGContext means render- and
    /// reconstruction-signatures share the same vertical-origin handling, so the
    /// flip cancels in any signature-vs-signature correlation. Using a sub-rect
    /// crop here mirrors the engine's exact-fill (sub-rect → full canvas).
    private func signature(of cgImage: CGImage, crop: NormalizedRect?, cols: Int, rows: Int) throws -> [Double] {
        let source: CGImage
        if let crop = crop {
            let W = cgImage.width, H = cgImage.height
            let r = CGRect(x: crop.x * Double(W), y: crop.y * Double(H),
                           width: crop.width * Double(W), height: crop.height * Double(H)).integral
            guard let c = cgImage.cropping(to: r) else {
                throw NSError(domain: "Signature", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "cropping(to:) failed for \(r)"])
            }
            source = c
        } else {
            source = cgImage
        }
        var data = [UInt8](repeating: 0, count: cols * rows * 4)
        guard let ctx = CGContext(
            data: &data, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: cols * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw NSError(domain: "Signature", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create downscale context"])
        }
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: cols, height: rows))
        var out = [Double]()
        out.reserveCapacity(cols * rows * 3)
        for i in 0..<(cols * rows) {
            out.append(Double(data[i * 4]))
            out.append(Double(data[i * 4 + 1]))
            out.append(Double(data[i * 4 + 2]))
        }
        return out
    }

    /// Pearson correlation; 0 if either signature is constant.
    private func correlation(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = Double(a.count)
        let ma = a.reduce(0, +) / n
        let mb = b.reduce(0, +) / n
        var num = 0.0, da = 0.0, db = 0.0
        for i in 0..<a.count {
            let x = a[i] - ma, y = b[i] - mb
            num += x * y; da += x * x; db += y * y
        }
        let denom = (da * db).squareRoot()
        return denom == 0 ? 0 : num / denom
    }

    /// Asserts a crop render is real content: not near-black and not a flat fill
    /// (guards against the crop transform producing an empty/garbage frame).
    private func assertRealContent(_ sig: [Double], label: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let maxChannel = sig.max() ?? 0
        XCTAssertGreaterThan(maxChannel, 16, "\(label) render is near-black (max channel \(maxChannel)).",
                             file: file, line: line)
        var luma = [Double]()
        var i = 0
        while i + 2 < sig.count { luma.append(0.299 * sig[i] + 0.587 * sig[i + 1] + 0.114 * sig[i + 2]); i += 3 }
        let n = Double(luma.count)
        let m = luma.reduce(0, +) / n
        let std = (luma.reduce(0) { $0 + ($1 - m) * ($1 - m) } / n).squareRoot()
        XCTAssertGreaterThan(std, 2.0, "\(label) render is a flat fill (luma stddev \(std)) — likely garbage, not cropped content.",
                             file: file, line: line)
    }
}
