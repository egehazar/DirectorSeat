import Foundation
import SwiftData
import UIKit

@MainActor
class ProjectStore {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createProject(ideaText: String, castChoice: CastChoice, contextText: String) -> FilmProject {
        let title = String(ideaText.prefix(60))
        let project = FilmProject(
            title: title,
            ideaText: ideaText,
            castChoice: castChoice.rawValue,
            contextText: contextText
        )
        modelContext.insert(project)
        save()
        ensureDirectories(for: project)
        return project
    }

    func save() {
        try? modelContext.save()
    }

    func delete(_ project: FilmProject) {
        try? FileManager.default.removeItem(at: project.projectDirectory)
        modelContext.delete(project)
        save()
    }

    func ensureDirectories(for project: FilmProject) {
        try? FileManager.default.createDirectory(
            at: project.takesDirectory,
            withIntermediateDirectories: true
        )
    }

    func generateThumbnail(for project: FilmProject) async {
        let takes = project.selectedTakes
        guard let firstURL = takes[0] ?? takes.sorted(by: { $0.key < $1.key }).first?.value else { return }
        if let image = await VideoUtilities.extractFirstFrame(from: firstURL) {
            project.thumbnailData = image.jpegData(compressionQuality: 0.7)
            save()
        }
    }
}
