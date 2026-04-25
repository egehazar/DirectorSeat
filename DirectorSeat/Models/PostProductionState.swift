import Combine
import Foundation

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
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("assembled_\(UUID().uuidString).mov")
            assembledVideoURL = try await service.assembleClips(urls: takes, outputURL: outputURL)
            print("[DirectorSeat] Assembly complete: \(outputURL)")
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
