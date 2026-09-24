import Foundation
import StoreKit
import Combine

enum ProductID {
    static let friends = "com.marblezzz.friends"
    static let walnut = "com.marblezzz.walnut"
    static let coastal = "com.marblezzz.coastal"
    static let all = [friends, walnut, coastal]
}

@MainActor final class PurchaseStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var owned: Set<String> = []
    @Published private(set) var busy = false
    @Published var message: String?
    private var listener: Task<Void, Never>?
    private let testEntitlements: Bool
    private var entitlementRefresh = 0

    init() {
        #if DEBUG
        testEntitlements = ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--friends-unlocked")
        #else
        testEntitlements = false
        #endif
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
        Task { await refreshEntitlements(); await loadProducts() }
    }
    deinit { listener?.cancel() }
    var hasFriends: Bool { testEntitlements || owned.contains(ProductID.friends) }
    func owns(_ id: String?) -> Bool { id == nil || owned.contains(id!) }
    func product(_ id: String) -> Product? { products.first { $0.id == id } }
    func loadProducts() async {
        do { products = try await Product.products(for: ProductID.all).sorted { $0.price < $1.price } }
        catch { message = "The store is unavailable. Your existing purchases still work. \(error.localizedDescription)" }
    }
    func refreshEntitlements() async {
        entitlementRefresh += 1
        let refresh = entitlementRefresh
        var verified = Set<String>()
        // StoreKit supplies its verified, on-device transaction cache while offline.
        // Never grant paid features from an unsigned UserDefaults flag.
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                verified.insert(transaction.productID)
            }
        }
        if refresh == entitlementRefresh { owned = verified }
    }
    func purchase(_ product: Product) async {
        guard !busy else { return }
        message = nil
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "This purchase could not be verified. No access was granted."; return
                }
                await refreshEntitlements(); await transaction.finish()
                message = "Your purchase is ready. Enjoy the table!"
            case .pending: message = "Your purchase is awaiting approval. We'll unlock it when Apple confirms it."
            case .userCancelled: break
            @unknown default: message = "The purchase is not complete. Please try again."
            }
        } catch StoreKitError.userCancelled { /* Cancellation leaves the table unchanged. */ }
        catch { message = error.localizedDescription }
    }
    func restore() async {
        guard !busy else { return }
        message = nil
        busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refreshEntitlements(); message = "Your available purchases have been restored." }
        catch { message = error.localizedDescription }
    }
}
