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
}
