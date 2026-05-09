import Foundation

/// Runtime-tunable feature toggles.
enum FeatureFlags {
    /// Use the new `AssemblyEngine` (Layer 1/2/3 architecture honoring editorial
    /// metadata) instead of the legacy `VideoAssemblyService` naive concatenation.
    /// Falls back to the legacy service when set to false.
    static let useAssemblyEngine: Bool = true
}
