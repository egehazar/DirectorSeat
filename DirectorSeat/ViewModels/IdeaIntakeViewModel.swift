import Combine
import SwiftUI

struct Archetype: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let description: String
    let starterIdea: String
}

class IdeaIntakeViewModel: ObservableObject {
    @Published var ideaText = ""
    @Published var currentPlaceholder: String

    let archetypes = [
        Archetype(name: "Suspense", icon: "eye.fill", description: "One secret. One room.", starterIdea: "A person hears footsteps in their apartment at night."),
        Archetype(name: "Comedy", icon: "face.smiling", description: "Laugh out loud moments.", starterIdea: "A job interview where everything that could go wrong, does."),
        Archetype(name: "Drama", icon: "theatermasks.fill", description: "Real emotions, real stakes.", starterIdea: "A parent and child sit in silence after a big argument."),
        Archetype(name: "Mystery", icon: "questionmark.circle.fill", description: "Something isn't right.", starterIdea: "A note is found in a library book that wasn't there yesterday."),
        Archetype(name: "Romance", icon: "heart.fill", description: "Two people. One spark.", starterIdea: "Two strangers reach for the same book at a café."),
        Archetype(name: "Chase", icon: "figure.run", description: "Someone's running.", starterIdea: "Someone sprints through a crowded market, clutching an envelope."),
        Archetype(name: "Goodbye", icon: "hand.wave.fill", description: "The last conversation.", starterIdea: "Two best friends share one last coffee before one moves away."),
        Archetype(name: "The Stranger", icon: "person.fill.questionmark", description: "Who are they?", starterIdea: "A person sits at your usual table and knows your name."),
        Archetype(name: "The Argument", icon: "bolt.fill", description: "Tension in the air.", starterIdea: "Two roommates argue over something small that means everything."),
        Archetype(name: "The Reunion", icon: "person.2.fill", description: "Years in the making.", starterIdea: "A person sees someone they haven't spoken to in ten years."),
    ]

    private let placeholders = [
        "A horror scene in a kitchen...",
        "Two friends saying goodbye...",
        "A stranger leaves a note...",
        "A first date gone wrong...",
    ]
    private var placeholderIndex = 0
    private var timerCancellable: AnyCancellable?

    var canProceed: Bool {
        !ideaText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        currentPlaceholder = placeholders[0]
        timerCancellable = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cyclePlaceholder()
            }
    }

    private func cyclePlaceholder() {
        placeholderIndex = (placeholderIndex + 1) % placeholders.count
        currentPlaceholder = placeholders[placeholderIndex]
    }

    func selectArchetype(_ name: String) {
        if let archetype = archetypes.first(where: { $0.name == name }) {
            ideaText = archetype.starterIdea
        }
    }
}
