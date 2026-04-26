import SwiftData
import SwiftUI

struct TemplateDetailView: View {
    let template: FilmTemplate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var planViewModel = PlanGenerationViewModel()
    @State private var customization = ""
    @State private var showGeneration = false
    @State private var project: FilmProject?

    private var canProceed: Bool {
        customization.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

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

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        storyStructure
                        customizationSection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 100)
                }

                LinearGradient(
                    colors: [Theme.Colors.background.opacity(0), Theme.Colors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)
            }

            VStack(spacing: Theme.Spacing.sm) {
                DSPrimaryButton(title: "Use This Template") {
                    startGeneration()
                }
                .disabled(!canProceed)

                Text(canProceed ? "Next: we'll build your plan" : "Describe your version (at least 20 characters)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(isPresented: $showGeneration) {
            TemplateGenerationFlowView(viewModel: planViewModel, project: project)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("TEMPLATE")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(2)
                .padding(.top, Theme.Spacing.lg)

            Text(template.title)
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(template.description)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.xs)

            Text("\(template.scenes.count) scenes \u{00B7} \(template.totalShots) shots \u{00B7} \(template.castLabel)")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.top, Theme.Spacing.sm)
        }
    }

    // MARK: - Story Structure

    private var storyStructure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STORY STRUCTURE")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)
                .padding(.top, Theme.Spacing.xl)

            ForEach(template.scenes, id: \.sceneNumber) { scene in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Rectangle()
                            .fill(Theme.Colors.surface)
                            .frame(width: 40, height: 1)

                        Text("SCENE \(scene.sceneNumber) \u{00B7} \(scene.beatDescription)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.accent)
                            .tracking(1.5)
                    }
                    .padding(.top, Theme.Spacing.lg)

                    Text(scene.placeholderDescription)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, Theme.Spacing.sm)

                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(scene.shots, id: \.shotNumber) { shot in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("SHOT \(shot.shotNumber) \u{00B7} \(shot.shotType.uppercased())")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                                    .tracking(1)

                                Text(shot.beatPurpose)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.accent.opacity(0.8))

                                Text(shot.placeholderDirection)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
    }

    // MARK: - Customization

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("MAKE IT YOURS")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1.5)
                .padding(.top, Theme.Spacing.xl)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $customization)
                    .scrollContentBackground(.hidden)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if customization.isEmpty {
                    Text("Describe your version. Where? Who? What's the specific situation?")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(height: 120)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Generation

    private func startGeneration() {
        let store = ProjectStore(modelContext: modelContext)
        let cast = CastChoice.fromCastSize(template.castSize)
        let newProject = store.createProject(
            ideaText: customization,
            castChoice: cast,
            contextText: ""
        )
        newProject.templateID = template.id
        newProject.templateCustomization = customization
        newProject.title = template.title
        newProject.filmTitle = template.title
        try? modelContext.save()

        project = newProject
        showGeneration = true
        Task {
            await planViewModel.generateFromTemplate(template: template, customization: customization)
        }
    }
}

// MARK: - Generation Flow

private struct TemplateGenerationFlowView: View {
    @ObservedObject var viewModel: PlanGenerationViewModel
    var project: FilmProject?

    var body: some View {
        switch viewModel.state {
        case .success(let plan):
            PlanPreviewView(plan: plan, project: project)
                .onAppear { savePlanToProject(plan) }
        default:
            PlanGenerationLoadingView(viewModel: viewModel)
        }
    }

    private func savePlanToProject(_ plan: FilmmakingPlan) {
        guard let project, project.planJSON == nil else { return }
        project.plan = plan
        project.status = "planning"
        try? project.modelContext?.save()
    }
}

#Preview {
    NavigationStack {
        TemplateDetailView(template: FilmTemplate.library[0])
    }
}
