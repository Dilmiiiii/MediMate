import XCTest

final class MediMateUITests: XCTestCase {
    func testMainNavigationLoads() {
        let app = XCUIApplication()
        app.launch()
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 4) { skip.tap() }
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 12))
        app.tabBars.buttons["Medicines"].tap()
        XCTAssertTrue(app.navigationBars["My Medications"].waitForExistence(timeout: 4))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["Medication History"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.navigationBars["Health Insights"].waitForExistence(timeout: 4))
    }
}
