import Foundation

/// Runtime-tunable feature toggles.
enum FeatureFlags {
    /// Use the new `AssemblyEngine` (Layer 1/2/3 architecture honoring editorial
    /// metadata) instead of the legacy `VideoAssemblyService` naive concatenation.
    /// Falls back to the legacy service when set to false.
    static let useAssemblyEngine: Bool = true

    /// Master gate for the intelligent-cutting / adaptive-coverage epic (see
    /// docs/intelligent-cutting-spec.md). When false (default), nothing in the
    /// coverage pipeline engages and capture/assembly behave exactly as today.
    /// Phase 0 uses this solely to opt CameraService into 4K capture (required so
    /// a 2× crop-zoom punch-in stays at/above the 1080p delivery target).
    static let useCoverageCutting: Bool = false
}
