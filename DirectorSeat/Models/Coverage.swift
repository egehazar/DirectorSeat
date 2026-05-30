import Foundation

// Coverage data model for the intelligent-cutting / adaptive-coverage epic
// (see docs/intelligent-cutting-spec.md). These types describe how a single
// dialogue beat can be covered by multiple angles so the AssemblyEngine can
// intercut "to whoever's talking."
//
// PHASE 1 (this file) only DEFINES the shape. Nothing reads it yet:
// `Shot.coverage` is optional and defaults to nil, and a shot with `coverage ==
// nil` is treated as a linear shot — byte-for-byte today's behavior. No engine,
// plan-generation, or intercut logic is wired up in this phase.
//
// Coding keys are snake_case to match the rest of the persisted plan JSON.

/// Declares a shot's part in a multi-angle dialogue beat. Shots sharing a
/// `beatId` cover the same dialogue beat.
struct CoverageRole: Codable, Equatable {
    /// Shots with the same `beatId` cover the same dialogue beat.
    let beatId: Int
    /// What kind of source this shot is.
    let kind: CoverageKind
    /// Ordered speaker runs this shot's take contains (see `LineRun`).
    let lineRuns: [LineRun]

    enum CodingKeys: String, CodingKey {
        case beatId = "beat_id"
        case kind
        case lineRuns = "line_runs"
    }
}

/// The role a coverage shot plays as a source for the intercut.
enum CoverageKind: String, Codable, Equatable {
    /// A wide two-shot the engine digitally punches into to fake each speaker's
    /// close-up (solo crop-zoom).
    case cropZoomSource = "crop_zoom_source"
    /// A physically distinct take (a guided solo insert, or a second camera in
    /// the multi-phone path).
    case separateAngle = "separate_angle"
}

/// One contiguous run of a single speaker within a take. There are deliberately
/// NO timestamps — the locked design forbids speech detection/diarization.
/// `estimatedSeconds` is a RELATIVE WEIGHT the engine scales onto the take's
/// real recorded duration to place run boundaries proportionally.
struct LineRun: Codable, Equatable {
    /// Matches a cast `role_name` / `dialogueDirection.speaker`.
    let speaker: String
    /// The line spoken during this run, if any.
    let lineText: String?
    /// Relative weight for proportional placement (NOT an absolute timestamp).
    let estimatedSeconds: Double
    /// What the engine should SHOW during this run.
    let angle: CoverageAngle

    enum CodingKeys: String, CodingKey {
        case speaker
        case lineText = "line_text"
        case estimatedSeconds = "estimated_seconds"
        case angle
    }
}

/// What to display for a given `LineRun`.
/// - `wide`: show the source wide untouched.
/// - `cropZoom`: digitally punch into the wide at `region`.
/// - `separateAngle`: cut to another physical take by its global shot number.
enum CoverageAngle: Codable, Equatable {
    case wide
    case cropZoom(region: NormalizedRect)
    case separateAngle(globalShotNumber: Int)
}

/// A rectangle in normalized (0...1) coordinates of the source's DISPLAY space
/// (post-`preferredTransform`). Used to declare a crop-zoom punch-in region.
struct NormalizedRect: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
