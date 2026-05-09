import AVFoundation
import Foundation

/// Layer 3: thin wrapper around AVAssetExportSession. Runs the export, forwards
/// progress to the caller's closure, returns the output URL on success.
struct Exporter {

    func export(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition,
        audioMix: AVMutableAudioMix?,
        outputURL: URL,
        progress: @escaping (Float) -> Void
    ) async throws -> URL {

        // Remove any previous file at this URL to avoid AVFoundation's
        // "file already exists" failure mode.
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AssemblyError.exportFailed("Could not create export session.")
        }

        session.videoComposition = videoComposition
        if let audioMix { session.audioMix = audioMix }

        // Spawn the progress observer concurrently. Per Apple docs, observing
        // `states(updateInterval:)` is what drives an async-context export
        // forward; without iterating the sequence the export does not progress.
        let progressTask = Task {
            for await state in session.states(updateInterval: 0.1) {
                if case .exporting(let p) = state {
                    progress(Float(p.fractionCompleted))
                }
            }
        }

        do {
            try await session.export(to: outputURL, as: .mov)
        } catch {
            progressTask.cancel()
            throw AssemblyError.exportFailed(error.localizedDescription)
        }

        progressTask.cancel()
        progress(1.0)
        return outputURL
    }
}
