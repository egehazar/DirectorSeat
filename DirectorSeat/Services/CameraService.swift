import AVFoundation

class CameraService: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    let previewLayer: AVCaptureVideoPreviewLayer
    private var isConfigured = false

    /// True only when the coverage-cutting flag is on AND this device/session can
    /// actually record 4K (3840×2160). Crop-zoom coverage needs a 4K source so a
    /// 2× digital punch-in stays at/above the 1080p delivery target. Stays false
    /// otherwise (flag off, or device can't do 4K). Read-only to the rest of the
    /// app so it can tell whether this device is crop-zoom-capable.
    private(set) var supports4KCapture = false

    var onRecordingFinished: ((Result<URL, Error>) -> Void)?

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }

    func requestPermissions() async -> Bool {
        let cameraGranted: Bool
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            cameraGranted = true
        } else {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        }

        let micGranted: Bool
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            micGranted = true
        } else {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        return cameraGranted && micGranted
    }

    @discardableResult
    func startSession() -> Bool {
        guard !session.isRunning else { return true }

        if !isConfigured {
            session.beginConfiguration()
            session.sessionPreset = .high

            var hasVideo = false

            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let videoInput = try? AVCaptureDeviceInput(device: camera),
               session.canAddInput(videoInput) {
                session.addInput(videoInput)
                hasVideo = true

                // Phase 0 (intelligent cutting): opt into 4K capture ONLY when the
                // coverage-cutting flag is on AND the active device/session can do
                // it. canSetSessionPreset is evaluated after the input is added, so
                // it reflects this session's real graph. If either is false the
                // preset stays .high (1080p) and capture is byte-for-byte unchanged.
                if FeatureFlags.useCoverageCutting,
                   session.canSetSessionPreset(.hd4K3840x2160) {
                    session.sessionPreset = .hd4K3840x2160
                    supports4KCapture = true
                }
            }

            if let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }

            session.commitConfiguration()
            isConfigured = true

            guard hasVideo else { return false }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
        return true
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func startRecording(to url: URL) {
        guard !movieOutput.isRecording else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        DispatchQueue.main.async { [weak self] in
            if let error {
                self?.onRecordingFinished?(.failure(error))
            } else {
                self?.onRecordingFinished?(.success(outputFileURL))
            }
        }
    }
}
