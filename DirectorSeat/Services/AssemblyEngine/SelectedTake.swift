import CoreMedia
import Foundation

/// A take selected for assembly. `shotGlobalNumber` is 1-indexed across the plan
/// (matches `FilmmakingPlan.sceneAndShotIndex(forGlobal:)` semantics). `duration`
/// is the take's natural duration, pre-loaded so Layer 1 can stay pure.
struct SelectedTake: Equatable, Hashable {
    let shotGlobalNumber: Int
    let sourceURL: URL
    let duration: CMTime
}
