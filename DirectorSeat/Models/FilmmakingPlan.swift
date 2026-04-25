import Foundation

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

    enum CodingKeys: String, CodingKey {
        case sceneNumber = "scene_number"
        case description
        case locationDescription = "location_description"
        case castCount = "cast_count"
        case shots
    }
}

struct Shot: Codable, Identifiable {
    var id: Int { shotNumber }
    let shotNumber: Int
    let shotType: String
    let directionText: String
    let cameraPlacement: String
    let actorDirection: String
    let dialogue: String?
    let estimatedDurationSeconds: Int
    let soloShootable: Bool
    let audioRisk: String

    enum CodingKeys: String, CodingKey {
        case shotNumber = "shot_number"
        case shotType = "shot_type"
        case directionText = "direction_text"
        case cameraPlacement = "camera_placement"
        case actorDirection = "actor_direction"
        case dialogue
        case estimatedDurationSeconds = "estimated_duration_seconds"
        case soloShootable = "solo_shootable"
        case audioRisk = "audio_risk"
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

extension FilmmakingPlan {
    static let sample = FilmmakingPlan(
        logline: "A person investigates mysterious footsteps in their apartment at night.",
        estimatedDurationMinutes: 3,
        estimatedTotalShootMinutes: 25,
        scenes: [
            FilmScene(sceneNumber: 1, description: "The protagonist hears something unsettling.", locationDescription: "Living room", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "wide", directionText: "Wide shot of the living room. The protagonist sits on the couch, looking alert.", cameraPlacement: "On a shelf or stack of books across the room", actorDirection: "Sit still, then slowly look toward the hallway", dialogue: nil, estimatedDurationSeconds: 15, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Close-up of the protagonist's face showing concern.", cameraPlacement: "On the coffee table at face height", actorDirection: "Look worried, glance toward the sound", dialogue: "What was that?", estimatedDurationSeconds: 10, soloShootable: true, audioRisk: "low"),
            ]),
            FilmScene(sceneNumber: 2, description: "The protagonist investigates the hallway.", locationDescription: "Hallway", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "medium", directionText: "The protagonist walks slowly down the hallway toward a closed door.", cameraPlacement: "On a chair or stool at the end of the hallway", actorDirection: "Walk slowly, hand on the wall, looking ahead", dialogue: nil, estimatedDurationSeconds: 12, soloShootable: true, audioRisk: "low"),
            ]),
        ],
        cast: [CastMember(roleName: "Protagonist", description: "A cautious person living alone")],
        requiredStoryProps: ["Phone (for flashlight)"],
        optionalSetupHelpers: ["Stack of books for camera height"],
        locationRequirements: ["A quiet room with a hallway"],
        musicMood: "Tense, suspenseful"
    )

    static let debugMock = FilmmakingPlan(
        logline: "A solo reader discovers a mysterious handwritten note tucked inside a library book they checked out yesterday.",
        estimatedDurationMinutes: 4,
        estimatedTotalShootMinutes: 35,
        scenes: [
            FilmScene(sceneNumber: 1, description: "The reader settles in with a book and discovers the note.", locationDescription: "Indoor library or any room with a table", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "wide", directionText: "Wide shot of the reader sitting at a table, opening the book. A folded note falls out.", cameraPlacement: "On a shelf or stack of books across the table", actorDirection: "Open the book casually, notice something fall out, pause", dialogue: nil, estimatedDurationSeconds: 20, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Close-up of the note unfolding in the reader's hands.", cameraPlacement: "On the table, propped against the mug", actorDirection: "Slowly unfold the note, hold it still for the camera", dialogue: nil, estimatedDurationSeconds: 12, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 3, shotType: "close-up", directionText: "Close-up of the reader's face as they read, expression shifting from curiosity to concern.", cameraPlacement: "On a stack of books at face height", actorDirection: "Read the note, let your expression change slowly", dialogue: "What the...", estimatedDurationSeconds: 10, soloShootable: true, audioRisk: "low"),
            ]),
            FilmScene(sceneNumber: 2, description: "The reader examines the book more closely, finding something hidden.", locationDescription: "Same table", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "medium", directionText: "Medium shot of the reader flipping through pages quickly, looking for more.", cameraPlacement: "On a chair pulled to the side of the table", actorDirection: "Flip through pages with urgency, stop suddenly", dialogue: nil, estimatedDurationSeconds: 15, soloShootable: true, audioRisk: "low"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Close-up of a small key taped inside the back cover.", cameraPlacement: "Flat on the table, angled up at the book", actorDirection: "Hold the book open to reveal the key", dialogue: nil, estimatedDurationSeconds: 8, soloShootable: true, audioRisk: "low"),
            ]),
            FilmScene(sceneNumber: 3, description: "The reader looks around, realizing someone left this for them specifically.", locationDescription: "Same room, near a window", castCount: 1, shots: [
                Shot(shotNumber: 1, shotType: "medium", directionText: "Medium shot of the reader standing, holding the note and key, looking toward the window.", cameraPlacement: "On a shelf or counter across the room", actorDirection: "Stand up slowly, hold both items, glance at the window", dialogue: nil, estimatedDurationSeconds: 15, soloShootable: true, audioRisk: "medium"),
                Shot(shotNumber: 2, shotType: "close-up", directionText: "Final close-up of the note and key held together in the reader's hand.", cameraPlacement: "On the table at hand height", actorDirection: "Hold both items together, turn them over slowly", dialogue: nil, estimatedDurationSeconds: 10, soloShootable: true, audioRisk: "low"),
            ]),
        ],
        cast: [CastMember(roleName: "The Reader", description: "A quiet, curious person who reads alone")],
        requiredStoryProps: ["library book", "handwritten note", "blue mug"],
        optionalSetupHelpers: ["small key as a hidden object"],
        locationRequirements: ["indoor library or any room with a table"],
        musicMood: "Quiet, mysterious, suspenseful"
    )
}
