import AVFoundation

class CameraService: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    let previewLayer: AVCaptureVideoPreviewLayer
    private var isConfigured = false

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
