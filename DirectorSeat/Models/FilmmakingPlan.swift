import Foundation

// MARK: - Editorial Enums

enum TransitionType: String, Codable {
    case cut
    case dissolve
    case fadeToBlack = "fade_to_black"
    case fadeFromBlack = "fade_from_black"
    case matchCut = "match_cut"
}

enum PacingRole: String, Codable {
    case establishing
    case building
    case beat
    case payoff
    case transition
    case closure
}

enum AudioTreatment: String, Codable {
    case dialoguePriority = "dialogue_priority"
    case musicPriority = "music_priority"
    case ambientOnly = "ambient_only"
    case silent
    case crescendo
}

enum ScenePacingProfile: String, Codable {
    case slowBurn = "slow_burn"
    case risingTension = "rising_tension"
    case quickBeats = "quick_beats"
    case steady
    case climactic
}

// MARK: - Dialogue Direction

struct DialogueDirection: Codable, Hashable {
    let hasSpokenLine: Bool
    let speaker: String?
    let beatPurpose: String
    let voiceCue: String
    let draftLine: String?
    var userWrittenLine: String?

    enum CodingKeys: String, CodingKey {
        case hasSpokenLine = "has_spoken_line"
        case speaker
        case beatPurpose = "beat_purpose"
        case voiceCue = "voice_cue"
        case draftLine = "draft_line"
        case userWrittenLine = "user_written_line"
    }
}

// MARK: - Plan Model

struct FilmmakingPlan: Codable {
    let logline: String
    let estimatedDurationMinutes: Int
    let estimatedTotalShootMinutes: Int
    let scenes: [FilmScene]
    let cast: [CastMember]
    let requiredStoryProps: [String]
    let optionalSetupHelpers: [String]
    let locationRequirements: [String]
    let musicMood: String

    enum CodingKeys: String, CodingKey {
        case logline
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case estimatedTotalShootMinutes = "estimated_total_shoot_minutes"
        case scenes, cast
        case requiredStoryProps = "required_story_props"
        case optionalSetupHelpers = "optional_setup_helpers"
        case locationRequirements = "location_requirements"
        case musicMood = "music_mood"
    }
}

struct FilmScene: Codable, Identifiable {
    var id: Int { sceneNumber }
    let sceneNumber: Int
    let description: String
    let locationDescription: String
    let castCount: Int
    let shots: [Shot]

    // Scene-level editorial metadata
    let pacingProfile: ScenePacingProfile?
    let musicCueIn: Bool?
    let musicCueOut: Bool?

    enum CodingKeys: String, CodingKey {
        case sceneNumber = "scene_number"
        case description
        case locationDescription = "location_description"
        case castCount = "cast_count"
        case shots
        case pacingProfile = "pacing_profile"
        case musicCueIn = "music_cue_in"
        case musicCueOut = "music_cue_out"
    }

    init(sceneNumber: Int, description: String, locationDescription: String,
         castCount: Int, shots: [Shot],
         pacingProfile: ScenePacingProfile? = nil,
         musicCueIn: Bool? = nil, musicCueOut: Bool? = nil) {
        self.sceneNumber = sceneNumber
        self.description = description
        self.locationDescription = locationDescription
        self.castCount = castCount
        self.shots = shots
        self.pacingProfile = pacingProfile
        self.musicCueIn = musicCueIn
        self.musicCueOut = musicCueOut
    }
}

struct Shot: Codable, Identifiable {
    var id: Int { shotNumber }
    let shotNumber: Int
    let shotType: String
    let directionText: String
    let cameraPlacement: String
    let actorDirection: String
    let dialogueDirection: DialogueDirection?
    let estimatedDurationSeconds: Int
    let soloShootable: Bool
    let audioRisk: String

    // Editorial metadata — populated by LLM, consumed by assembly engine
    let recommendedHoldSeconds: Double?
    let transitionInType: TransitionType?
    let transitionOutType: TransitionType?
    let pacingRole: PacingRole?
    let audioTreatment: AudioTreatment?
    let editingNote: String?

    // Adaptive-coverage metadata (intelligent-cutting epic). OPTIONAL and
    // defaults to nil — load-bearing for backward compatibility: plans encoded
    // before this field existed decode with coverage == nil, and a shot with
    // coverage == nil is treated as linear (today's behavior). See
    // docs/intelligent-cutting-spec.md. Nothing reads this yet (Phase 1).
    let coverage: CoverageRole?

    enum CodingKeys: String, CodingKey {
        case shotNumber = "shot_number"
        case shotType = "shot_type"
        case directionText = "direction_text"
        case cameraPlacement = "camera_placement"
        case actorDirection = "actor_direction"
        case dialogueDirection = "dialogue_direction"
        case estimatedDurationSeconds = "estimated_duration_seconds"
        case soloShootable = "solo_shootable"
        case audioRisk = "audio_risk"
        case recommendedHoldSeconds = "recommended_hold_seconds"
        case transitionInType = "transition_in_type"
        case transitionOutType = "transition_out_type"
        case pacingRole = "pacing_role"
        case audioTreatment = "audio_treatment"
        case editingNote = "editing_note"
        case coverage
    }

    // Legacy key for backward-compatible decoding of saved projects
    private enum LegacyCodingKeys: String, CodingKey {
        case dialogue
    }

    init(shotNumber: Int, shotType: String, directionText: String,
         cameraPlacement: String, actorDirection: String, dialogueDirection: DialogueDirection?,
         estimatedDurationSeconds: Int, soloShootable: Bool, audioRisk: String,
         recommendedHoldSeconds: Double? = nil, transitionInType: TransitionType? = nil,
         transitionOutType: TransitionType? = nil, pacingRole: PacingRole? = nil,
         audioTreatment: AudioTreatment? = nil, editingNote: String? = nil,
         coverage: CoverageRole? = nil) {
        self.shotNumber = shotNumber
        self.shotType = shotType
        self.directionText = directionText
        self.cameraPlacement = cameraPlacement
        self.actorDirection = actorDirection
        self.dialogueDirection = dialogueDirection
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.soloShootable = soloShootable
        self.audioRisk = audioRisk
        self.recommendedHoldSeconds = recommendedHoldSeconds
        self.transitionInType = transitionInType
        self.transitionOutType = transitionOutType
        self.pacingRole = pacingRole
        self.audioTreatment = audioTreatment
        self.editingNote = editingNote
        self.coverage = coverage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shotNumber = try container.decode(Int.self, forKey: .shotNumber)
        shotType = try container.decode(String.self, forKey: .shotType)
        directionText = try container.decode(String.self, forKey: .directionText)
        cameraPlacement = try container.decode(String.self, forKey: .cameraPlacement)
        actorDirection = try container.decode(String.self, forKey: .actorDirection)
        estimatedDurationSeconds = try container.decode(Int.self, forKey: .estimatedDurationSeconds)
        soloShootable = try container.decode(Bool.self, forKey: .soloShootable)
        audioRisk = try container.decode(String.self, forKey: .audioRisk)
        recommendedHoldSeconds = try container.decodeIfPresent(Double.self, forKey: .recommendedHoldSeconds)
        transitionInType = try container.decodeIfPresent(TransitionType.self, forKey: .transitionInType)
        transitionOutType = try container.decodeIfPresent(TransitionType.self, forKey: .transitionOutType)
        pacingRole = try container.decodeIfPresent(PacingRole.self, forKey: .pacingRole)
        audioTreatment = try container.decodeIfPresent(AudioTreatment.self, forKey: .audioTreatment)
        editingNote = try container.decodeIfPresent(String.self, forKey: .editingNote)
        // Absent in plans encoded before coverage existed → nil → linear shot.
        coverage = try container.decodeIfPresent(CoverageRole.self, forKey: .coverage)

        // New dialogue_direction field; fall back to legacy dialogue string for saved projects
        if let dd = try container.decodeIfPresent(DialogueDirection.self, forKey: .dialogueDirection) {
            dialogueDirection = dd
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            if let legacyLine = try legacy.decodeIfPresent(String.self, forKey: .dialogue) {
                dialogueDirection = DialogueDirection(
                    hasSpokenLine: true,
                    speaker: nil,
                    beatPurpose: "",
                    voiceCue: "",
                    draftLine: nil,
                    userWrittenLine: legacyLine
                )
            } else {
                dialogueDirection = nil
            }
        }
    }
}

struct CastMember: Codable, Identifiable {
    var id: String { roleName }
    let roleName: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case roleName = "role_name"
        case description
    }
}

// MARK: - Plan Mutation for Shot Refinement

extension FilmmakingPlan {
    /// Maps a 1-indexed global shot number to (sceneIndex, shotIndex).
    func sceneAndShotIndex(forGlobal globalNumber: Int) -> (sceneIndex: Int, shotIndex: Int)? {
        var count = 0
        for (si, scene) in scenes.enumerated() {
            for shi in 0..<scene.shots.count {
                count += 1
                if count == globalNumber { return (si, shi) }
            }
        }
        return nil
    }

    /// Returns a new plan with the revision applied (target + dependents).
    func applyingRevision(_ revision: ShotRevision) -> FilmmakingPlan? {
        var updatedScenes = scenes

        // Apply target shot
        guard let (si, shi) = sceneAndShotIndex(forGlobal: revision.targetShotNumber) else { return nil }
        let originalNum = updatedScenes[si].shots[shi].shotNumber
        updatedScenes[si] = updatedScenes[si].replacingShot(
            at: shi,
            with: revision.updatedShot.withShotNumber(originalNum)
        )

        // Apply dependent changes
        for depShot in revision.dependentShotChanges {
            guard let (dsi, dshi) = sceneAndShotIndex(forGlobal: depShot.shotNumber) else { continue }
            let origNum = updatedScenes[dsi].shots[dshi].shotNumber
            updatedScenes[dsi] = updatedScenes[dsi].replacingShot(
                at: dshi,
                with: depShot.withShotNumber(origNum)
            )
        }

        return FilmmakingPlan(
            logline: logline,
            estimatedDurationMinutes: estimatedDurationMinutes,
            estimatedTotalShootMinutes: estimatedTotalShootMinutes,
            scenes: updatedScenes,
            cast: cast,
            requiredStoryProps: requiredStoryProps,
            optionalSetupHelpers: optionalSetupHelpers,
            locationRequirements: locationRequirements,
            musicMood: musicMood
        )
    }
}

extension Shot {
    func withShotNumber(_ number: Int) -> Shot {
        Shot(
            shotNumber: number,
            shotType: shotType,
            directionText: directionText,
            cameraPlacement: cameraPlacement,
            actorDirection: actorDirection,
            dialogueDirection: dialogueDirection,
            estimatedDurationSeconds: estimatedDurationSeconds,
            soloShootable: soloShootable,
            audioRisk: audioRisk,
            recommendedHoldSeconds: recommendedHoldSeconds,
            transitionInType: transitionInType,
            transitionOutType: transitionOutType,
            pacingRole: pacingRole,
            audioTreatment: audioTreatment,
            editingNote: editingNote,
            coverage: coverage
        )
    }

    var displayLine: String {
        dialogueDirection?.userWrittenLine ?? dialogueDirection?.draftLine ?? ""
    }

    func withDialogueDirection(_ direction: DialogueDirection?) -> Shot {
        Shot(
            shotNumber: shotNumber,
            shotType: shotType,
            directionText: directionText,
            cameraPlacement: cameraPlacement,
            actorDirection: actorDirection,
            dialogueDirection: direction,
            estimatedDurationSeconds: estimatedDurationSeconds,
            soloShootable: soloShootable,
            audioRisk: audioRisk,
            recommendedHoldSeconds: recommendedHoldSeconds,
            transitionInType: transitionInType,
            transitionOutType: transitionOutType,
            pacingRole: pacingRole,
            audioTreatment: audioTreatment,
            editingNote: editingNote,
            coverage: coverage
        )
    }
}

extension FilmmakingPlan {
    func replacingShot(atGlobal globalNumber: Int, with shot: Shot) -> FilmmakingPlan? {
        guard let (si, shi) = sceneAndShotIndex(forGlobal: globalNumber) else { return nil }
        var updatedScenes = scenes
        updatedScenes[si] = updatedScenes[si].replacingShot(at: shi, with: shot)
        return FilmmakingPlan(
            logline: logline,
            estimatedDurationMinutes: estimatedDurationMinutes,
            estimatedTotalShootMinutes: estimatedTotalShootMinutes,
            scenes: updatedScenes,
            cast: cast,
            requiredStoryProps: requiredStoryProps,
            optionalSetupHelpers: optionalSetupHelpers,
            locationRequirements: locationRequirements,
            musicMood: musicMood
        )
    }
}

extension FilmScene {
    func replacingShot(at index: Int, with shot: Shot) -> FilmScene {
        var updatedShots = shots
        updatedShots[index] = shot
        return FilmScene(
            sceneNumber: sceneNumber,
            description: description,
            locationDescription: locationDescription,
            castCount: castCount,
            shots: updatedShots,
            pacingProfile: pacingProfile,
            musicCueIn: musicCueIn,
            musicCueOut: musicCueOut
        )
    }
}

// MARK: - Sample Data

extension FilmmakingPlan {
    static let sample = FilmmakingPlan(
        logline: "A person investigates mysterious footsteps in their apartment at night.",
        estimatedDurationMinutes: 3,
        estimatedTotalShootMinutes: 25,
        scenes: [
            FilmScene(sceneNumber: 1, description: "The protagonist hears something unsettling.", locationDescription: "Living room", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "wide", directionText: "Wide shot of the living room. The protagonist sits on the couch, looking alert.", cameraPlacement: "On a shelf or stack of books across the room", actorDirection: "Sit still, then slowly look toward the hallway", dialogueDirection: nil, estimatedDurationSeconds: 15, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Close-up of the protagonist's face showing concern.", cameraPlacement: "On the coffee table at face height", actorDirection: "Look worried, glance toward the sound", dialogueDirection: DialogueDirection(hasSpokenLine: true, speaker: "Protagonist", beatPurpose: "Breaks the silence to externalize rising fear", voiceCue: "Whispered, half to themselves — not expecting an answer", draftLine: "What was that?"), estimatedDurationSeconds: 10, soloShootable: true, audioRisk: "low"),
            ]),
            FilmScene(sceneNumber: 2, description: "The protagonist investigates the hallway.", locationDescription: "Hallway", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "medium", directionText: "The protagonist walks slowly down the hallway toward a closed door.", cameraPlacement: "On a chair or stool at the end of the hallway", actorDirection: "Walk slowly, hand on the wall, looking ahead", dialogueDirection: nil, estimatedDurationSeconds: 12, soloShootable: true, audioRisk: "low"),
            ]),
        ],
        cast: [CastMember(roleName: "Protagonist", description: "A cautious person living alone")],
        requiredStoryProps: ["Phone (for flashlight)"],
        optionalSetupHelpers: ["Stack of books for camera height"],
        locationRequirements: ["A quiet room with a hallway"],
        musicMood: "Tense, suspenseful"
    )

    static let fastTest = FilmmakingPlan(
        logline: "A quick test of the shooting flow.",
        estimatedDurationMinutes: 1,
        estimatedTotalShootMinutes: 2,
        scenes: [
            FilmScene(sceneNumber: 1, description: "Three quick shots to test the full pipeline.", locationDescription: "Anywhere", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "wide", directionText: "Stand a few feet back from your phone. Wave at the camera.", cameraPlacement: "On any surface — shelf, table, stack of books", actorDirection: "Wave at the camera for a few seconds", dialogueDirection: nil, estimatedDurationSeconds: 5, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "medium", directionText: "Move closer. Smile and say: 'This is a test.'", cameraPlacement: "Same position", actorDirection: "Step closer, smile, say the line", dialogueDirection: DialogueDirection(hasSpokenLine: true, speaker: "Tester", beatPurpose: "Confirms audio capture is working", voiceCue: "Casual, direct to camera", draftLine: "This is a test."), estimatedDurationSeconds: 5, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 3, shotType: "close-up", directionText: "Get close. Hold your hand up to the camera, then drop it.", cameraPlacement: "Same position", actorDirection: "Hold hand up, pause, drop it", dialogueDirection: nil, estimatedDurationSeconds: 5, soloShootable: true, audioRisk: "low"),
            ]),
        ],
        cast: [CastMember(roleName: "Tester", description: "You")],
        requiredStoryProps: ["yourself"],
        optionalSetupHelpers: [],
        locationRequirements: ["Anywhere"],
        musicMood: "ambient"
    )

    static let debugMock = FilmmakingPlan(
        logline: "A solo reader discovers a mysterious handwritten note tucked inside a library book they checked out yesterday.",
        estimatedDurationMinutes: 4,
        estimatedTotalShootMinutes: 35,
        scenes: [
            FilmScene(sceneNumber: 1, description: "The reader settles in with a book and discovers the note.", locationDescription: "Indoor library or any room with a table", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "wide", directionText: "Wide shot of the reader sitting at a table, opening the book. A folded note falls out.", cameraPlacement: "On a shelf or stack of books across the table", actorDirection: "Open the book casually, notice something fall out, pause", dialogueDirection: nil, estimatedDurationSeconds: 20, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Close-up of the note unfolding in the reader's hands.", cameraPlacement: "On the table, propped against the mug", actorDirection: "Slowly unfold the note, hold it still for the camera", dialogueDirection: nil, estimatedDurationSeconds: 12, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 3, shotType: "close-up", directionText: "Close-up of the reader's face as they read, expression shifting from curiosity to concern.", cameraPlacement: "On a stack of books at face height", actorDirection: "Read the note, let your expression change slowly", dialogueDirection: DialogueDirection(hasSpokenLine: true, speaker: "The Reader", beatPurpose: "Reveals the note's content is alarming without showing it", voiceCue: "Muttered, trailing off — genuine surprise, not performed", draftLine: "What the..."), estimatedDurationSeconds: 10, soloShootable: true, audioRisk: "low"),
            ]),
            FilmScene(sceneNumber: 2, description: "The reader examines the book more closely, finding something hidden.", locationDescription: "Same table", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "medium", directionText: "Medium shot of the reader flipping through pages quickly, looking for more.", cameraPlacement: "On a chair pulled to the side of the table", actorDirection: "Flip through pages with urgency, stop suddenly", dialogueDirection: nil, estimatedDurationSeconds: 15, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Close-up of a small key taped inside the back cover.", cameraPlacement: "Flat on the table, angled up at the book", actorDirection: "Hold the book open to reveal the key", dialogueDirection: nil, estimatedDurationSeconds: 8, soloShootable: true, audioRisk: "low"),
            ]),
            FilmScene(sceneNumber: 3, description: "The reader looks around, realizing someone left this for them specifically.", locationDescription: "Same room, near a window", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "medium", directionText: "Medium shot of the reader standing, holding the note and key, looking toward the window.", cameraPlacement: "On a shelf or counter across the room", actorDirection: "Stand up slowly, hold both items, glance at the window", dialogueDirection: nil, estimatedDurationSeconds: 15, soloShootable: true, audioRisk: "medium"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Final close-up of the note and key held together in the reader's hand.", cameraPlacement: "On the table at hand height", actorDirection: "Hold both items together, turn them over slowly", dialogueDirection: nil, estimatedDurationSeconds: 10, soloShootable: true, audioRisk: "low"),
            ]),
        ],
        cast: [CastMember(roleName: "The Reader", description: "A quiet, curious person who reads alone")],
        requiredStoryProps: ["library book", "handwritten note", "blue mug"],
        optionalSetupHelpers: ["small key as a hidden object"],
        locationRequirements: ["indoor library or any room with a table"],
        musicMood: "Quiet, mysterious, suspenseful"
    )
}
