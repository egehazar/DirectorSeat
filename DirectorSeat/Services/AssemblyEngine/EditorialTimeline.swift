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
