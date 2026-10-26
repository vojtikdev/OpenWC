import XCTest

final class OpenWCUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        let demo = app.buttons["Explore a demo"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        demo.tap()
        XCTAssertTrue(app.buttons["tab-4"].waitForExistence(timeout: 10))
    }
    func testSettingsActionsStayAboveNavigation() {
        app.buttons["tab-4"].tap()
        let requests = app.buttons["Privacy & account requests"]
        for _ in 0..<6 {
            if requests.exists && requests.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(requests.exists)
        XCTAssertTrue(requests.isHittable)
        XCTAssertLessThanOrEqual(requests.frame.maxY, app.buttons["tab-4"].frame.minY)
        attach("Settings and footer")
        requests.tap()
        XCTAssertTrue(app.staticTexts["Privacy & account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab-4"].isHittable)
    }
    func testNearbySearchIsAboveFooter() {
        app.buttons["tab-1"].tap()
        let search = app.textFields["nearbySearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable)
        XCTAssertLessThan(search.frame.maxY, app.buttons["tab-1"].frame.minY)
        search.tap()
        search.typeText("McDonald")
        XCTAssertTrue(app.staticTexts["McDonald’s"].waitForExistence(timeout: 5))
        attach("Nearby search with keyboard")
    }
    func testManualPinIsAvailableWithoutBusinessSearch() {
        app.buttons["sharePlaceButton"].tap()
        let choose = app.buttons["Choose a spot on the map"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()
        let exact = app.buttons["Keep exact pin instead"]
        XCTAssertTrue(exact.waitForExistence(timeout: 10))
        XCTAssertTrue(exact.isHittable)
        attach("Nearest business pin picker")
        exact.tap()
        XCTAssertTrue(app.staticTexts["Location pinned"].waitForExistence(timeout: 5))
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
