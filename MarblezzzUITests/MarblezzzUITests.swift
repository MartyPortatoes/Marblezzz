import XCTest
import StoreKitTest

@MainActor final class MarblezzzUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    }
    func testSoloPlayableAndResumable() throws {
        app.launch()
        waitForHome()
        attach("Home")
        startFreshSolo()
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 10))
        playOneTurn()
        attach("Solo board")
        app.buttons["Save and leave table"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["resume-solo"].waitForExistence(timeout: 10))
        app.buttons["resume-solo"].tap()
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 10))
    }
    func testFriendsModeIsGated() {
        app.launch()
        app.buttons["pass-and-play"].tap()
        XCTAssertTrue(app.staticTexts["Friends for good"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["start-table"].exists)
        attach("Friends storefront")
    }
    func testPassAndPlayHidesHandUntilReveal() {
        app.launchArguments += ["--friends-unlocked"]
        app.launch()
        waitForHome()
        if app.buttons["new-pass-and-play"].exists {
            tapVisible(app.buttons["new-pass-and-play"])
            app.buttons["Replace saved game"].tap()
        } else {
            tapVisible(app.buttons["pass-and-play"])
        }
        attach("Table setup contrast")
        let start = app.buttons["start-table"]
        if !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 5)); start.tap()
        XCTAssertTrue(app.buttons["reveal-hand"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-' ")).count, 0)
        app.buttons["reveal-hand"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["reveal-hand"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-' ")).count, 0)
        attach("Private handoff")
        app.buttons["reveal-hand"].tap()
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 5))
        playOneTurn()
        XCTAssertTrue(app.buttons["reveal-hand"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-' ")).count, 0)
    }
    func testTutorialHasAllTenLessons() {
        traverseTutorial()
    }
    func testTutorialAtLargestTextSize() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        traverseTutorial()
    }
    private func traverseTutorial() {
        app.launch()
        let learn = app.buttons["learn-to-play"]
        tapVisible(learn)
        XCTAssertTrue(app.staticTexts["Two teams. One way home."].waitForExistence(timeout: 5))
        for _ in 0..<9 { app.buttons["tutorial-next"].tap() }
        XCTAssertTrue(app.staticTexts["All home? You're not done yet."].exists)
        attach(app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXXXL") ? "Tutorial largest text" : "Tutorial")
        app.buttons["tutorial-next"].tap()
        waitForHome()
    }
    func testLandscapeAndLargeTextBoard() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        startFreshSolo()
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
            guard let self else { return false }
            return self.app.frame.width > self.app.frame.height
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
        XCTAssertTrue(app.buttons["Table options"].waitForExistence(timeout: 10))
        attach("Landscape large text")
        playOneTurn()
        attach("Large text completed turn")
        XCUIDevice.shared.orientation = .portrait
    }
    func testLandscapeAtDefaultTextSize() {
        app.launch()
        startFreshSolo()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Table options"].waitForExistence(timeout: 10))
        let visibleHand = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
            guard let self else { return false }
            let card = self.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-' ")).firstMatch
            return self.app.frame.width > self.app.frame.height && card.isHittable
                && self.app.staticTexts["turn-title"].isHittable
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [visibleHand], timeout: 10), .completed)
        attach("Landscape board")
        XCUIDevice.shared.orientation = .portrait
    }
    func testNewGameCancellationPreservesSavedSolo() {
        app.launch()
        startFreshSolo()
        playOneTurn()
        let nextTurn = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
            self?.app.staticTexts["turn-title"].label == "Your move."
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [nextTurn], timeout: 15), .completed)
        let before = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'")).allElementsBoundByIndex.map(\.identifier).sorted()
        app.buttons["Save and leave table"].tap()
        tapVisible(app.buttons["new-solo"])
        XCTAssertTrue(app.buttons["Keep saved game"].waitForExistence(timeout: 5))
        attach("Replace saved game confirmation")
        app.buttons["Keep saved game"].tap()
        tapVisible(app.buttons["resume-solo"])
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 10))
        let after = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'")).allElementsBoundByIndex.map(\.identifier).sorted()
        XCTAssertEqual(before, after)
    }

    func testPendingPurchaseShowsVisibleResult() throws {
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Marblezzz", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.askToBuyEnabled = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        app.launch()
        waitForHome()
        app.buttons["Table shop"].tap()
        let buy = app.buttons["buy-com.marblezzz.friends"]
        XCTAssertTrue(buy.waitForExistence(timeout: 10))
        tapVisible(buy)
        let alert = app.alerts["Store update"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["Your purchase is awaiting approval. We'll unlock it when Apple confirms it."].exists)
        attach("Visible pending purchase result")
        alert.buttons["OK"].tap()
        XCTAssertFalse(alert.exists)
        XCTAssertTrue(buy.isEnabled)
    }

    private func waitForHome() {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
            guard let self else { return false }
            return self.app.buttons["play-solo"].exists || self.app.buttons["resume-solo"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    private func startFreshSolo() {
        waitForHome()
        // Resume is the primary action when progress exists. Starting over is explicit.
        if app.buttons["new-solo"].exists {
            tapVisible(app.buttons["new-solo"])
            XCTAssertTrue(app.buttons["Replace saved game"].waitForExistence(timeout: 5))
            app.buttons["Replace saved game"].tap()
        } else {
            tapVisible(app.buttons["play-solo"])
        }
        XCTAssertTrue(app.staticTexts["turn-title"].waitForExistence(timeout: 10))
    }

    private func tapVisible(_ element: XCUIElement) {
        for _ in 0..<24 {
            if element.isHittable { element.tap(); return }
            let table = app.scrollViews["table-scroll"]
            let scroll = table.exists ? table : app.scrollViews.firstMatch
            let viewport = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
            let upwards = !element.exists || element.frame.midY >= viewport.midY
            // Short drags inside the content avoid the board and do not jump over
            // a scaled card in a short landscape viewport.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = viewport.minX + viewport.width * 0.85
            let top = viewport.minY + viewport.height * 0.30
            let bottom = viewport.minY + viewport.height * 0.75
            origin.withOffset(CGVector(dx: x, dy: upwards ? bottom : top))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: upwards ? top : bottom)))
        }
        attach("Unreachable \(element.identifier)")
        XCTFail("Control is not reachable: \(element.identifier), frame: \(element.frame). \(app.debugDescription)")
    }

    private func playOneTurn() {
        app.swipeUp()
        let forfeit = app.buttons["forfeit-hand"]
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'"))
        let ready = NSPredicate { [weak self] _, _ in
            guard let self else { return false }
            return forfeit.exists || (cards.count > 0 && self.app.staticTexts["turn-title"].label == "Your move.")
        }
        let readyExpectation = XCTNSPredicateExpectation(predicate: ready, object: app)
        let result = XCTWaiter.wait(for: [readyExpectation], timeout: 20)
        if result != .completed {
            attach("Unavailable turn")
            XCTFail("No human turn became available: \(app.debugDescription)")
            return
        }
        if forfeit.exists {
            if !forfeit.isHittable { app.swipeUp() }
            forfeit.tap(); return
        }
        for identifier in cards.allElementsBoundByIndex.map(\.identifier) {
            let card = app.buttons[identifier]
            tapVisible(card)
            let disclosure = app.buttons["legal-moves"]
            if disclosure.exists {
                tapVisible(disclosure)
                app.swipeUp()
            }
            let move = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'move-' ")).firstMatch
            if move.waitForExistence(timeout: 1) {
                tapVisible(move)
                let confirm = app.buttons["confirm-move"]
                XCTAssertTrue(confirm.isEnabled); tapVisible(confirm); return
            }
        }
        attach("Missing legal moves")
        XCTFail("No accessible legal move was available: \(app.debugDescription)")
    }
    private func attach(_ name: String) {
        // XCTest can report an element present during a device rotation or marble animation.
        // Let those finite presentation animations settle before recording visual evidence.
        Thread.sleep(forTimeInterval: 2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
