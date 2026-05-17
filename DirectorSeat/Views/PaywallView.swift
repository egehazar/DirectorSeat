import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject var exportState: ExportState
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var wallet = CreditWallet.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing: Bool = false
    @State private var purchaseError: String? = nil
    @State private var lastSeenBalance: Int = 0
    @State private var showCreditGrantedToast: Bool = false

    private static let productID = "com.tastefyapp.DirectorSeat.filmexport"

    private var product: Product? {
        storeManager.availableProducts.first(where: { $0.id == Self.productID })
    }

    private var localizedPrice: String {
        product?.displayPrice ?? "$4.99"
    }

    private var buyButtonTitle: String {
        if isPurchasing { return "Processing\u{2026}" }
        return "Export Clean \u{2014} \(localizedPrice)"
    }

    private var creditButtonTitle: String {
        let n = wallet.balance
        return "Export Clean (\(n) credit\(n == 1 ? "" : "s") available)"
    }

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

            if showCreditGrantedToast {
                Text("\u{2713} Credit added")
                    .font(Theme.Typography.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .padding(.top, Theme.Spacing.sm)
                    .transition(.opacity)
            }

            if wallet.balance > 0 {
                Text("\(wallet.balance) credit\(wallet.balance == 1 ? "" : "s") available")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.top, Theme.Spacing.xs)
            }

            if let error = purchaseError {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            VStack(spacing: Theme.Spacing.md) {
                if exportState.canExportClean {
                    creditAvailableCard
                } else {
                    purchaseCard
                }

                watermarkCard
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)

            Spacer()

            Button {
                Task {
                    await storeManager.restorePurchases()
                }
            } label: {
                Text("Restore purchases")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.bottom, Theme.Spacing.xs)

            Button {
                Task {
                    await storeManager.presentCodeRedemption()
                }
            } label: {
                Text("Have a promo code?")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.bottom, Theme.Spacing.sm)

            #if DEBUG
            Button("[DEBUG] Reset credits") {
                CreditWallet.shared._debugSetBalance(0)
            }
            .font(.caption2)
            .foregroundStyle(.gray)
            .padding(.bottom, Theme.Spacing.sm)
            #endif

            Button { dismiss() } label: {
                Text("Maybe later")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .presentationDetents([.large])
        .animation(.easeInOut(duration: 0.2), value: showCreditGrantedToast)
        .onAppear {
            lastSeenBalance = wallet.balance
        }
        .onChange(of: wallet.balance) { _, newValue in
            if newValue > lastSeenBalance {
                showCreditGrantedToast = true
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showCreditGrantedToast = false
                }
            }
            lastSeenBalance = newValue
        }
    }

    // MARK: - Cards

    private var purchaseCard: some View {
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

            Text(localizedPrice)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, Theme.Spacing.xs)

            DSPrimaryButton(title: buyButtonTitle, action: handleBuy)
                .disabled(isPurchasing || storeManager.availableProducts.isEmpty)

            if storeManager.availableProducts.isEmpty {
                if storeManager.isLoadingProducts {
                    Text("Loading\u{2026}")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                } else if storeManager.lastError != nil {
                    Text("Couldn't load purchase options. Check your connection and tap below to retry.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button("Retry") {
                        Task { await storeManager.loadProducts() }
                    }
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                }
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
    }

    private var creditAvailableCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("YOU HAVE A CREDIT")
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
            .padding(.bottom, Theme.Spacing.xs)

            DSPrimaryButton(title: creditButtonTitle, action: handleUseCredit)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.accent, lineWidth: 1.5)
        )
    }

    private var watermarkCard: some View {
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

    // MARK: - Actions

    private func handleBuy() {
        guard !isPurchasing else { return }
        guard let product else {
            purchaseError = "Product not available. Please try again."
            return
        }

        Task {
            isPurchasing = true
            purchaseError = nil
            defer { isPurchasing = false }
            do {
                let result = try await storeManager.purchase(product)
                switch result {
                case .success:
                    if exportState.proceedClean() {
                        dismiss()
                    } else {
                        purchaseError = "Credit wasn't applied. Try again."
                    }
                case .userCancelled:
                    break
                case .pending:
                    purchaseError = "Your purchase is awaiting approval. We'll add your credit when it's approved."
                }
            } catch let error as StoreManager.StoreError {
                purchaseError = error.errorDescription
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }

    private func handleUseCredit() {
        if exportState.proceedClean() {
            dismiss()
        } else {
            purchaseError = "Credit wasn't applied. Try again."
        }
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
