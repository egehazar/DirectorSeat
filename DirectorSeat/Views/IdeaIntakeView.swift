import SwiftUI

struct IdeaIntakeView: View {
    @StateObject private var viewModel = IdeaIntakeViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showQuickContext = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.xs)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.ideaText)
                            .scrollContentBackground(.hidden)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if viewModel.ideaText.isEmpty {
                            Text(viewModel.currentPlaceholder)
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
                    .overlay(alignment: .bottomTrailing) {
                        if !viewModel.ideaText.isEmpty {
                            Text("\(viewModel.ideaText.count)/200")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                                .padding(Theme.Spacing.md)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    Text("Or pick a vibe")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.lg)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(viewModel.archetypes) { archetype in
                                ArchetypeCard(archetype: archetype) {
                                    viewModel.selectArchetype(archetype.name)
                                }
                            }
                        }
                        .padding(.leading, Theme.Spacing.lg)
                    }
                    .padding(.top, Theme.Spacing.md)

                    DSPrimaryButton(title: "Next") {
                        showQuickContext = true
                    }
                    .disabled(!viewModel.canProceed)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showQuickContext) {
            QuickContextView(ideaText: viewModel.ideaText)
        }
        .onChange(of: viewModel.ideaText) { _, newValue in
            if newValue.count > 200 {
                viewModel.ideaText = String(newValue.prefix(200))
            }
        }
    }
}

private struct ArchetypeCard: View {
    let archetype: Archetype
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: archetype.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Colors.accent)
                Text(archetype.name)
                    .font(Theme.Typography.caption.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(width: 120, height: 120)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        IdeaIntakeView()
    }
}
