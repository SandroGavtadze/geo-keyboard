import StoreKit
import SwiftUI

/// StoreKit 2 wrapper for the one-time Pro unlock. Lives in the host app only —
/// the keyboard extension never talks to StoreKit; it reads the cached
/// `AppSettings.isProUnlocked` flag from the App Group.
@MainActor
final class ProStore: ObservableObject {

    @Published private(set) var product: Product?
    @Published private(set) var isUnlocked = AppSettings.isProUnlocked
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private var updates: Task<Void, Never>?

    init() {
        // Purchases approved outside the app (Ask to Buy, another device, refunds).
        updates = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit { updates?.cancel() }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [AppSettings.proProductID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlement()
    }

    /// Source of truth is the App Store's verified entitlements; the App Group
    /// flag is only a cache so the extension can read it.
    func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppSettings.proProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
        AppSettings.isProUnlocked = unlocked
    }
}
