import SwiftUI

struct SetupChecklistView: View {
    let plan: FilmmakingPlan
    @Environment(\.dismiss) private var dismiss
    @State private var checkedItems: Set<String> = []

    private var items: [ChecklistItem] {
        var list: [ChecklistItem] = []

        let castCount = plan.cast.count
        if castCount <= 1 {
            list.append(ChecklistItem(
                id: "cast",
                title: "Your cast: just you",
                detail: "Solo shoot \u{2014} set the phone, get in frame, press record."
            ))
        } else if castCount == 2 {
            list.append(ChecklistItem(
                id: "cast",
                title: "Your cast: 2 people",
                detail: "Grab a friend. Any friend will do."
            ))
        } else {
            list.append(ChecklistItem(
                id: "cast",
                title: "Your cast: \(castCount) people",
                detail: "Time to round up the crew."
            ))
        }

        let locationDetail = plan.scenes.first?.locationDescription.lowercased() ?? "any quiet room"
        list.append(ChecklistItem(
            id: "location",
            title: "Your location",
            detail: locationDetail
        ))

        let propsDetail = plan.requiredStoryProps.isEmpty
            ? "Nothing special \u{2014} you're good."
            : plan.requiredStoryProps.joined(separator: ", ")
        list.append(ChecklistItem(
            id: "props",
            title: "Your props",
            detail: propsDetail
        ))

        list.append(ChecklistItem(
            id: "time",
            title: "Your time",
            detail: "About \(plan.estimatedTotalShootMinutes) minutes to shoot."
        ))

        list.append(ChecklistItem(
            id: "phone",
            title: "Your phone is ready",
            detail: "Make sure you have at least 2GB free."
        ))

        list.append(ChecklistItem(
            id: "tip",
            title: "Pro tip",
            detail: Self.tips.randomElement()!
        ))

        return list
    }

    private static let tips = [
        "Turn on Do Not Disturb so calls don't break your shoot.",
        "Wipe your phone's camera lens. Smudges will show.",
        "Charge your phone or have a charger nearby.",
        "Shoot in landscape for cinematic framing.",
        "If a take feels off, just retry. No one's grading you.",
    ]

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
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Text("ALMOST READY")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.accent)
                                .tracking(2)

                            Text("Before You Shoot")
                                .font(Theme.Typography.heroTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .padding(.top, Theme.Spacing.sm)

                            Text("Quick check before we start.")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                                .padding(.top, Theme.Spacing.md)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xl)

                        VStack(spacing: Theme.Spacing.lg) {
                            ForEach(items) { item in
                                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                                    Button {
                                        if checkedItems.contains(item.id) {
                                            checkedItems.remove(item.id)
                                        } else {
                                            checkedItems.insert(item.id)
                                        }
                                    } label: {
                                        checkboxView(checked: checkedItems.contains(item.id))
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        Text(item.title)
                                            .font(Theme.Typography.body.bold())
                                            .foregroundStyle(Theme.Colors.textPrimary)

                                        Text(item.detail)
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.xl)
                    }
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
                DSPrimaryButton(title: "I'm Ready to Shoot") {
                    print("Going to Shooting Mode")
                }

                Text("Tap when you're set up.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func checkboxView(checked: Bool) -> some View {
        ZStack {
            if checked {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
            } else {
                Circle()
                    .stroke(Theme.Colors.textSecondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: checked)
    }
}

private struct ChecklistItem: Identifiable {
    let id: String
    let title: String
    let detail: String
}

#Preview {
    NavigationStack {
        SetupChecklistView(plan: .sample)
    }
}
