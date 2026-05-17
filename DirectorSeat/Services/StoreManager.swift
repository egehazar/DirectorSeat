import Combine
import Foundation
import StoreKit
import UIKit

/// Manages product loading, purchases, and transaction listening via
/// StoreKit 2. Source of truth for purchase events; calls into
/// CreditWallet to grant credits when purchases succeed.
@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    /// Product IDs known to the app. One consumable for V1.1.
    static let productIDs: Set<String> = [
        "com.tastefyapp.DirectorSeat.filmexport"
    ]

    /// Credits granted per product. When a purchase of a product completes,
    /// this many credits are added to the wallet.
    static let creditsPerProduct: [String: Int] = [
        "com.tastefyapp.DirectorSeat.filmexport": 1
    ]

    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastError: StoreError?

    private var transactionListenerTask: Task<Void, Never>?

    enum StoreError: Error, LocalizedError, Equatable {
        case productsNotLoaded
        case purchaseFailed(String)
        case verificationFailed
        case userCancelled
        case pending
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .productsNotLoaded: return "Products couldn't be loaded from the App Store. Check your internet connection."
            case .purchaseFailed(let msg): return "Purchase failed: \(msg)"
            case .verificationFailed: return "We couldn't verify the purchase. Please contact support."
            case .userCancelled: return "Purchase cancelled."
            case .pending: return "Your purchase is awaiting approval. We'll add your credit when it's approved."
            case .unknown(let msg): return msg
            }
        }
    }

    enum PurchaseResult: Equatable {
        case success(creditsGranted: Int)
        case userCancelled
        case pending
    }

    private init() {
        self.transactionListenerTask = Task.detached(priority: .background) { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    /// Load product metadata from App Store / StoreKit Configuration.
    /// Call once on app launch.
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: Array(Self.productIDs))
            self.availableProducts = products
            self.lastError = nil
        } catch {
            self.lastError = .productsNotLoaded
        }
    }

    /// Purchase a product. Returns success/cancellation/pending state.
    /// On success, the corresponding number of credits is granted.
    func purchase(_ product: Product) async throws -> PurchaseResult {
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            let storeError: StoreError = .purchaseFailed(error.localizedDescription)
            self.lastError = storeError
            throw storeError
        }

        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(verification)
            let credits = Self.creditsPerProduct[transaction.productID] ?? 0
            CreditWallet.shared.grantCredits(credits)
            await transaction.finish()
            return .success(creditsGranted: credits)

        case .userCancelled:
            return .userCancelled

        case .pending:
            return .pending

        @unknown default:
            throw StoreError.unknown("Unknown purchase result")
        }
    }

    /// Restore purchases — for consumables this primarily processes any
    /// unfinished transactions (e.g., approved Ask to Buy that arrived
    /// while app was closed).
    func restorePurchases() async {
        for await result in Transaction.unfinished {
            do {
                let transaction = try verifiedTransaction(result)
                if let credits = Self.creditsPerProduct[transaction.productID] {
                    CreditWallet.shared.grantCredits(credits)
                }
                await transaction.finish()
            } catch {
                // Ignore unverified transactions; they'll re-appear if real.
            }
        }
    }

    /// Present the App Store's promo code redemption sheet. Apple handles
    /// the redemption UI and delivers the resulting transaction through
    /// the transaction listener. Requires an active UIWindowScene.
    func presentCodeRedemption() async {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        else {
            self.lastError = .unknown("No active window scene to present code redemption.")
            return
        }
        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
        } catch {
            self.lastError = .unknown(error.localizedDescription)
        }
    }

    // MARK: - Private

    /// Unwraps a VerificationResult, throwing if Apple's signature check failed.
    private func verifiedTransaction(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let transaction):
            return transaction
        }
    }

    /// Listens for transaction updates (e.g., Ask to Buy approvals,
    /// server-side validation completions). Runs for the lifetime of
    /// the app.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try verifiedTransaction(result)
                if let credits = Self.creditsPerProduct[transaction.productID] {
                    CreditWallet.shared.grantCredits(credits)
                }
                await transaction.finish()
            } catch {
                // Unverified — skip.
            }
        }
    }
}
