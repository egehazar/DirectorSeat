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
    private var slowWarningTask: Task<Void, Never>?
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
        startSlowWarning()

        do {
            let plan = try await service.generate(
                idea: lastIdea,
                cast: lastCast,
                context: lastContext,
                language: lastLanguage,
                onRetryAttempt: { [weak self] attempt in
                    self?.handleRetryAttempt(attempt)
                }
            )
            state = .success(plan)
        } catch {
            let message = error.localizedDescription
            state = .failure(message)
            lastError = message
            showError = true
        }

        cancelSlowWarning()
        stopLoadingMessageCycle()
    }

    private func performTemplateGeneration() async {
        guard let template = lastTemplate else { return }
        state = .loading
        messageIndex = 0
        currentLoadingMessage = loadingMessages[0]
        startLoadingMessageCycle()
        startSlowWarning()

        do {
            let plan = try await service.generateFromTemplate(
                template: template,
                customization: lastIdea,
                cast: lastCast,
                onRetryAttempt: { [weak self] attempt in
                    self?.handleRetryAttempt(attempt)
                }
            )
            state = .success(plan)
        } catch {
            let message = error.localizedDescription
            state = .failure(message)
            lastError = message
            showError = true
        }

        cancelSlowWarning()
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

    /// After 30 seconds, swap the rotating "almost there" copy for an honest
    /// "still working — taking longer than usual" message so the user knows
    /// the request is in flight, not stuck.
    private func startSlowWarning() {
        slowWarningTask?.cancel()
        slowWarningTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.stopLoadingMessageCycle()
            self.currentLoadingMessage = "Still working — this is taking longer than usual..."
        }
    }

    private func cancelSlowWarning() {
        slowWarningTask?.cancel()
        slowWarningTask = nil
    }

    /// APIRetry calls this before each attempt. Attempt 1 is the first try
    /// (no message change). Attempt 2+ surfaces a "Retrying..." state so the
    /// user knows we're recovering from a transient failure rather than stuck.
    private func handleRetryAttempt(_ attempt: Int) {
        guard attempt > 1 else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopLoadingMessageCycle()
            self.currentLoadingMessage = "Reconnecting — retrying (attempt \(attempt) of 3)..."
        }
    }
}
