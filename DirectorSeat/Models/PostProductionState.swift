import Combine
import Foundation

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

    private let service = VideoAssemblyService()

    init() {
        directorName = UserDefaults.standard.string(forKey: "directorName") ?? ""
    }

    func assemble(takes: [URL]) async {
        isAssembling = true
        assemblyError = nil
        do {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("assembled_\(UUID().uuidString).mov")
            assembledVideoURL = try await service.assembleClips(urls: takes, outputURL: outputURL)
        } catch {
            assemblyError = error.localizedDescription
        }
        isAssembling = false
    }
}
