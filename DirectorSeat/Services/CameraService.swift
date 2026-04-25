import AVFoundation

class CameraService: NSObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    let previewLayer: AVCaptureVideoPreviewLayer

    var onRecordingFinished: ((URL) -> Void)?

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

    func startSession() {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let videoInput = try? AVCaptureDeviceInput(device: camera),
           session.canAddInput(videoInput) {
            session.addInput(videoInput)
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
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
            self?.onRecordingFinished?(outputFileURL)
        }
    }
}
