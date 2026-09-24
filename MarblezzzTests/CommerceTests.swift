import XCTest
import StoreKit
import StoreKitTest
@testable import Marblezzz

@MainActor final class CommerceTests: XCTestCase {
    private var session: SKTestSession!
    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Marblezzz")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
    }
    override func tearDown() async throws { session.clearTransactions(); session = nil }

    func testFriendsPurchaseRestoreAndRefund() async throws {
        let store = PurchaseStore()
        await store.loadProducts(); await store.refreshEntitlements()
        XCTAssertFalse(store.hasFriends)
        XCTAssertEqual(Set(store.products.map(\.id)), Set(ProductID.all))
        let transaction = try await session.buyProduct(identifier: ProductID.friends)
        try await waitForOwnership(ProductID.friends, in: store, expected: true)
        let restoredStore = PurchaseStore()
        try await waitForOwnership(ProductID.friends, in: restoredStore, expected: true)
        XCTAssertTrue(restoredStore.hasFriends, "A new store instance restores verified transactions")
        try session.refundTransaction(identifier: UInt(transaction.id))
        try await waitForOwnership(ProductID.friends, in: store, expected: false)
    }
    func testCosmeticPurchaseNeverUnlocksFriends() async throws {
        let store = PurchaseStore()
        _ = try await session.buyProduct(identifier: ProductID.walnut)
        try await waitForOwnership(ProductID.walnut, in: store, expected: true)
        XCTAssertFalse(store.hasFriends)
        XCTAssertFalse(store.owns(ProductID.coastal))
        XCTAssertTrue(store.owns(nil), "The original board is free")
    }
    func testPurchaseThroughStoreCompletesAndFinishesTransaction() async throws {
        let store = PurchaseStore()
        await store.loadProducts()
        let product = try XCTUnwrap(store.product(ProductID.coastal))
        await store.purchase(product)
        XCTAssertTrue(store.owns(ProductID.coastal))
        XCTAssertFalse(store.busy)
        XCTAssertFalse(store.hasFriends)
    }
    func testProductPricesAndSharingConfiguration() async throws {
        let products = try await Product.products(for: ProductID.all)
        let friends = try XCTUnwrap(products.first { $0.id == ProductID.friends })
        XCTAssertEqual(friends.price, Decimal(string: "4.99"))
        XCTAssertTrue(friends.isFamilyShareable)
        for product in products where product.id != ProductID.friends {
            XCTAssertEqual(product.price, Decimal(string: "1.99"))
            XCTAssertFalse(product.isFamilyShareable)
        }
    }

    func testPendingApprovalDoesNotGrantAccessUntilApproved() async throws {
        session.askToBuyEnabled = true
        let store = PurchaseStore()
        await store.loadProducts()
        let friends = try XCTUnwrap(store.product(ProductID.friends))
        await store.purchase(friends)
        XCTAssertFalse(store.hasFriends)
        XCTAssertTrue(store.message?.contains("awaiting approval") == true)
        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForOwnership(ProductID.friends, in: store, expected: true)
    }

    func testFailedOrCancelledPurchaseGrantsNothing() async throws {
        let store = PurchaseStore()
        await store.loadProducts()
        let friends = try XCTUnwrap(store.product(ProductID.friends))
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: StoreKitPurchaseAPI())
        await store.purchase(friends)
        XCTAssertFalse(store.hasFriends)
        XCTAssertFalse(store.busy)
        // Some StoreKit Test versions surface the simulated cancellation as a server error.
        // Both paths must leave access locked and release the purchase progress state.
    }

    private func waitForOwnership(_ product: String, in store: PurchaseStore, expected: Bool) async throws {
        // StoreKit propagates refunds and Ask to Buy approvals asynchronously.
        for _ in 0..<50 {
            await store.refreshEntitlements()
            if store.owned.contains(product) == expected { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("StoreKit did not deliver the expected ownership update for \(product)")
    }
}
