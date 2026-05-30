import XCTest
@testable import DirectorSeat

/// Phase 1 (intelligent-cutting epic): the coverage data model is OPTIONAL and
/// additive. These tests prove (a) plans encoded BEFORE `coverage` existed still
/// decode — coverage comes back nil with every other field intact; (b) a nil
/// coverage is omitted from the encoded JSON (byte-for-byte unchanged for linear
/// shots); and (c) the new coverage types round-trip cleanly within plan JSON.
final class CoverageModelTests: XCTestCase {

    // A plan JSON shaped exactly as plans were serialized BEFORE this change:
    // snake_case keys, no `coverage` field anywhere. This is the regression
    // fixture for backward compatibility of saved FilmProject.planJSON blobs.
    private let legacyPlanJSON = """
    {
      "logline": "A quiet test of backward compatibility.",
      "estimated_duration_minutes": 2,
      "estimated_total_shoot_minutes": 10,
      "scenes": [
        {
          "scene_number": 1,
          "description": "One scene, two shots.",
          "location_description": "A room",
          "cast_count": 1,
          "pacing_profile": "steady",
          "music_cue_in": true,
          "music_cue_out": false,
          "shots": [
            {
              "shot_number": 1,
              "shot_type": "wide",
              "direction_text": "Wide of the room.",
              "camera_placement": "On a shelf",
              "actor_direction": "Stand still",
              "dialogue_direction": null,
              "estimated_duration_seconds": 5,
              "solo_shootable": true,
              "audio_risk": "low",
              "recommended_hold_seconds": 3.0,
              "transition_in_type": "cut",
              "transition_out_type": "cut",
              "pacing_role": "establishing",
              "audio_treatment": "ambient_only",
              "editing_note": "Hold to read the space."
            },
            {
              "shot_number": 2,
              "shot_type": "close-up",
              "direction_text": "Close on the face.",
              "camera_placement": "On the table",
              "actor_direction": "Say the line",
              "dialogue_direction": {
                "has_spoken_line": true,
                "speaker": "Tester",
                "beat_purpose": "Confirms audio works",
                "voice_cue": "Calm",
                "draft_line": "This is a test.",
                "user_written_line": null
              },
              "estimated_duration_seconds": 4,
              "solo_shootable": true,
              "audio_risk": "low",
              "recommended_hold_seconds": 2.5,
              "transition_in_type": "cut",
              "transition_out_type": "cut",
              "pacing_role": "beat",
              "audio_treatment": "dialogue_priority",
              "editing_note": "Tight on the line."
            }
          ]
        }
      ],
      "cast": [{ "role_name": "Tester", "description": "You" }],
      "required_story_props": ["yourself"],
      "optional_setup_helpers": [],
      "location_requirements": ["A room"],
      "music_mood": "ambient"
    }
    """

    // MARK: - Backward compatibility (the load-bearing test)

    func testLegacyPlanDecodesWithNilCoverageAndAllFieldsIntact() throws {
        let data = Data(legacyPlanJSON.utf8)
        let plan = try JSONDecoder().decode(FilmmakingPlan.self, from: data)

        // Plan-level fields intact.
        XCTAssertEqual(plan.logline, "A quiet test of backward compatibility.")
        XCTAssertEqual(plan.estimatedDurationMinutes, 2)
        XCTAssertEqual(plan.scenes.count, 1)

        let scene = plan.scenes[0]
        XCTAssertEqual(scene.shots.count, 2)
        XCTAssertEqual(scene.pacingProfile, .steady)

        // Shot 1: every existing field intact, coverage absent → nil.
        let s1 = scene.shots[0]
        XCTAssertEqual(s1.shotNumber, 1)
        XCTAssertEqual(s1.shotType, "wide")
        XCTAssertEqual(s1.directionText, "Wide of the room.")
        XCTAssertEqual(s1.recommendedHoldSeconds, 3.0)
        XCTAssertEqual(s1.pacingRole, .establishing)
        XCTAssertEqual(s1.audioTreatment, .ambientOnly)
        XCTAssertNil(s1.dialogueDirection)
        XCTAssertNil(s1.coverage, "Missing coverage must decode to nil (linear shot).")

        // Shot 2: dialogue intact, coverage still nil.
        let s2 = scene.shots[1]
        XCTAssertEqual(s2.dialogueDirection?.draftLine, "This is a test.")
        XCTAssertEqual(s2.audioTreatment, .dialoguePriority)
        XCTAssertNil(s2.coverage)
    }

    // MARK: - nil coverage is omitted on encode (byte-for-byte for linear shots)

    func testNilCoverageIsOmittedFromEncodedJSON() throws {
        let plan = try JSONDecoder().decode(FilmmakingPlan.self, from: Data(legacyPlanJSON.utf8))
        let reEncoded = try JSONEncoder().encode(plan)
        let json = String(decoding: reEncoded, as: UTF8.self)
        XCTAssertFalse(json.contains("coverage"),
                       "A nil coverage must not appear in encoded JSON — linear shots stay byte-for-byte.")
    }

    // MARK: - New coverage types round-trip cleanly within a plan

    func testCoverageRoundTripsWithinPlan() throws {
        let coveredShot = Shot(
            shotNumber: 1, shotType: "wide", directionText: "Wide two-shot.",
            cameraPlacement: "On a table", actorDirection: "Talk",
            dialogueDirection: nil, estimatedDurationSeconds: 8,
            soloShootable: true, audioRisk: "low",
            recommendedHoldSeconds: 6.0, transitionInType: .cut, transitionOutType: .cut,
            pacingRole: .beat, audioTreatment: .dialoguePriority, editingNote: nil,
            coverage: CoverageRole(
                beatId: 1,
                kind: .cropZoomSource,
                lineRuns: [
                    LineRun(speaker: "A", lineText: "Hey.", estimatedSeconds: 2.0,
                            angle: .cropZoom(region: NormalizedRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0))),
                    LineRun(speaker: "B", lineText: "Hi.", estimatedSeconds: 1.5,
                            angle: .cropZoom(region: NormalizedRect(x: 0.5, y: 0.0, width: 0.5, height: 1.0))),
                    LineRun(speaker: "A", lineText: nil, estimatedSeconds: 1.0, angle: .wide),
                    LineRun(speaker: "B", lineText: "Wait.", estimatedSeconds: 1.0,
                            angle: .separateAngle(globalShotNumber: 2)),
                ]
            )
        )
        let scene = FilmScene(sceneNumber: 1, description: "d", locationDescription: "l",
                              castCount: 2, shots: [coveredShot])
        let plan = FilmmakingPlan(
            logline: "covered", estimatedDurationMinutes: 1, estimatedTotalShootMinutes: 5,
            scenes: [scene], cast: [], requiredStoryProps: [],
            optionalSetupHelpers: [], locationRequirements: [], musicMood: "test"
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(FilmmakingPlan.self, from: data)
        let rt = decoded.scenes[0].shots[0].coverage

        XCTAssertNotNil(rt)
        XCTAssertEqual(rt?.beatId, 1)
        XCTAssertEqual(rt?.kind, .cropZoomSource)
        XCTAssertEqual(rt?.lineRuns.count, 4)
        // Each angle variant survives the round trip.
        XCTAssertEqual(rt?.lineRuns[0].angle,
                       .cropZoom(region: NormalizedRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0)))
        XCTAssertEqual(rt?.lineRuns[2].angle, .wide)
        XCTAssertEqual(rt?.lineRuns[3].angle, .separateAngle(globalShotNumber: 2))
        XCTAssertEqual(rt?.lineRuns[1].speaker, "B")
        XCTAssertEqual(rt?.lineRuns[0].estimatedSeconds, 2.0)
    }
}
