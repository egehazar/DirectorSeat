import XCTest
import CoreMedia
@testable import DirectorSeat

/// Phase 2 (intelligent-cutting epic): the Layer-1 intercut algorithm in
/// TimelineBuilder. These tests ARE the behavioral spec for the algorithm:
/// proportional placement (relative weights scaled onto the take's real
/// duration, no diarization), the jitter floor + merge rule, angle→segment
/// mapping with audio-continuous crop-zoom sub-slices, and — critically — the
/// guarantee that a coverage-nil shot still emits exactly one segment so the
/// linear path is byte-for-byte unchanged.
final class CoverageIntercutTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoverageIntercutTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Builders

    private func makeTakeFile(name: String) -> URL {
        let url = tempDir.appendingPathComponent("\(name).mov")
        FileManager.default.createFile(atPath: url.path, contents: Data([0x00]))
        return url
    }

    private func makeTake(global: Int, durationSeconds: Double) -> SelectedTake {
        SelectedTake(shotGlobalNumber: global,
                     sourceURL: makeTakeFile(name: "take_\(global)"),
                     duration: CMTime.seconds(durationSeconds))
    }

    private func coveredShot(
        number: Int,
        recommendedHold: Double?,
        kind: CoverageKind = .cropZoomSource,
        runs: [LineRun]
    ) -> Shot {
        Shot(shotNumber: number, shotType: "wide", directionText: "t",
             cameraPlacement: "x", actorDirection: "y", dialogueDirection: nil,
             estimatedDurationSeconds: 5, soloShootable: true, audioRisk: "low",
             recommendedHoldSeconds: recommendedHold, transitionInType: nil,
             transitionOutType: nil, pacingRole: nil, audioTreatment: .dialoguePriority,
             editingNote: nil,
             coverage: CoverageRole(beatId: 1, kind: kind, lineRuns: runs))
    }

    private func linearShot(number: Int, recommendedHold: Double? = nil) -> Shot {
        Shot(shotNumber: number, shotType: "wide", directionText: "t",
             cameraPlacement: "x", actorDirection: "y", dialogueDirection: nil,
             estimatedDurationSeconds: 5, soloShootable: true, audioRisk: "low",
             recommendedHoldSeconds: recommendedHold, transitionInType: nil,
             transitionOutType: nil, pacingRole: nil, audioTreatment: .dialoguePriority,
             editingNote: nil)
    }

    private func plan(_ shots: [Shot]) -> FilmmakingPlan {
        FilmmakingPlan(logline: "t", estimatedDurationMinutes: 1, estimatedTotalShootMinutes: 5,
                       scenes: [FilmScene(sceneNumber: 1, description: "s", locationDescription: "l",
                                          castCount: 2, shots: shots)],
                       cast: [], requiredStoryProps: [], optionalSetupHelpers: [],
                       locationRequirements: [], musicMood: "t")
    }

    private func leftHalf() -> CoverageAngle {
        .cropZoom(region: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1))
    }
    private func rightHalf() -> CoverageAngle {
        .cropZoom(region: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    // MARK: - 1. Three balanced runs → three proportional segments summing to the take

    func test01_ThreeRunsProduceProportionalSegmentsSummingToTake() throws {
        // Weights 2:1:1 over a 12s hold → 6s, 3s, 3s. All ≥ floor.
        let shot = coveredShot(number: 1, recommendedHold: 12.0, runs: [
            LineRun(speaker: "A", lineText: "a", estimatedSeconds: 2.0, angle: leftHalf()),
            LineRun(speaker: "B", lineText: "b", estimatedSeconds: 1.0, angle: rightHalf()),
            LineRun(speaker: "A", lineText: "c", estimatedSeconds: 1.0, angle: .wide),
        ])
        let take = makeTake(global: 1, durationSeconds: 12.0)
        let timeline = try TimelineBuilder().build(plan: plan([shot]), takes: [take], hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.duration, CMTime.seconds(6.0))
        XCTAssertEqual(timeline.segments[1].timelineTimeRange.duration, CMTime.seconds(3.0))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange.duration, CMTime.seconds(3.0))

        // Contiguous on the timeline, starting at 0.
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.start, .zero)
        XCTAssertEqual(timeline.segments[1].timelineTimeRange.start, CMTime.seconds(6.0))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange.start, CMTime.seconds(9.0))

        // Sum is EXACTLY the hold-trimmed beat duration.
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(12.0))
        let sum = timeline.segments.reduce(CMTime.zero) { $0 + $1.timelineTimeRange.duration }
        XCTAssertEqual(sum, CMTime.seconds(12.0))

        // All segments belong to the beat's global number and one track.
        XCTAssertTrue(timeline.segments.allSatisfy { $0.shotGlobalNumber == 1 })
        XCTAssertTrue(timeline.segments.allSatisfy { $0.trackIndex == 0 })
    }

    // MARK: - 2. Sub-floor run merges; no segment below the floor

    func test02_SubFloorRunMergesAndNoSegmentBelowFloor() throws {
        // Weights 5 : 0.2 : 5 over a 10.2s hold → ~5.0, ~0.2, ~5.0.
        // The 0.2s middle run is below the 1.2s floor; it must be absorbed into
        // the PREVIOUS angle (the previous angle holds through the short run),
        // yielding two segments, none shorter than the floor.
        let shot = coveredShot(number: 1, recommendedHold: 10.2, runs: [
            LineRun(speaker: "A", lineText: "a", estimatedSeconds: 5.0, angle: leftHalf()),
            LineRun(speaker: "B", lineText: "b", estimatedSeconds: 0.2, angle: rightHalf()),
            LineRun(speaker: "A", lineText: "c", estimatedSeconds: 5.0, angle: .wide),
        ])
        let take = makeTake(global: 1, durationSeconds: 10.2)
        let timeline = try TimelineBuilder().build(plan: plan([shot]), takes: [take], hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 2, "Sub-floor run must merge, not emit a 3rd micro-segment")
        let floor = CMTime.seconds(AssemblyConstants.minCoverageSegmentSeconds)
        for seg in timeline.segments {
            XCTAssertGreaterThanOrEqual(seg.timelineTimeRange.duration.seconds,
                                        floor.seconds - 1e-6,
                                        "No intercut segment may be shorter than the floor")
        }
        // First (left) angle absorbed the short right run: ~5.2s; second ~5.0s.
        XCTAssertEqual(timeline.segments[0].cropRect, NormalizedRect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.duration.seconds, 5.2, accuracy: 0.01)
        XCTAssertNil(timeline.segments[1].cropRect, "Second segment is the .wide run")
        // Still sums to exactly the beat.
        let sum = timeline.segments.reduce(CMTime.zero) { $0 + $1.timelineTimeRange.duration }
        XCTAssertEqual(sum, CMTime.seconds(10.2))
    }

    // MARK: - 3. cropZoom sub-slices reference the same wide URL with contiguous source ranges

    func test03_CropZoomSubSlicesShareWideURLContiguously() throws {
        let shot = coveredShot(number: 1, recommendedHold: 9.0, runs: [
            LineRun(speaker: "A", lineText: "a", estimatedSeconds: 1.0, angle: leftHalf()),
            LineRun(speaker: "B", lineText: "b", estimatedSeconds: 1.0, angle: rightHalf()),
            LineRun(speaker: "A", lineText: "c", estimatedSeconds: 1.0, angle: .wide),
        ])
        let take = makeTake(global: 1, durationSeconds: 9.0)
        let timeline = try TimelineBuilder().build(plan: plan([shot]), takes: [take], hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 3)
        // All three reference the SAME wide URL.
        XCTAssertTrue(timeline.segments.allSatisfy { $0.sourceURL == take.sourceURL })
        // Source ranges are contiguous (so the wide's audio reconstructs continuously).
        var cursor = CMTime.zero
        for seg in timeline.segments {
            XCTAssertEqual(seg.sourceTimeRange.start, cursor, "crop-zoom source slices must be contiguous")
            cursor = cursor + seg.sourceTimeRange.duration
        }
        XCTAssertEqual(cursor, CMTime.seconds(9.0), "source slices cover the whole take")
        // Crop rects: left, right, then nil (wide).
        XCTAssertEqual(timeline.segments[0].cropRect, NormalizedRect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(timeline.segments[1].cropRect, NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1))
        XCTAssertNil(timeline.segments[2].cropRect)
    }

    // MARK: - 4. coverage == nil still emits exactly one segment (linear path intact)

    func test04_CoverageNilEmitsExactlyOneSegment() throws {
        let shot = linearShot(number: 1, recommendedHold: 5.0)
        let take = makeTake(global: 1, durationSeconds: 5.0)
        let timeline = try TimelineBuilder().build(plan: plan([shot]), takes: [take], hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 1)
        let seg = timeline.segments[0]
        XCTAssertNil(seg.cropRect, "Linear segment carries no crop rect")
        XCTAssertEqual(seg.sourceURL, take.sourceURL)
        XCTAssertEqual(seg.sourceTimeRange, CMTimeRange(start: .zero, duration: CMTime.seconds(5.0)))
        XCTAssertEqual(seg.timelineTimeRange, CMTimeRange(start: .zero, duration: CMTime.seconds(5.0)))
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(5.0))
    }

    // MARK: - 5. Coverage beat mixed with linear shots — segment counts and ordering

    func test05_CoverageBeatAmongLinearShots() throws {
        // Linear #1 (5s), covered #2 (2 runs over 8s → 4s + 4s), linear #3 (5s).
        let s1 = linearShot(number: 1, recommendedHold: 5.0)
        let s2 = coveredShot(number: 2, recommendedHold: 8.0, runs: [
            LineRun(speaker: "A", lineText: "a", estimatedSeconds: 1.0, angle: leftHalf()),
            LineRun(speaker: "B", lineText: "b", estimatedSeconds: 1.0, angle: rightHalf()),
        ])
        let s3 = linearShot(number: 3, recommendedHold: 5.0)
        let takes = [makeTake(global: 1, durationSeconds: 5.0),
                     makeTake(global: 2, durationSeconds: 8.0),
                     makeTake(global: 3, durationSeconds: 5.0)]
        let timeline = try TimelineBuilder().build(plan: plan([s1, s2, s3]), takes: takes, hasMusicURL: false)

        // 1 + 2 + 1 = 4 segments.
        XCTAssertEqual(timeline.segments.count, 4)
        XCTAssertEqual(timeline.segments.map { $0.shotGlobalNumber }, [1, 2, 2, 3])
        // Timeline: 0–5 (s1), 5–9 (s2a), 9–13 (s2b), 13–18 (s3).
        XCTAssertEqual(timeline.segments[0].timelineTimeRange, CMTimeRange(start: .zero, duration: CMTime.seconds(5)))
        XCTAssertEqual(timeline.segments[1].timelineTimeRange, CMTimeRange(start: CMTime.seconds(5), duration: CMTime.seconds(4)))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange, CMTimeRange(start: CMTime.seconds(9), duration: CMTime.seconds(4)))
        XCTAssertEqual(timeline.segments[3].timelineTimeRange, CMTimeRange(start: CMTime.seconds(13), duration: CMTime.seconds(5)))
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(18))
        // All on one track (cuts only).
        XCTAssertTrue(timeline.segments.allSatisfy { $0.trackIndex == 0 })
    }

    // MARK: - 6. separateAngle run references the other take; member shot emits no standalone segment

    func test06_SeparateAngleReferencesOtherTakeAndMemberIsNotStandalone() throws {
        // Driver beat #1 (cropZoomSource, 9s) whose 2nd run cuts to a separate
        // angle shot #2. Shot #2 is a separate-angle MEMBER → no standalone segment.
        let driver = coveredShot(number: 1, recommendedHold: 9.0, runs: [
            LineRun(speaker: "A", lineText: "a", estimatedSeconds: 1.0, angle: leftHalf()),
            LineRun(speaker: "B", lineText: "b", estimatedSeconds: 1.0, angle: .separateAngle(globalShotNumber: 2)),
            LineRun(speaker: "A", lineText: "c", estimatedSeconds: 1.0, angle: .wide),
        ])
        let member = Shot(shotNumber: 2, shotType: "close-up", directionText: "t",
                          cameraPlacement: "x", actorDirection: "y", dialogueDirection: nil,
                          estimatedDurationSeconds: 9, soloShootable: true, audioRisk: "low",
                          recommendedHoldSeconds: 9.0, transitionInType: nil, transitionOutType: nil,
                          pacingRole: nil, audioTreatment: .dialoguePriority, editingNote: nil,
                          coverage: CoverageRole(beatId: 1, kind: .separateAngle, lineRuns: []))
        let takes = [makeTake(global: 1, durationSeconds: 9.0),
                     makeTake(global: 2, durationSeconds: 9.0)]
        let timeline = try TimelineBuilder().build(plan: plan([driver, member]), takes: takes, hasMusicURL: false)

        // 3 intercut segments from the driver; the member contributes none of its own.
        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertTrue(timeline.segments.allSatisfy { $0.shotGlobalNumber == 1 })
        // Middle segment points at shot #2's take; others at the wide (#1).
        XCTAssertEqual(timeline.segments[0].sourceURL, takes[0].sourceURL)
        XCTAssertEqual(timeline.segments[1].sourceURL, takes[1].sourceURL, "separateAngle cuts to the other take")
        XCTAssertEqual(timeline.segments[2].sourceURL, takes[0].sourceURL)
        XCTAssertNil(timeline.segments[1].cropRect, "separateAngle is not a crop")
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(9.0))
    }

    // MARK: - 7. Whole beat shorter than the floor — single segment (floor unsatisfiable)

    func test07_WholeBeatShorterThanFloorEmitsSingleSegment() throws {
        // Two runs but only 0.8s total (< 1.2s floor): cannot satisfy the floor;
        // must collapse to a single segment rather than emit sub-floor pieces.
        let shot = coveredShot(number: 1, recommendedHold: 0.8, runs: [
            LineRun(speaker: "A", lineText: "a", estimatedSeconds: 1.0, angle: leftHalf()),
            LineRun(speaker: "B", lineText: "b", estimatedSeconds: 1.0, angle: rightHalf()),
        ])
        let take = makeTake(global: 1, durationSeconds: 0.8)
        let timeline = try TimelineBuilder().build(plan: plan([shot]), takes: [take], hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 1, "A sub-floor beat collapses to one segment")
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.duration, CMTime.seconds(0.8))
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(0.8))
    }
}
