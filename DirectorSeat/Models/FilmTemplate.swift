import Foundation

struct FilmTemplate: Codable, Identifiable, Hashable {
    static func == (lhs: FilmTemplate, rhs: FilmTemplate) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let title: String
    let description: String
    let mood: String
    let estimatedDurationMinutes: Int
    let estimatedShootMinutes: Int
    let castSize: Int
    let scenes: [TemplateScene]

    var totalShots: Int {
        scenes.reduce(0) { $0 + $1.shots.count }
    }

    var castLabel: String {
        switch castSize {
        case 1: "1 person"
        case 2: "2 people"
        default: "\(castSize) people"
        }
    }
}

struct TemplateScene: Codable {
    let sceneNumber: Int
    let beatDescription: String
    let placeholderDescription: String
    let shots: [TemplateShot]
}

struct TemplateShot: Codable {
    let shotNumber: Int
    let shotType: String
    let beatPurpose: String
    let placeholderDirection: String
    var dialogueIntent: TemplateDialogueIntent? = nil
}

struct TemplateDialogueIntent: Codable {
    let hasSpokenLine: Bool
    let speaker: String?
    let beatPurpose: String
    let voiceCue: String
    let draftHint: String

    enum CodingKeys: String, CodingKey {
        case hasSpokenLine = "has_spoken_line"
        case speaker
        case beatPurpose = "beat_purpose"
        case voiceCue = "voice_cue"
        case draftHint = "draft_hint"
    }
}
