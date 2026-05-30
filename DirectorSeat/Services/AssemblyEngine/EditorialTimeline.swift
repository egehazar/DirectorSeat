import CoreMedia
import Foundation

struct EditorialTimeline: Equatable {
    let segments: [TimelineSegment]
    let transitions: [TimelineTransition]
    let audioRegions: [AudioRegion]
    let musicRegions: [MusicRegion]
    let totalDuration: CMTime
    let diagnostics: [AssemblyDiagnostic]
}

struct TimelineSegment: Equatable {
    let shotGlobalNumber: Int
    let sourceURL: URL
    let sourceTimeRange: CMTimeRange
    let timelineTimeRange: CMTimeRange
    let trackIndex: Int
    /// Crop-zoom punch-in region (normalized 0...1 in the source's display space)
    /// for coverage intercut segments. nil for linear and full-frame segments —
    /// "render the take as-is." Phase 3 (CompositionAssembler) applies the crop;
    /// Layer 1 only records it. Defaulted so existing call sites are unchanged.
    var cropRect: NormalizedRect? = nil
}

struct TimelineTransition: Equatable {
    enum Kind: Equatable {
        case crossfade
        case fadeToBlack
        case fadeFromBlack
    }
    let kind: Kind
    let duration: CMTime
    let timeRange: CMTimeRange
    let outgoingSegmentIndex: Int?
    let incomingSegmentIndex: Int?
}

struct AudioRegion: Equatable {
    let timeRange: CMTimeRange
    let videoVolume: VolumeCurve
    let musicVolume: VolumeCurve
}

enum VolumeCurve: Equatable {
    case constant(Float)
    case ramp(from: Float, to: Float)

    var startLevel: Float {
        switch self {
        case .constant(let v): return v
        case .ramp(let from, _): return from
        }
    }

    var endLevel: Float {
        switch self {
        case .constant(let v): return v
        case .ramp(_, let to): return to
        }
    }
}

struct MusicRegion: Equatable {
    let timeRange: CMTimeRange
    let fadeInDuration: CMTime
    let fadeOutDuration: CMTime
}

struct AssemblyDiagnostic: Equatable {
    enum Severity: Equatable { case info, warning }
    let severity: Severity
    let shotGlobalNumber: Int?
    let message: String
}
