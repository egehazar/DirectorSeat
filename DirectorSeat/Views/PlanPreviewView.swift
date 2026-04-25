import SwiftUI

struct PlanPreviewView: View {
    let plan: FilmmakingPlan
    @Environment(\.dismiss) private var dismiss

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
                                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                            Text("SHOT \(shot.shotNumber) \u{00B7} \(shot.shotType.uppercased())")
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                                .tracking(1.5)

                                            Text(shot.directionText)
                                                .font(Theme.Typography.body)
                                                .foregroundStyle(Theme.Colors.textPrimary)

                                            if let dialogue = shot.dialogue {
                                                Text("\u{201C}\(dialogue)")
                                                    .font(Theme.Typography.body.italic())
                                                    .foregroundStyle(Theme.Colors.textSecondary)
                                            }
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
                    print("Shooting mode next")
                }

                Text("Next: setup checklist")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PlanPreviewView(plan: .sample)
    }
}
