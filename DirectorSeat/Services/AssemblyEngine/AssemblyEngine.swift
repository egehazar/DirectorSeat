import AVFoundation
import CoreMedia
import Foundation

/// Public surface of the assembly engine. Composes Layer 1 (TimelineBuilder),
/// Layer 2 (CompositionAssembler), and Layer 3 (Exporter) into one async call.
final class AssemblyEngine {

    private let timelineBuilder = TimelineBuilder()
    private let compositionAssembler = CompositionAssembler()
    private let exporter = Exporter()

    /// Spec-shaped entry point: caller provides SelectedTakes (each carrying its
    /// pre-loaded duration) plus an optional music URL, and gets back a finished
    /// .mov at `outputURL`.
    func assemble(
        plan: FilmmakingPlan,
        takes: [SelectedTake],
        musicURL: URL?,
        outputURL: URL,
        progress: @escaping (Float) -> Void
    ) async throws -> URL {

        // Layer 1: build the editorial timeline (pure).
        let timeline = try timelineBuilder.build(
            plan: plan,
            takes: takes,
            hasMusicURL: musicURL != nil
        )

        if !timeline.diagnostics.isEmpty {
            for d in timeline.diagnostics {
                let prefix = d.severity == .warning ? "[AssemblyEngine][warn]" : "[AssemblyEngine][info]"
                let shotTag = d.shotGlobalNumber.map { " shot #\($0):" } ?? ""
                print("\(prefix)\(shotTag) \(d.message)")
            }
        }

        // Layer 2: translate to AVFoundation objects.
        let assembled = try await compositionAssembler.assemble(
            timeline: timeline,
            musicURL: musicURL
        )

        // Layer 3: export.
        return try await exporter.export(
            composition: assembled.composition,
            videoComposition: assembled.videoComposition,
            audioMix: assembled.audioMix,
            outputURL: outputURL,
            progress: progress
        )
    }

    /// Convenience entry point matching the legacy `VideoAssemblyService` shape:
    /// call site passes `[URL]` in shot order and the engine pre-loads durations
    /// before invoking Layer 1. Constructs synthetic `SelectedTake.shotGlobalNumber`
    /// values (1-indexed) to match the plan's flatten order.
    func assembleFromOrderedURLs(
        plan: FilmmakingPlan,
        takeURLs: [URL],
        musicURL: URL?,
        outputURL: URL,
        progress: @escaping (Float) -> Void
    ) async throws -> URL {

        let preflight = try await preflightTakes(urls: takeURLs)
        return try await assemble(
            plan: plan,
            takes: preflight,
            musicURL: musicURL,
            outputURL: outputURL,
            progress: progress
        )
    }

    private func preflightTakes(urls: [URL]) async throws -> [SelectedTake] {
        var result: [SelectedTake] = []
        for (i, url) in urls.enumerated() {
            let global = i + 1
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AssemblyError.missingSourceFile(shotGlobalNumber: global)
            }
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            result.append(SelectedTake(shotGlobalNumber: global, sourceURL: url, duration: duration))
        }
        return result
    }
}
