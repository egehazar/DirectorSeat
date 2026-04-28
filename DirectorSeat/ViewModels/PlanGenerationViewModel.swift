import Combine
import Foundation

enum GenerationState {
    case idle
    case loading
    case success(FilmmakingPlan)
    case failure(String)
}

class PlanGenerationViewModel: ObservableObject {
    @Published var state: GenerationState = .idle
    @Published var currentLoadingMessage = "Writing your logline..."
    @Published var showError = false
    var lastError = ""

    private let service = PlanGenerationService()
    private var timerCancellable: AnyCancellable?
    private var lastIdea = ""
    private var lastCast: CastChoice = .decideLater
    private var lastContext = ""
    private var lastLanguage: String?
    private var lastTemplate: FilmTemplate?

    private let loadingMessages = [
        "Writing your logline...",
        "Building scenes...",
        "Designing shots...",
        "Almost there...",
    ]
    private var messageIndex = 0

    func generate(idea: String, cast: CastChoice, context: String, language: String? = nil) async {
        lastIdea = idea
        lastCast = cast
        lastContext = context
        lastLanguage = language
        lastTemplate = nil
        await performGeneration()
    }

    func generateFromTemplate(template: FilmTemplate, customization: String) async {
        lastTemplate = template
        lastIdea = customization
        lastCast = CastChoice.fromCastSize(template.castSize)
        lastContext = ""
        await performTemplateGeneration()
    }

    func retry() async {
        if lastTemplate != nil {
            await performTemplateGeneration()
        } else {
            await performGeneration()
        }
    }

    private func performGeneration() async {
        state = .loading
        messageIndex = 0
        currentLoadingMessage = loadingMessages[0]
        startLoadingMessageCycle()

        do {
            let plan = try await service.generate(idea: lastIdea, cast: lastCast, context: lastContext, language: lastLanguage)
            state = .success(plan)
        } catch {
            let message = error.localizedDescription
            state = .failure(message)
            lastError = message
            showError = true
        }

        stopLoadingMessageCycle()
    }

    private func performTemplateGeneration() async {
        guard let template = lastTemplate else { return }
        state = .loading
        messageIndex = 0
        currentLoadingMessage = loadingMessages[0]
        startLoadingMessageCycle()

        do {
            let plan = try await service.generateFromTemplate(
                template: template,
                customization: lastIdea,
                cast: lastCast
            )
            state = .success(plan)
        } catch {
            let message = error.localizedDescription
            state = .failure(message)
            lastError = message
            showError = true
        }

        stopLoadingMessageCycle()
    }

    private func startLoadingMessageCycle() {
        timerCancellable = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.messageIndex = (self.messageIndex + 1) % self.loadingMessages.count
                self.currentLoadingMessage = self.loadingMessages[self.messageIndex]
            }
    }

    private func stopLoadingMessageCycle() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
