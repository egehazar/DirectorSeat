import SwiftData
import SwiftUI

struct ShotChatView: View {
    @Binding var plan: FilmmakingPlan
    let shot: Shot
    let globalShotNumber: Int
    var project: FilmProject?
    @StateObject private var viewModel: ShotChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDialogueChips: Bool

    private static let dialogueChipPrompts = [
        "Make this funnier",
        "Three alternatives",
        "More subtle",
        "Different tone",
    ]

    init(plan: Binding<FilmmakingPlan>, shot: Shot, globalShotNumber: Int, project: FilmProject?, existingMessages: [ConversationMessage]) {
        _plan = plan
        self.shot = shot
        self.globalShotNumber = globalShotNumber
        self.project = project
        _viewModel = StateObject(wrappedValue: ShotChatViewModel(
            plan: plan.wrappedValue,
            shot: shot,
            globalShotNumber: globalShotNumber,
            existingMessages: existingMessages
        ))
        _showDialogueChips = State(initialValue: !existingMessages.contains { $0.role == .user })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.Colors.surface)

            if showDialogueChips, shot.dialogueDirection?.hasSpokenLine == true {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Self.dialogueChipPrompts, id: \.self) { prompt in
                            Button {
                                viewModel.inputText = prompt
                            } label: {
                                Text(prompt)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.accent)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .background(Theme.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isWaitingForResponse {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if showDialogueChips, viewModel.messages.contains(where: { $0.role == .user }) {
                        showDialogueChips = false
                    }
                    scrollToBottom(proxy)
                    saveConversation()
                }
                .onChange(of: viewModel.isWaitingForResponse) { _, waiting in
                    if waiting { scrollToBottom(proxy) }
                }
            }

            if let revision = viewModel.pendingRevision {
                revisionCard(revision)
            }

            if viewModel.messages.count >= 20 {
                costWarning
            }

            inputArea
        }
        .background(Theme.Colors.background)
        .onDisappear {
            saveConversation()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("REFINING")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(2)

            Text("Shot \(globalShotNumber) \u{00B7} \(shot.shotType.uppercased())")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(shot.directionText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Revision Card

    private func revisionCard(_ revision: ShotRevision) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("PROPOSED CHANGE")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(1.5)

            Text(revision.summary)
                .font(Theme.Typography.body.bold())
                .foregroundStyle(Theme.Colors.textPrimary)

            if !revision.dependentShotChanges.isEmpty {
                let shotNums = revision.dependentShotChanges.map { "Shot \($0.shotNumber)" }.joined(separator: ", ")
                Text("Also updates: \(shotNums)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    acceptRevision()
                } label: {
                    Text("Accept")
                        .font(Theme.Typography.body.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    viewModel.rejectRevision()
                } label: {
                    Text("Reject")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.accent.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.accent, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Cost Warning

    private var costWarning: some View {
        Text("This is a long conversation — consider accepting a change or starting fresh.")
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xs)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            TextField("Tell me what to change...", text: $viewModel.inputText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1...5)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit { viewModel.sendMessage() }

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(sendButtonDisabled ? Theme.Colors.textSecondary.opacity(0.3) : Theme.Colors.accent)
                    .frame(width: 40, height: 40)
            }
            .disabled(sendButtonDisabled)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }

    private var sendButtonDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isWaitingForResponse
    }

    // MARK: - Actions

    private func acceptRevision() {
        guard let updatedPlan = viewModel.applyRevision() else { return }
        plan = updatedPlan
        if let project {
            project.plan = updatedPlan
            try? project.modelContext?.save()
        }
    }

    private func saveConversation() {
        guard let project else { return }
        var convos = project.conversations
        convos[globalShotNumber] = viewModel.messages
        project.conversations = convos
        try? project.modelContext?.save()
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        let target: String? = viewModel.isWaitingForResponse ? "typing" : viewModel.messages.last?.id.uuidString
        if let id = viewModel.messages.last?.id, !viewModel.isWaitingForResponse {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
        } else if viewModel.isWaitingForResponse {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("typing", anchor: .bottom) }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.content)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(bubbleShape)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: Color {
        message.role == .user
            ? Theme.Colors.accent.opacity(0.15)
            : Theme.Colors.surface
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == .user {
            UnevenRoundedRectangle(
                topLeadingRadius: 16, bottomLeadingRadius: 16,
                bottomTrailingRadius: 4, topTrailingRadius: 16
            )
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: 16, bottomLeadingRadius: 4,
                bottomTrailingRadius: 16, topTrailingRadius: 16
            )
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.Colors.textSecondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: animate ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animate = true }
    }
}

#Preview {
    ShotChatView(
        plan: .constant(.sample),
        shot: FilmmakingPlan.sample.scenes[0].shots[0],
        globalShotNumber: 1,
        project: nil,
        existingMessages: []
    )
    .presentationDetents([.medium, .large])
}
