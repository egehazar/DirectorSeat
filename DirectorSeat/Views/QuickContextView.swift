import SwiftUI

private struct CastOption: Identifiable {
    var id: CastChoice { choice }
    let icon: String
    let label: String
    let choice: CastChoice
}

private let castOptions = [
    CastOption(icon: "person.fill", label: "Just me", choice: .solo),
    CastOption(icon: "person.2.fill", label: "Me and 1 other person", choice: .pair),
    CastOption(icon: "person.3.fill", label: "A group", choice: .group),
    CastOption(icon: "questionmark.circle", label: "Decide later", choice: .decideLater),
]

struct QuickContextView: View {
    let ideaText: String
    @StateObject private var viewModel: QuickContextViewModel
    @Environment(\.dismiss) private var dismiss

    init(ideaText: String, initialCard: Int = 1) {
        self.ideaText = ideaText
        _viewModel = StateObject(wrappedValue: QuickContextViewModel(initialCard: initialCard))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        if viewModel.currentCard == 1 {
                            dismiss()
                        } else {
                            viewModel.goBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(Theme.Spacing.xs)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)

                HStack(spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.currentCard == 1 ? Theme.Colors.accent : Theme.Colors.surface)
                        .frame(width: 40, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.currentCard == 2 ? Theme.Colors.accent : Theme.Colors.surface)
                        .frame(width: 40, height: 4)
                }
                .padding(.top, Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .zIndex(1)

            ZStack {
                if viewModel.currentCard == 1 {
                    card1View
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    card2View
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentCard)
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var card1View: some View {
        VStack(spacing: 0) {
            Text("Who's in this film?")
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xxl)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(castOptions) { option in
                    Button {
                        viewModel.selectCast(option.choice)
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: option.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: 32)
                            Text(option.label)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .frame(height: 72)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(viewModel.castChoice == option.choice ? Theme.Colors.accent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)

            Spacer()
        }
    }

    private var card2View: some View {
        VStack(spacing: 0) {
            Text("Anything we should know?")
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xxl)

            Text("Optional")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
                .padding(.top, Theme.Spacing.sm)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.contextText)
                    .scrollContentBackground(.hidden)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if viewModel.contextText.isEmpty {
                    Text("e.g. tripod, time limit, outdoors...")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(height: 100)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    printCollectedData()
                } label: {
                    Text("Skip")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                DSPrimaryButton(title: "Create My Film") {
                    printCollectedData()
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private func printCollectedData() {
        print("Idea: \(ideaText)")
        print("Cast: \(viewModel.castChoice.map { "\($0)" } ?? "none")")
        print("Context: \(viewModel.contextText)")
    }
}

#Preview("Card 1") {
    NavigationStack {
        QuickContextView(ideaText: "A person hears footsteps in their apartment at night.")
    }
}

#Preview("Card 2") {
    NavigationStack {
        QuickContextView(ideaText: "A person hears footsteps in their apartment at night.", initialCard: 2)
    }
}
