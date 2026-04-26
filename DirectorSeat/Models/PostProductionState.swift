import Combine
import Foundation
import SwiftData

@MainActor
class PostProductionState: ObservableObject {
    @Published var colorPreset: ColorPreset = .original
    @Published var musicTrackId: String?
    @Published var musicVolume: Double = 0.5
    @Published var titleCardsEnabled: Bool = true
    @Published var filmTitle: String = ""
    @Published var directorName: String
    @Published var assembledVideoURL: URL?
    @Published var isAssembling = false
    @Published var assemblyError: String?

    var project: FilmProject?
    private let service = VideoAssemblyService()
    private var lastTakes: [URL] = []

    init() {
        directorName = UserDefaults.standard.string(forKey: "directorName") ?? ""
    }

    func assemble(takes: [URL]) async {
        lastTakes = takes
        isAssembling = true
        assemblyError = nil
        print("[DirectorSeat] Assembly started with \(takes.count) clips")
        do {
            let outputDir: URL
            if let project {
                outputDir = project.projectDirectory
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            } else {
                outputDir = FileManager.default.temporaryDirectory
            }
            let outputURL = outputDir.appendingPathComponent("assembled_\(UUID().uuidString).mov")
            assembledVideoURL = try await service.assembleClips(urls: takes, outputURL: outputURL)
            print("[DirectorSeat] Assembly complete: \(outputURL)")

            if let project {
                let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
                let relativePath = outputURL.path.hasPrefix(docsPath)
                    ? String(outputURL.path.dropFirst(docsPath.count + 1))
                    : outputURL.path
                project.assembledVideoPath = relativePath
                project.status = "post"
                try? project.modelContext?.save()
            }
        } catch {
            print("[DirectorSeat] Assembly error: \(error.localizedDescription)")
            assemblyError = error.localizedDescription
        }
        isAssembling = false
    }

    func retryAssembly() {
        Task { await assemble(takes: lastTakes) }
    }
}
