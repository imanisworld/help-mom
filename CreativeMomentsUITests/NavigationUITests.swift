import XCTest

/// End-to-end navigation smoke tests for the four large home actions.
/// Use accessibility IDs for stable entry points; screen titles remain user-facing.
final class CreativeMomentsNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeSectionsOpenAndReturn() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))

        let destinations = [
            ("home.planner", "My Planner"),
            ("home.draw", "Color & Draw"),
            ("home.journal", "My Journal"),
            ("home.creations", "My Creations")
        ]
        for (identifier, title) in destinations {
            let entry = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "Home action missing: \(title)")
            entry.tap()

            let navigation = app.navigationBars[title]
            XCTAssertTrue(navigation.waitForExistence(timeout: 10), "Destination did not open: \(title)")
            let back = navigation.buttons.firstMatch
            XCTAssertTrue(back.exists, "No way back from \(title)")
            back.tap()
            XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        }
    }

    func testDrawingEditorCanBeOpenedAndClosed() {
        let app = XCUIApplication()
        app.launch()

        let draw = app.descendants(matching: .any).matching(identifier: "home.draw").firstMatch
        XCTAssertTrue(draw.waitForExistence(timeout: 10))
        draw.tap()
        XCTAssertTrue(app.navigationBars["Color & Draw"].waitForExistence(timeout: 10))

        let sketch = app.buttons["Sketch an idea"]
        XCTAssertTrue(sketch.waitForExistence(timeout: 10))
        sketch.tap()
        XCTAssertTrue(app.navigationBars["Sketch an idea"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Color & Draw"].waitForExistence(timeout: 10))
    }
}
