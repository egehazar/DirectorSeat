import AVFoundation
import Combine
import Foundation
import SwiftData

enum RecordingState: Equatable {
    case idle
    case countingDown
    case recording
    case reviewing(URL)
}

class ShootingModeViewModel: ObservableObject {
    let plan: FilmmakingPlan
    let cameraService = CameraService()
    var project: FilmProject?

    @Published var currentShotIndex = 0
    @Published var recordingState: RecordingState = .idle
    @Published var countdownValue = 3
    @Published var capturedTakes: [Int: [URL]] = [:]
    @Published var selectedTakes: [Int: URL] = [:]
    @Published var allShotsComplete = false
    @Published var permissionGranted: Bool?
    @Published var recordingDuration: TimeInterval = 0
    @Published var showRecordingError = false
    @Published var cameraStartError = false

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

    init(plan: FilmmakingPlan, project: FilmProject? = nil) {
        self.plan = plan
        self.project = project

        // Restore state from project
        if let project {
            self.capturedTakes = project.capturedTakes
            self.selectedTakes = project.selectedTakes
            self.currentShotIndex = project.currentShotIndex
        }

        cameraService.onRecordingFinished = { [weak self] result in
            switch result {
            case .success(let url):
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                print("[DirectorSeat] Recording stopped, file size: \(size) bytes")
                self?.handleRecordingFinished(url: url)
            case .failure(let error):
                print("[DirectorSeat] Recording error: \(error.localizedDescription)")
                self?.recordingTimer?.invalidate()
                self?.recordingTimer = nil
                self?.recordingState = .idle
                self?.showRecordingError = true
            }
        }
    }

    func requestPermissions() async {
        let granted = await cameraService.requestPermissions()
        permissionGranted = granted
        if granted {
            let started = cameraService.startSession()
            if !started {
                cameraStartError = true
            }
        }
    }

    func startRecording() {
        guard recordingState == .idle else { return }
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
        guard recordingState == .recording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        cameraService.stopRecording()
    }

    func useTake() {
        guard case .reviewing(let url) = recordingState else { return }
        selectedTakes[currentShotIndex] = url
        print("[DirectorSeat] Take selected for shot \(currentShotNumber)")

        project?.selectedTakes = selectedTakes
        saveProject()

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

            project?.currentShotIndex = currentShotIndex
            saveProject()
        } else {
            print("[DirectorSeat] All shots captured, ready to assemble")
            allShotsComplete = true

            project?.status = "reviewing"
            saveProject()
        }
    }

    func cleanup() {
        countdownTimer?.invalidate()
        recordingTimer?.invalidate()
        cameraService.stopSession()
    }

    private func beginActualRecording() {
        let takeIndex = (capturedTakes[currentShotIndex]?.count ?? 0) + 1
        let fileName = "shot_\(currentShotIndex + 1)_take_\(takeIndex)_\(UUID().uuidString).mov"

        let url: URL
        if let project {
            let store = ProjectStore(modelContext: project.modelContext!)
            store.ensureDirectories(for: project)
            url = project.takesDirectory.appendingPathComponent(fileName)
        } else {
            url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        recordingState = .recording
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }

        print("[DirectorSeat] Recording started, file: \(url)")
        cameraService.startRecording(to: url)

        if project?.status == "planning" || project?.status == "reviewing" {
            project?.status = "shooting"
            saveProject()
        }
    }

    private func handleRecordingFinished(url: URL) {
        var takes = capturedTakes[currentShotIndex] ?? []
        takes.append(url)
        capturedTakes[currentShotIndex] = takes
        recordingState = .reviewing(url)

        project?.capturedTakes = capturedTakes
        saveProject()
    }

    private func saveProject() {
        try? project?.modelContext?.save()
    }
}
