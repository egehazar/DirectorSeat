import Foundation

enum AssemblyError: Error, LocalizedError, Equatable {
    case emptyPlan
    case missingSourceFile(shotGlobalNumber: Int)
    case missingTakeForShot(shotGlobalNumber: Int)
    case inconsistentSourceDimensions
    case missingVideoTrack(shotGlobalNumber: Int)
    case compositionSetupFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "Plan has no shots."
        case .missingSourceFile(let n):
            return "Source file missing for shot #\(n)."
        case .missingTakeForShot(let n):
            return "No selected take provided for shot #\(n)."
        case .inconsistentSourceDimensions:
            return "Source takes have inconsistent dimensions; V1 requires identical resolutions."
        case .missingVideoTrack(let n):
            return "Source asset for shot #\(n) has no video track."
        case .compositionSetupFailed(let m):
            return "Could not build composition: \(m)"
        case .exportFailed(let m):
            return "Export failed: \(m)"
        }
    }
}
