import SwiftUI

struct ShotReviewView: View {
    let totalShots: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.accent)

            Text("All \(totalShots) shots captured!")
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Coming next: Review and Assembly")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            DSPrimaryButton(title: "Done") {
                dismiss()
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ShotReviewView(totalShots: 7)
}
