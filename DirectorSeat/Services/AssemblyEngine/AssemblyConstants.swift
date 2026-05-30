import CoreMedia
import Foundation

/// Engine-wide tunable constants. Centralized so they can be adjusted in one place
/// after first hardware audition.
enum AssemblyConstants {
    // Transition durations (seconds)
    static let crossfadeDuration: TimeInterval = 0.7
    static let fadeFromBlackDuration: TimeInterval = 1.0
    static let fadeToBlackDuration: TimeInterval = 1.0

    // Music fades (seconds)
    static let musicFadeInDuration: TimeInterval = 1.5
    static let musicFadeOutDuration: TimeInterval = 1.5

    // Boundary audio ramp (seconds)
    static let boundaryAudioRampDuration: TimeInterval = 0.05

    // Default hold cap when shot.recommendedHoldSeconds is nil
    static let defaultMaxHoldSeconds: TimeInterval = 6.0

    // Minimum on-screen duration for a coverage intercut segment. Rapid dialogue
    // would otherwise produce sub-second cuts that strobe; slices below this floor
    // are merged into a neighbour so no intercut segment is shorter than this
    // (except a whole beat that is itself shorter than the floor). Tunable after
    // first hardware audition.
    static let minCoverageSegmentSeconds: TimeInterval = 1.2

    // Frame rate for video composition
    static let frameRate: Int32 = 30

    // Standard timescale for AVFoundation-friendly CMTime arithmetic.
    // 600 divides cleanly by 24/25/30 fps and milliseconds.
    static let timeScale: CMTimeScale = 600

    // Audio volumes per AudioTreatment
    static let dialoguePriorityVideoVolume: Float = 1.0
    static let dialoguePriorityMusicVolume: Float = 0.25
    static let musicPriorityVideoVolume: Float = 0.30
    static let musicPriorityMusicVolume: Float = 1.0
    static let ambientOnlyVideoVolume: Float = 1.0
    static let ambientOnlyMusicVolume: Float = 0.0
    static let silentVideoVolume: Float = 0.0
    static let silentMusicVolume: Float = 0.0
    static let crescendoVideoVolume: Float = 1.0
    static let crescendoMusicRampStart: Float = 0.30
    static let crescendoMusicRampEnd: Float = 1.0
}

extension CMTime {
    /// Convenience constructor at the engine's standard timescale.
    static func seconds(_ s: TimeInterval) -> CMTime {
        CMTime(seconds: s, preferredTimescale: AssemblyConstants.timeScale)
    }
}
