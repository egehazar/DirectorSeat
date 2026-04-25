import Combine
import Foundation
import Photos

enum ExportPhase: Equatable {
    case idle
    case paywall
    case rendering(progress: Double)
    case success(URL)
    case failure(String)
}

@MainActor
class ExportState: ObservableObject {
    @Published var phase: ExportPhase = .idle
    @Published var isPaid = false
    @Published var includeWatermark = true
    @Published var userChoseExport = false

    private let service = VideoExportService()
    private var lastPlan: FilmmakingPlan?
    private var lastAssembledURL: URL?
    private var lastPostState: PostProductionState?

    func proceedWithWatermark() {
        includeWatermark = true
        userChoseExport = true
    }

    func purchaseClean() {
        isPaid = true
        includeWatermark = false
        userChoseExport = true
    }

    func startRender(plan: FilmmakingPlan, assembledURL: URL, state: PostProductionState) {
        lastPlan = plan
        lastAssembledURL = assembledURL
        lastPostState = state
        phase = .rendering(progress: 0)
        print("[DirectorSeat] Export started")

        Task {
            let progressTask = Task {
                var elapsed = 0.0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    elapsed += 0.2
                    let fakeProgress = min(elapsed / 8.0, 0.95)
                    phase = .rendering(progress: fakeProgress)
                }
            }

            do {
                let url = try await service.export(
                    assembledURL: assembledURL,
                    state: state,
                    includeWatermark: includeWatermark,
                    plan: plan
                )
                progressTask.cancel()
                print("[DirectorSeat] Export complete: \(url)")
                phase = .success(url)
            } catch {
                progressTask.cancel()
                print("[DirectorSeat] Export error: \(error.localizedDescription)")
                phase = .failure(error.localizedDescription)
            }
        }
    }

    func retry() {
        guard let plan = lastPlan, let url = lastAssembledURL, let state = lastPostState else { return }
        startRender(plan: plan, assembledURL: url, state: state)
    }

    func saveToCameraRoll(url: URL) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                throw NSError(domain: "DirectorSeat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied."])
            }
        } else if status == .denied || status == .restricted {
            throw NSError(domain: "DirectorSeat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied. Open Settings to grant access."])
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
