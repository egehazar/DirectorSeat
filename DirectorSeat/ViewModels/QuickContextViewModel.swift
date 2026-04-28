import Combine
import SwiftUI

enum CastChoice: String {
    case solo, pair, group, decideLater

    static func fromCastSize(_ size: Int) -> CastChoice {
        switch size {
        case 1: .solo
        case 2: .pair
        default: .group
        }
    }
}

enum ShootingLanguage: String, CaseIterable {
    case auto = "auto"
    case english = "en"
    case turkish = "tr"
    case spanish = "es"
    case portuguese = "pt"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case tagalog = "tl"
    case indonesian = "id"
    case arabic = "ar"
    case hindi = "hi"

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .turkish: return "Turkish"
        case .spanish: return "Spanish"
        case .portuguese: return "Portuguese"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .tagalog: return "Tagalog"
        case .indonesian: return "Indonesian"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        }
    }
}

class QuickContextViewModel: ObservableObject {
    @Published var currentCard: Int
    @Published var castChoice: CastChoice?
    @Published var contextText = ""
    @Published var shootingLanguage: ShootingLanguage = .auto

    init(initialCard: Int = 1) {
        currentCard = initialCard
    }

    func selectCast(_ choice: CastChoice) {
        castChoice = choice
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            currentCard = 2
        }
    }

    func goBack() {
        if currentCard == 2 {
            currentCard = 1
        }
    }
}
