import Combine
import SwiftUI

enum CastChoice: String {
    case solo, pair, group, decideLater
}

class QuickContextViewModel: ObservableObject {
    @Published var currentCard: Int
    @Published var castChoice: CastChoice?
    @Published var contextText = ""

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
