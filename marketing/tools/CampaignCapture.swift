// Copy temporarily to MarblezzzUITests/MarketingCaptureTests.swift and regenerate
// the project. Seed validated snapshots with CampaignFixture before running.
import XCTest
import StoreKitTest

@MainActor final class MarketingCaptureTests: XCTestCase {
    private var app: XCUIApplication!
    func testCampaignScreens() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Marblezzz", withExtension: "storekit"))
        let store = try SKTestSession(contentsOf: configuration)
        store.resetToDefaultState(); store.clearTransactions(); store.disableDialogs = true
        _ = try await store.buyProduct(identifier: "com.marblezzz.friends")
        _ = try await store.buyProduct(identifier: "com.marblezzz.walnut")
        defer { store.clearTransactions(); store.resetToDefaultState() }
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["resume-solo"].waitForExistence(timeout: 15))
        try await capture("03-solo")
        tapVisible(app.buttons["learn-to-play"])
        XCTAssertTrue(app.staticTexts["Two teams. One way home."].waitForExistence(timeout: 5))
        try await capture("05-tutorial")
        app.buttons["Done"].tap()
        tapVisible(app.buttons["resume-solo"])
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 10))
        try await capture("01-gameplay")
        tapVisible(app.buttons["card-34"])
        tapVisible(app.buttons["legal-moves"])
        tapVisible(app.buttons["move-34:move(0, 9)"])
        tapVisible(app.buttons["legal-moves"])
        XCTAssertTrue(app.buttons["confirm-move"].isEnabled)
        reveal(app.buttons["confirm-move"])
        try await capture("02-preview")
        app.buttons["Save and leave table"].tap()
        tapVisible(app.buttons["pass-and-play"])
        XCTAssertTrue(app.buttons["reveal-hand"].waitForExistence(timeout: 10))
        try await capture("04-handoff")
        app.buttons["Save and leave table"].tap()
        app.buttons["Table shop"].tap()
        XCTAssertTrue(app.staticTexts["Friends unlocked"].waitForExistence(timeout: 10))
        tapVisible(app.buttons["Use finish"].firstMatch)
        XCTAssertTrue(app.staticTexts["Midnight walnut"].exists)
        try await capture("07-shop")
        app.buttons["Done"].tap()
        tapVisible(app.buttons["resume-solo"])
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 10))
        try await capture("06-finish")
    }
    private func capture(_ name: String) async throws {
        try await Task.sleep(for: .milliseconds(650))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func tapVisible(_ element: XCUIElement) { reveal(element); element.tap() }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<24 {
            if element.isHittable { return }
            let table = app.scrollViews["table-scroll"]
            let scroll = table.exists ? table : app.scrollViews.firstMatch
            let viewport = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
            let upwards = !element.exists || element.frame.midY >= viewport.midY
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // iPad's storefront is a centered sheet; a drag near the app edge
            // hits the dimmed home view. Keep sheet gestures within its center.
            let inShop = app.staticTexts["The table shop"].exists
            let x = inShop ? app.frame.midX : viewport.minX + viewport.width * 0.85
            let top = inShop ? app.frame.height * 0.45 : viewport.minY + viewport.height * 0.30
            let bottom = inShop ? app.frame.height * 0.67 : viewport.minY + viewport.height * 0.75
            origin.withOffset(CGVector(dx: x, dy: upwards ? bottom : top))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: upwards ? top : bottom)))
        }
        XCTFail("Control not reachable: \(element.identifier). \(app.debugDescription)")
    }
}
