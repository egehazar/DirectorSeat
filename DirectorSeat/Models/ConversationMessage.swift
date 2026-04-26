import Foundation

struct ConversationMessage: Codable, Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let proposedRevision: ShotRevision?

    enum Role: String, Codable {
        case user, assistant
    }
}

struct ShotRevision: Codable {
    let targetShotNumber: Int
    let updatedShot: Shot
    let dependentShotChanges: [Shot]
    let summary: String

    enum CodingKeys: String, CodingKey {
        case targetShotNumber = "target_shot_number"
        case updatedShot = "updated_shot"
        case dependentShotChanges = "dependent_shot_changes"
        case summary
    }
}
