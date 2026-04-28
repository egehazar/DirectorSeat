import SwiftData
import SwiftUI

struct PlanPreviewView: View {
    @State private var plan: FilmmakingPlan
    var project: FilmProject?
    @Environment(\.dismiss) private var dismiss
    @State private var showChecklist = false
    @State private var activeShotChat: ShotChatContext?

    init(plan: FilmmakingPlan, project: FilmProject? = nil) {
        _plan = State(initialValue: plan)
        self.project = project
    }

    private var totalShots: Int {
        plan.scenes.reduce(0) { $0 + $1.shots.count }
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
                        Text(plan.logline)
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(2)
                            .padding(.top, Theme.Spacing.lg)

                        Text("\(plan.scenes.count) scenes \u{00B7} \(totalShots) shots \u{00B7} ~\(plan.estimatedTotalShootMinutes) min to shoot")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.vertical, Theme.Spacing.sm)
                            .padding(.horizontal, Theme.Spacing.md)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, Theme.Spacing.md)

                        ForEach(plan.scenes) { scene in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Rectangle()
                                        .fill(Theme.Colors.surface)
                                        .frame(width: 40, height: 1)

                                    Text("SCENE \(scene.sceneNumber)")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.accent)
                                        .tracking(2)
                                }
                                .padding(.top, Theme.Spacing.xl)

                                Text(scene.description)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .padding(.top, Theme.Spacing.sm)

                                VStack(spacing: Theme.Spacing.sm) {
                                    ForEach(scene.shots) { shot in
                                        let globalNum = globalShotNumber(for: shot, in: scene)
                                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                            Text("SHOT \(shot.shotNumber) \u{00B7} \(shot.shotType.uppercased())")
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                                .tracking(1.5)

                                            Text(shot.directionText)
                                                .font(Theme.Typography.body)
                                                .foregroundStyle(Theme.Colors.textPrimary)

                                            if !shot.displayLine.isEmpty {
                                                Text("\u{201C}\(shot.displayLine)")
                                                    .font(Theme.Typography.body.italic())
                                                    .foregroundStyle(Theme.Colors.textSecondary)
                                            }
                                        }
                                        .padding(Theme.Spacing.md)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Theme.Colors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture {
                                            activeShotChat = ShotChatContext(shot: shot, globalShotNumber: globalNum)
                                        }
                                    }
                                }
                                .padding(.top, Theme.Spacing.md)
                            }
                        }
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
                DSPrimaryButton(title: "Let's Shoot") {
                    showChecklist = true
                }

                Text("Tap any shot to refine it \u{00B7} Next: setup checklist")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showChecklist) {
            SetupChecklistView(plan: plan, project: project)
        }
        .sheet(item: $activeShotChat, onDismiss: {
            savePlanToProject()
        }) { context in
            ShotChatView(
                plan: $plan,
                shot: context.shot,
                globalShotNumber: context.globalShotNumber,
                project: project,
                existingMessages: project?.conversations[context.globalShotNumber] ?? []
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helpers

    private func globalShotNumber(for shot: Shot, in scene: FilmScene) -> Int {
        var num = 0
        for s in plan.scenes {
            for sh in s.shots {
                num += 1
                if s.sceneNumber == scene.sceneNumber && sh.shotNumber == shot.shotNumber {
                    return num
                }
            }
        }
        return 0
    }

    private func savePlanToProject() {
        guard let project else { return }
        project.plan = plan
        try? project.modelContext?.save()
    }
}

private struct ShotChatContext: Identifiable {
    let id = UUID()
    let shot: Shot
    let globalShotNumber: Int
}

#Preview {
    NavigationStack {
        PlanPreviewView(plan: .sample)
    }
}
