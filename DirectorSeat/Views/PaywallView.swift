import SwiftUI

struct PaywallView: View {
    @ObservedObject var exportState: ExportState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Theme.Colors.textSecondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, Theme.Spacing.md)

            Text("Almost there.")
                .font(Theme.Typography.heroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, Theme.Spacing.lg)

            Text("How would you like to export your film?")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.sm)

            VStack(spacing: Theme.Spacing.md) {
                // Paid option (prominent)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("RECOMMENDED")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.accent)
                        .tracking(2)

                    Text("Clean Export")
                        .font(Theme.Typography.body.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        bulletPoint("Remove watermark")
                        bulletPoint("Full quality")
                        bulletPoint("Ready to share anywhere")
                    }

                    Text("$4.99")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.top, Theme.Spacing.xs)

                    DSPrimaryButton(title: "Export Clean \u{2014} $4.99") {
                        // TODO(prompt #2): wire to StoreManager.purchase(...) and
                        // call exportState.proceedClean() on success.
                        dismiss()
                    }
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.Colors.accent, lineWidth: 1.5)
                )

                // Free option
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Free Export")
                        .font(Theme.Typography.body.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("With small DirectorSeat watermark")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Button {
                        exportState.proceedWithWatermark()
                        dismiss()
                    } label: {
                        Text("Export with Watermark")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)

            Spacer()

            Button {
                // TODO(prompt #2): wire to StoreManager.restorePurchases().
            } label: {
                Text("Restore purchases")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.bottom, Theme.Spacing.sm)

            Button { dismiss() } label: {
                Text("Maybe later")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .presentationDetents([.large])
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.Colors.accent)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
        }
    }
}

#Preview {
    PaywallView(exportState: ExportState())
}
