import XCTest

// scripts/extract-screenshots.sh saves the screenshots these attach as PNGs
@MainActor
final class PopoverUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func test1_PopoverShowsFixtureMeters() {
        launch(fixture: "2.1.317-normal")
        for id in ["meter-session", "meter-weekly_all"] {
            XCTAssertTrue(element(id).waitForExistence(timeout: 10), "\(id) should be in the popover")
        }
        XCTAssertTrue(element("updatedText").exists)
        screenshot("1-popover-usage")
    }

    func test2_Refresh() {
        launch(fixture: "2.1.317-normal")
        let refresh = popover.buttons["refreshButton"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        refresh.click()
        XCTAssertTrue(element("meter-session").waitForExistence(timeout: 5))
        screenshot("2-popover-refreshed")
    }

    func test3_FooterMenu() {
        launch(fixture: "2.1.317-normal")
        XCTAssertTrue(element("meter-session").waitForExistence(timeout: 10))

        openMoreMenu()
        // The first item says which claude the last fetch used
        XCTAssertTrue(app.menuItems["fixture:2.1.317-normal.jsonl (2.1.317)"].waitForExistence(timeout: 5))
        app.menuItems["Menu bar shows"].hover()
        let session = app.menuItems["Session"]
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Weekly"].exists)
        session.click()

        openMoreMenu()
        app.menuItems["Background refresh"].hover()
        let hourly = app.menuItems["Every 60 min"]
        XCTAssertTrue(hourly.waitForExistence(timeout: 5))
        hourly.click()

        // XCUITest doesn't expose the checkmark on SwiftUI picker items, and the
        // sandboxed runner can't read the app's defaults, so the screenshot is the
        // only check that the choice stuck. UsageStoreTests cover what it does.
        openMoreMenu()
        app.menuItems["Background refresh"].hover()
        let submenu = app.menuItems["Background refresh"].menus.firstMatch
        XCTAssertTrue(submenu.waitForExistence(timeout: 5))
        screenshot("3a-background-refresh", of: submenu)
        // One Escape closes the whole menu. A second would close the popover too.
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(submenu.waitForNonExistence(timeout: 5))
        XCTAssertTrue(popover.exists)
    }

    func test4_ProblemShowsNextStep() {
        launch(fixture: "2.1.317-logged-out")
        XCTAssertTrue(element("problemView").waitForExistence(timeout: 10))
        XCTAssertTrue(popover.buttons["copyCommandButton"].exists)
        screenshot("4-problem-logged-out")
    }

    private var popover: XCUIElement {
        app.popovers.firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        popover.descendants(matching: .any)[identifier]
    }

    private func openMoreMenu() {
        let more = element("moreMenu")
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.click()
    }

    private func launch(fixture: String) {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "BenchedTests/Fixtures/\(fixture).jsonl")
            .path
        app.launchArguments = ["--show-popover", "--fixture", path]
        app.launch()
        XCTAssertTrue(popover.waitForExistence(timeout: 10), "Popover should open on launch")
    }

    // Only ever the app's own elements: a screen capture would include whatever else is open.
    // Not the popover itself either, because its frame takes in the screen around its
    // rounded corners and arrow.
    private func screenshot(_ name: String, of element: XCUIElement? = nil) {
        let attachment = XCTAttachment(screenshot: (element ?? self.element("popoverContent")).screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
