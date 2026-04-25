import AVFoundation
import Combine
import Foundation

enum RecordingState: Equatable {
    case idle
    case countingDown
    case recording
    case reviewing(URL)
}

class ShootingModeViewModel: ObservableObject {
    let plan: FilmmakingPlan
    let cameraService = CameraService()

    @Published var currentShotIndex = 0
    @Published var recordingState: RecordingState = .idle
    @Published var countdownValue = 3
    @Published var capturedTakes: [Int: [URL]] = [:]
    @Published var selectedTakes: [Int: URL] = [:]
    @Published var allShotsComplete = false
    @Published var permissionGranted: Bool?
    @Published var recordingDuration: TimeInterval = 0

    private var countdownTimer: Timer?
    private var recordingTimer: Timer?

    var allShots: [Shot] {
        plan.scenes.flatMap(\.shots)
    }

    var currentShot: Shot? {
        guard currentShotIndex < allShots.count else { return nil }
        return allShots[currentShotIndex]
    }

    var currentShotNumber: Int { currentShotIndex + 1 }
    var totalShots: Int { allShots.count }

    init(plan: FilmmakingPlan) {
        self.plan = plan
        cameraService.onRecordingFinished = { [weak self] url in
            self?.handleRecordingFinished(url: url)
        }
    }

    func requestPermissions() async {
        let granted = await cameraService.requestPermissions()
        permissionGranted = granted
        if granted {
            cameraService.startSession()
        }
    }

    func startRecording() {
        recordingState = .countingDown
        countdownValue = 3

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.countdownValue -= 1
            if self.countdownValue <= 0 {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.beginActualRecording()
            }
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        cameraService.stopRecording()
    }

    func useTake() {
        guard case .reviewing(let url) = recordingState else { return }
        selectedTakes[currentShotIndex] = url
        advanceToNextShot()
    }

    func retryTake() {
        recordingState = .idle
    }

    func skipShot() {
        advanceToNextShot()
    }

    func advanceToNextShot() {
        if currentShotIndex + 1 < allShots.count {
            currentShotIndex += 1
            recordingState = .idle
        } else {
            allShotsComplete = true
        }
    }

    func cleanup() {
        countdownTimer?.invalidate()
        recordingTimer?.invalidate()
        cameraService.stopSession()
    }

    private func beginActualRecording() {
        let takeIndex = (capturedTakes[currentShotIndex]?.count ?? 0) + 1
        let fileName = "shot_\(currentShotIndex + 1)_take\(takeIndex).mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        recordingState = .recording
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }

        cameraService.startRecording(to: url)
    }

    private func handleRecordingFinished(url: URL) {
        var takes = capturedTakes[currentShotIndex] ?? []
        takes.append(url)
        capturedTakes[currentShotIndex] = takes
        recordingState = .reviewing(url)
    }
}
