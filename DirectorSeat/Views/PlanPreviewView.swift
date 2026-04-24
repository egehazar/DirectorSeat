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

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(plan.logline)
                        .font(Theme.Typography.heroTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("\(plan.scenes.count) scenes \u{00B7} \(totalShots) shots \u{00B7} ~\(plan.estimatedTotalShootMinutes) min to shoot")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    ForEach(plan.scenes) { scene in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Scene \(scene.sceneNumber)")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Text(scene.description)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textSecondary)

                            ForEach(scene.shots) { shot in
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Text("Shot \(shot.shotNumber): \(shot.shotType)")
                                        .font(Theme.Typography.body.bold())
                                        .foregroundStyle(Theme.Colors.textPrimary)

                                    Text(shot.directionText)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                .padding(.top, Theme.Spacing.xs)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }

            DSPrimaryButton(title: "Let's Shoot") {
                print("Shooting mode next")
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)
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
