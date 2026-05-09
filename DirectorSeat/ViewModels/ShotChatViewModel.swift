import Combine
import Foundation

class ShotChatViewModel: ObservableObject {
    @Published var messages: [ConversationMessage] = []
    @Published var inputText = ""
    @Published var isWaitingForResponse = false
    @Published var pendingRevision: ShotRevision?
    @Published var error: String?

    let shot: Shot
    let globalShotNumber: Int
    private let service = PlanRefinementService()
    private(set) var plan: FilmmakingPlan

    init(plan: FilmmakingPlan, shot: Shot, globalShotNumber: Int, existingMessages: [ConversationMessage]) {
        self.plan = plan
        self.shot = shot
        self.globalShotNumber = globalShotNumber

        if existingMessages.isEmpty {
            messages = [
                ConversationMessage(
                    id: UUID(),
                    role: .assistant,
                    content: "What would you like to change about this shot?",
                    timestamp: Date(),
                    proposedRevision: nil
                ),
            ]
        } else {
            messages = existingMessages
            // Restore pending revision from last assistant message if present
            if let lastAssistant = existingMessages.last(where: { $0.role == .assistant }),
               let revision = lastAssistant.proposedRevision
            {
                pendingRevision = revision
            }
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWaitingForResponse else { return }

        let userMsg = ConversationMessage(
            id: UUID(),
            role: .user,
            content: text,
            timestamp: Date(),
            proposedRevision: nil
        )
        messages.append(userMsg)
        inputText = ""
        isWaitingForResponse = true
        error = nil

        Task { @MainActor in
            do {
                let response = try await service.refineShot(
                    plan: plan,
                    targetShotNumber: globalShotNumber,
                    conversationHistory: messages,
                    userMessage: text
                )
                messages.append(response)
                if let revision = response.proposedRevision {
                    pendingRevision = revision
                }
            } catch {
                // error.localizedDescription is now the specific APIError reason
                // (timeout / network / rate limit / etc.) thanks to APIErrorMapper.
                let errorMsg = ConversationMessage(
                    id: UUID(),
                    role: .assistant,
                    content: "\(error.localizedDescription). You can try sending your message again.",
                    timestamp: Date(),
                    proposedRevision: nil
                )
                messages.append(errorMsg)
                self.error = error.localizedDescription
            }
            isWaitingForResponse = false
        }
    }

    /// Applies the pending revision to the plan. Returns the updated plan, or nil on failure.
    func applyRevision() -> FilmmakingPlan? {
        guard let revision = pendingRevision else { return nil }
        guard let updated = plan.applyingRevision(revision) else { return nil }
        plan = updated
        pendingRevision = nil

        let confirmMsg = ConversationMessage(
            id: UUID(),
            role: .assistant,
            content: "Done! The change has been applied to your plan.",
            timestamp: Date(),
            proposedRevision: nil
        )
        messages.append(confirmMsg)
        return updated
    }

    func rejectRevision() {
        pendingRevision = nil
        let rejectMsg = ConversationMessage(
            id: UUID(),
            role: .assistant,
            content: "No problem — change rejected. What else would you like to adjust?",
            timestamp: Date(),
            proposedRevision: nil
        )
        messages.append(rejectMsg)
    }
}
