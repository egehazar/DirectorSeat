import Foundation
import SwiftData
import UIKit

@Model
class FilmProject {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var ideaText: String
    var castChoice: String
    var contextText: String
    var planJSON: Data?
    var capturedTakesJSON: Data?
    var selectedTakesJSON: Data?
    var currentShotIndex: Int
    var status: String
    var thumbnailData: Data?
    var assembledVideoPath: String?
    var exportedVideoPath: String?
    var directorName: String
    var titleCardsEnabled: Bool
    var filmTitle: String
    var conversationsJSON: Data?
    var templateID: String?
    var templateCustomization: String?
    var shootingLanguage: String?

    init(
        title: String,
        ideaText: String,
        castChoice: String,
        contextText: String
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.title = title
        self.ideaText = ideaText
        self.castChoice = castChoice
        self.contextText = contextText
        self.currentShotIndex = 0
        self.status = "planning"
        self.directorName = UserDefaults.standard.string(forKey: "directorName") ?? ""
        self.titleCardsEnabled = true
        self.filmTitle = title
    }

    // MARK: - Plan

    var plan: FilmmakingPlan? {
        get {
            guard let data = planJSON else { return nil }
            return try? JSONDecoder().decode(FilmmakingPlan.self, from: data)
        }
        set {
            planJSON = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }

    // MARK: - Takes (stored as relative paths from Documents)

    var capturedTakes: [Int: [URL]] {
        get {
            guard let data = capturedTakesJSON else { return [:] }
            guard let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
            let docs = Self.documentsDirectory
            return dict.reduce(into: [:]) { result, pair in
                if let key = Int(pair.key) {
                    result[key] = pair.value.map { docs.appendingPathComponent($0) }
                }
            }
        }
        set {
            let docsPath = Self.documentsDirectory.path
            let dict = newValue.reduce(into: [String: [String]]()) { result, pair in
                result[String(pair.key)] = pair.value.map { Self.relativePath($0.path, from: docsPath) }
            }
            capturedTakesJSON = try? JSONEncoder().encode(dict)
            updatedAt = Date()
        }
    }

    var selectedTakes: [Int: URL] {
        get {
            guard let data = selectedTakesJSON else { return [:] }
            guard let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            let docs = Self.documentsDirectory
            return dict.reduce(into: [:]) { result, pair in
                if let key = Int(pair.key) {
                    result[key] = docs.appendingPathComponent(pair.value)
                }
            }
        }
        set {
            let docsPath = Self.documentsDirectory.path
            let dict = newValue.reduce(into: [String: String]()) { result, pair in
                result[String(pair.key)] = Self.relativePath(pair.value.path, from: docsPath)
            }
            selectedTakesJSON = try? JSONEncoder().encode(dict)
            updatedAt = Date()
        }
    }

    // MARK: - Conversations (shot number → messages)

    var conversations: [Int: [ConversationMessage]] {
        get {
            guard let data = conversationsJSON else { return [:] }
            guard let dict = try? JSONDecoder().decode([String: [ConversationMessage]].self, from: data) else { return [:] }
            return dict.reduce(into: [:]) { result, pair in
                if let key = Int(pair.key) {
                    result[key] = pair.value
                }
            }
        }
        set {
            let dict = newValue.reduce(into: [String: [ConversationMessage]]()) { result, pair in
                result[String(pair.key)] = pair.value
            }
            conversationsJSON = try? JSONEncoder().encode(dict)
        }
    }

    // MARK: - Directories

    var projectDirectory: URL {
        Self.documentsDirectory
            .appendingPathComponent("projects/\(id.uuidString)", isDirectory: true)
    }

    var takesDirectory: URL {
        projectDirectory.appendingPathComponent("takes", isDirectory: true)
    }

    // MARK: - Resolved URLs

    var assembledVideoURL: URL? {
        guard let path = assembledVideoPath else { return nil }
        return Self.documentsDirectory.appendingPathComponent(path)
    }

    var exportedVideoURL: URL? {
        guard let path = exportedVideoPath else { return nil }
        return Self.documentsDirectory.appendingPathComponent(path)
    }

    // MARK: - Display Helpers

    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    var statusDisplay: String {
        switch status {
        case "planning": return "Planning"
        case "shooting":
            if let plan {
                let total = plan.scenes.flatMap(\.shots).count
                return "Shooting (\(min(currentShotIndex + 1, total)) of \(total))"
            }
            return "Shooting"
        case "reviewing": return "Ready to assemble"
        case "post": return "Post-production"
        case "exported": return "Exported"
        default: return status.capitalized
        }
    }

    var relativeTimeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    // MARK: - Private Helpers

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func relativePath(_ absolute: String, from base: String) -> String {
        if absolute.hasPrefix(base) {
            let start = absolute.index(absolute.startIndex, offsetBy: base.count)
            var relative = String(absolute[start...])
            if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }
            return relative
        }
        return absolute
    }
}
