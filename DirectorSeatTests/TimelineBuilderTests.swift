import XCTest
import CoreMedia
@testable import DirectorSeat

final class TimelineBuilderTests: XCTestCase {

    // Holds temp source files we create per test so they exist on disk
    // for the TimelineBuilder pre-flight check.
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimelineBuilderTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeTakeFile(name: String) -> URL {
        let url = tempDir.appendingPathComponent("\(name).mov")
        FileManager.default.createFile(atPath: url.path, contents: Data([0x00]))
        return url
    }

    private func makeTake(global: Int, durationSeconds: Double) -> SelectedTake {
        SelectedTake(
            shotGlobalNumber: global,
            sourceURL: makeTakeFile(name: "take_\(global)"),
            duration: CMTime.seconds(durationSeconds)
        )
    }

    // Builds a Shot with editorial fields configurable. Defaults match a "legacy" plan.
    private func makeShot(
        number: Int,
        recommendedHold: Double? = nil,
        transitionIn: TransitionType? = nil,
        transitionOut: TransitionType? = nil,
        audio: AudioTreatment? = nil
    ) -> Shot {
        Shot(
            shotNumber: number,
            shotType: "wide",
            directionText: "test",
            cameraPlacement: "anywhere",
            actorDirection: "stand still",
            dialogueDirection: nil,
            estimatedDurationSeconds: 5,
            soloShootable: true,
            audioRisk: "low",
            recommendedHoldSeconds: recommendedHold,
            transitionInType: transitionIn,
            transitionOutType: transitionOut,
            pacingRole: nil,
            audioTreatment: audio,
            editingNote: nil
        )
    }

    private func makePlan(
        scenes: [FilmScene]
    ) -> FilmmakingPlan {
        FilmmakingPlan(
            logline: "test plan",
            estimatedDurationMinutes: 1,
            estimatedTotalShootMinutes: 5,
            scenes: scenes,
            cast: [],
            requiredStoryProps: [],
            optionalSetupHelpers: [],
            locationRequirements: [],
            musicMood: "test"
        )
    }

    private func makeScene(
        number: Int,
        shots: [Shot],
        musicCueIn: Bool? = nil,
        musicCueOut: Bool? = nil
    ) -> FilmScene {
        FilmScene(
            sceneNumber: number,
            description: "scene \(number)",
            locationDescription: "anywhere",
            castCount: 1,
            shots: shots,
            pacingProfile: nil,
            musicCueIn: musicCueIn,
            musicCueOut: musicCueOut
        )
    }

    // MARK: - Test 1: Three-shot all-cuts, full-take holds
    func test01_ThreeShotAllCutsProducesContiguousSegments() throws {
        let shots = (1...3).map { makeShot(number: $0, recommendedHold: 5.0, audio: .dialoguePriority) }
        let plan = makePlan(scenes: [makeScene(number: 1, shots: shots)])
        let takes = (1...3).map { makeTake(global: $0, durationSeconds: 5.0) }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertEqual(timeline.transitions.count, 0)

        XCTAssertEqual(timeline.segments[0].timelineTimeRange.start, .zero)
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.duration, CMTime.seconds(5.0))
        XCTAssertEqual(timeline.segments[1].timelineTimeRange.start, CMTime.seconds(5.0))
        XCTAssertEqual(timeline.segments[1].timelineTimeRange.duration, CMTime.seconds(5.0))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange.start, CMTime.seconds(10.0))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange.duration, CMTime.seconds(5.0))

        // Cut-only films stay on a single video track so AVFoundation never
        // sees gaps mid-track (iOS 26 MediaValidator rejects those exports).
        XCTAssertEqual(timeline.segments[0].trackIndex, 0)
        XCTAssertEqual(timeline.segments[1].trackIndex, 0)
        XCTAssertEqual(timeline.segments[2].trackIndex, 0)

        // Source ranges fully use the take from start
        for seg in timeline.segments {
            XCTAssertEqual(seg.sourceTimeRange.start, .zero)
            XCTAssertEqual(seg.sourceTimeRange.duration, CMTime.seconds(5.0))
        }

        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(15.0))
    }

    // MARK: - Test 2: Dissolve between shots 2 and 3
    func test02_DissolveBetweenShotsProducesCrossfade() throws {
        let s1 = makeShot(number: 1, recommendedHold: 5.0)
        let s2 = makeShot(number: 2, recommendedHold: 5.0, transitionOut: .dissolve)
        let s3 = makeShot(number: 3, recommendedHold: 5.0)
        let plan = makePlan(scenes: [makeScene(number: 1, shots: [s1, s2, s3])])
        let takes = (1...3).map { makeTake(global: $0, durationSeconds: 5.0) }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)

        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertEqual(timeline.transitions.count, 1)

        let crossfade = CMTime.seconds(AssemblyConstants.crossfadeDuration)

        // Segment 0/1 unchanged; segment 2 starts 0.7s before segment 1 ends.
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.start, .zero)
        XCTAssertEqual(timeline.segments[1].timelineTimeRange.start, CMTime.seconds(5.0))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange.start, CMTime.seconds(10.0) - crossfade)

        let t = timeline.transitions[0]
        XCTAssertEqual(t.kind, .crossfade)
        XCTAssertEqual(t.duration, crossfade)
        XCTAssertEqual(t.timeRange.duration, crossfade)
        XCTAssertEqual(t.outgoingSegmentIndex, 1)
        XCTAssertEqual(t.incomingSegmentIndex, 2)
        XCTAssertEqual(t.timeRange.start, CMTime.seconds(10.0) - crossfade)
        XCTAssertEqual(t.timeRange.end, CMTime.seconds(10.0))

        // Total film: 5 + 5 + 5 - 0.7 = 14.3
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(15.0) - crossfade)
    }

    // MARK: - Test 3: Hold 3s, take 5s → trim to 3s
    func test03_HoldShorterThanTakeTrimsFromEnd() throws {
        let s1 = makeShot(number: 1, recommendedHold: 5.0)
        let s2 = makeShot(number: 2, recommendedHold: 3.0)
        let s3 = makeShot(number: 3, recommendedHold: 5.0)
        let plan = makePlan(scenes: [makeScene(number: 1, shots: [s1, s2, s3])])
        let takes = (1...3).map { makeTake(global: $0, durationSeconds: 5.0) }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)

        let s2Segment = timeline.segments[1]
        XCTAssertEqual(s2Segment.sourceTimeRange.start, .zero)
        XCTAssertEqual(s2Segment.sourceTimeRange.duration, CMTime.seconds(3.0))
        XCTAssertEqual(s2Segment.timelineTimeRange.duration, CMTime.seconds(3.0))

        // No "take shorter than hold" warning expected
        XCTAssertFalse(timeline.diagnostics.contains { d in
            d.severity == .warning && d.shotGlobalNumber == 2 && d.message.contains("shorter")
        })
    }

    // MARK: - Test 4: Hold 3s, take 1.5s → use full take, emit warning
    func test04_HoldLongerThanTakeUsesFullTakeAndWarns() throws {
        let s1 = makeShot(number: 1, recommendedHold: 5.0)
        let s2 = makeShot(number: 2, recommendedHold: 3.0)
        let s3 = makeShot(number: 3, recommendedHold: 5.0)
        let plan = makePlan(scenes: [makeScene(number: 1, shots: [s1, s2, s3])])
        let takes = [
            makeTake(global: 1, durationSeconds: 5.0),
            makeTake(global: 2, durationSeconds: 1.5),
            makeTake(global: 3, durationSeconds: 5.0),
        ]

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)

        let s2Segment = timeline.segments[1]
        XCTAssertEqual(s2Segment.sourceTimeRange.duration, CMTime.seconds(1.5))
        XCTAssertEqual(s2Segment.timelineTimeRange.duration, CMTime.seconds(1.5))

        let warnings = timeline.diagnostics.filter { d in
            d.severity == .warning && d.shotGlobalNumber == 2 && d.message.contains("shorter than recommendedHoldSeconds")
        }
        XCTAssertEqual(warnings.count, 1, "Expected one warning about take shorter than recommendedHoldSeconds")
    }

    // MARK: - Test 5: Alternating audio treatments → boundary ramps inserted
    func test05_AlternatingAudioTreatmentsProducesBoundaryRamps() throws {
        let s1 = makeShot(number: 1, recommendedHold: 5.0, audio: .dialoguePriority)
        let s2 = makeShot(number: 2, recommendedHold: 5.0, audio: .musicPriority)
        let s3 = makeShot(number: 3, recommendedHold: 5.0, audio: .dialoguePriority)
        let plan = makePlan(scenes: [makeScene(number: 1, shots: [s1, s2, s3])])
        let takes = (1...3).map { makeTake(global: $0, durationSeconds: 5.0) }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)

        // Expect 5 audio regions: 3 main + 2 boundary ramps
        XCTAssertEqual(timeline.audioRegions.count, 5)

        let main1 = timeline.audioRegions[0]
        let ramp1 = timeline.audioRegions[1]
        let main2 = timeline.audioRegions[2]
        let ramp2 = timeline.audioRegions[3]
        let main3 = timeline.audioRegions[4]

        XCTAssertEqual(main1.videoVolume, .constant(AssemblyConstants.dialoguePriorityVideoVolume))
        XCTAssertEqual(main1.musicVolume, .constant(AssemblyConstants.dialoguePriorityMusicVolume))
        XCTAssertEqual(main2.videoVolume, .constant(AssemblyConstants.musicPriorityVideoVolume))
        XCTAssertEqual(main2.musicVolume, .constant(AssemblyConstants.musicPriorityMusicVolume))
        XCTAssertEqual(main3.videoVolume, .constant(AssemblyConstants.dialoguePriorityVideoVolume))
        XCTAssertEqual(main3.musicVolume, .constant(AssemblyConstants.dialoguePriorityMusicVolume))

        // Boundary ramp 1: dialogue → music
        XCTAssertEqual(ramp1.timeRange.duration, CMTime.seconds(AssemblyConstants.boundaryAudioRampDuration))
        XCTAssertEqual(ramp1.videoVolume,
                       .ramp(from: AssemblyConstants.dialoguePriorityVideoVolume,
                             to: AssemblyConstants.musicPriorityVideoVolume))
        XCTAssertEqual(ramp1.musicVolume,
                       .ramp(from: AssemblyConstants.dialoguePriorityMusicVolume,
                             to: AssemblyConstants.musicPriorityMusicVolume))

        // Boundary ramp 2: music → dialogue
        XCTAssertEqual(ramp2.timeRange.duration, CMTime.seconds(AssemblyConstants.boundaryAudioRampDuration))
        XCTAssertEqual(ramp2.videoVolume,
                       .ramp(from: AssemblyConstants.musicPriorityVideoVolume,
                             to: AssemblyConstants.dialoguePriorityVideoVolume))
        XCTAssertEqual(ramp2.musicVolume,
                       .ramp(from: AssemblyConstants.musicPriorityMusicVolume,
                             to: AssemblyConstants.dialoguePriorityMusicVolume))

        // Continuity: regions cover the whole timeline contiguously
        var cursor = CMTime.zero
        for region in timeline.audioRegions {
            XCTAssertEqual(region.timeRange.start, cursor)
            cursor = region.timeRange.end
        }
        XCTAssertEqual(cursor, timeline.totalDuration)
    }

    // MARK: - Test 6: Legacy plan (all editorial nil) — naive concatenation behavior
    func test06_LegacyPlanProducesNaiveConcatenation() throws {
        // All editorial fields nil
        let s1 = makeShot(number: 1)
        let s2 = makeShot(number: 2)
        let s3 = makeShot(number: 3)
        let plan = makePlan(scenes: [makeScene(number: 1, shots: [s1, s2, s3])])
        let takes = (1...3).map { makeTake(global: $0, durationSeconds: 5.0) }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: false)

        // Three contiguous segments, no transitions
        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertEqual(timeline.transitions.count, 0)
        XCTAssertEqual(timeline.segments[0].timelineTimeRange.start, .zero)
        XCTAssertEqual(timeline.segments[1].timelineTimeRange.start, CMTime.seconds(5.0))
        XCTAssertEqual(timeline.segments[2].timelineTimeRange.start, CMTime.seconds(10.0))
        XCTAssertEqual(timeline.totalDuration, CMTime.seconds(15.0))

        // No music regions
        XCTAssertEqual(timeline.musicRegions.count, 0)

        // Default audio treatment is dialogue_priority — same on every segment, so
        // no boundary ramps, no audio level differences.
        XCTAssertEqual(timeline.audioRegions.count, 3)
        for region in timeline.audioRegions {
            XCTAssertEqual(region.videoVolume, .constant(AssemblyConstants.dialoguePriorityVideoVolume))
            XCTAssertEqual(region.musicVolume, .constant(AssemblyConstants.dialoguePriorityMusicVolume))
        }

        // Timeline duration matches sum of takes (naive concat behavior)
        let totalSec = timeline.totalDuration.seconds
        XCTAssertEqual(totalSec, 15.0, accuracy: 0.0001)
    }

    // MARK: - Test 7: musicCueIn on scene 2, musicCueOut on scene 3
    func test07_MusicCuesProduceSingleSpanningRegion() throws {
        let s1 = makeShot(number: 1, recommendedHold: 5.0)
        let s2 = makeShot(number: 2, recommendedHold: 5.0)
        let s3 = makeShot(number: 3, recommendedHold: 5.0)

        let scene1 = makeScene(number: 1, shots: [s1])
        let scene2 = makeScene(number: 2, shots: [s2], musicCueIn: true)
        let scene3 = makeScene(number: 3, shots: [s3], musicCueOut: true)
        let plan = makePlan(scenes: [scene1, scene2, scene3])
        let takes = (1...3).map { makeTake(global: $0, durationSeconds: 5.0) }

        let timeline = try TimelineBuilder().build(plan: plan, takes: takes, hasMusicURL: true)

        XCTAssertEqual(timeline.musicRegions.count, 1)
        let region = timeline.musicRegions[0]
        // Music starts at start of scene 2 (segment 1) and ends at end of scene 3 (segment 2)
        XCTAssertEqual(region.timeRange.start, CMTime.seconds(5.0))
        XCTAssertEqual(region.timeRange.end, CMTime.seconds(15.0))
        XCTAssertEqual(region.fadeInDuration, CMTime.seconds(AssemblyConstants.musicFadeInDuration))
        XCTAssertEqual(region.fadeOutDuration, CMTime.seconds(AssemblyConstants.musicFadeOutDuration))
    }
}
