import Combine
import Foundation

/// Tracks how many film export credits the user has available.
/// One credit allows one clean (no-watermark) export.
/// Credits are added by purchases (or promo codes) and consumed by exports.
///
/// Persisted in UserDefaults under "creditWallet.balance" — note that this is
/// a *cache* for fast UI, not the source of truth. The source of truth is the
/// StoreKit transaction history (queried at app launch and on transaction
/// updates), but we maintain a local count for instant reads.
///
/// Tampering risk: a sophisticated user could modify UserDefaults directly.
/// For V1.1 this is acceptable — the cost of preventing it (server-side
/// verification, app signing) outweighs the loss. StoreKit transaction
/// verification still happens; the local count just gets reconciled.
@MainActor
final class CreditWallet: ObservableObject {

    static let shared = CreditWallet()

    private static let storageKey = "creditWallet.balance"

    @Published private(set) var balance: Int = 0

    var hasCredit: Bool { balance > 0 }

    private init() {
        self.balance = UserDefaults.standard.integer(forKey: Self.storageKey)
    }

    /// Adds credits to the wallet — called by StoreManager when a purchase
    /// or promo code redemption succeeds.
    func grantCredits(_ count: Int) {
        guard count > 0 else { return }
        balance += count
        persist()
    }

    /// Consumes one credit — called when the user successfully exports a
    /// clean (no-watermark) film. Returns true if a credit was available
    /// and consumed; false if the wallet was empty.
    func consumeCredit() -> Bool {
        guard balance > 0 else { return false }
        balance -= 1
        persist()
        return true
    }

    /// Reconcile the local balance with StoreKit's transaction history.
    /// Called on app launch by StoreManager. Loops over all unfinished
    /// transactions and grants credits for any that haven't been counted.
    ///
    /// Note: consumables don't appear in transaction history after they're
    /// "finished" by the app, so this method primarily handles pending
    /// transactions (e.g., Ask to Buy approvals delivered while app was closed).
    func reconcileWithStoreKit(grantedCount: Int) {
        if grantedCount > 0 {
            grantCredits(grantedCount)
        }
    }

    private func persist() {
        UserDefaults.standard.set(balance, forKey: Self.storageKey)
    }

    #if DEBUG
    /// Test-only helper to set arbitrary balance.
    func _debugSetBalance(_ value: Int) {
        balance = max(0, value)
        persist()
    }
    #endif
}
