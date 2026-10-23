import XCTest

/// End-to-end flows on the simulator with seeded data (DEBUG launch arguments).
/// Selectors are accessibility labels, the same text VoiceOver reads.
final class TorpidoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(seeded: Bool) {
        app.launchArguments = ["-TorpidoReset", "1"] + (seeded ? ["-TorpidoSeed", "1"] : [])
        app.launch()
    }

    private func tab(_ name: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[name]
        return inBar.exists ? inBar : app.buttons[name].firstMatch
    }

    private func element(startingWith label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// F01-N1: a link that is not a URL gets a clear message, nothing is added.
    func testAddSourceRejectsNonURL() {
        launch(seeded: false)
        app.buttons["Kaynak ekle"].firstMatch.tap()
        let field = app.descendants(matching: .any)["Liste bağlantısı"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("bu bir adres değil")
        app.buttons["Ekle"].tap()

        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Bu bir bağlantı değil")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
    }

    /// F06-H1: long-press a channel, add to favourites, find it on the Favoriler tab.
    func testFavouriteFromHomeAppearsInFavourites() {
        launch(seeded: true)
        let tile = element(startingWith: "Gündem TV")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.press(forDuration: 1.2)
        app.buttons["Favorilere ekle"].tap()

        tab("Favoriler").tap()
        XCTAssertTrue(element(startingWith: "Gündem TV").waitForExistence(timeout: 5))
    }

    /// F01-H1 (play part) and S15: open a channel, shrink the player, the mini player keeps it.
    func testPlayerShrinksToMiniPlayer() {
        launch(seeded: true)
        let tile = element(startingWith: "Haber 24")
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()

        let shrink = app.buttons["Oynatıcıyı küçült"]
        XCTAssertTrue(shrink.waitForExistence(timeout: 5))
        shrink.tap()

        let miniToggle = app.buttons.matching(NSPredicate(format: "label IN %@", ["Duraklat", "Oynat"])).firstMatch
        XCTAssertTrue(miniToggle.waitForExistence(timeout: 5), "mini player should appear after shrinking")
    }

    /// Accessibility audit on every tab: contrast, clipped text, labels, hit regions, traits.
    /// Dynamic Type is covered by the accessibility-size screenshots instead
    /// (see replica/bugs.md, "to check"). Elements scrolled under the translucent
    /// tab bar are skipped: the audit measures them through the glass.
    func testAccessibilityAuditOnEveryTab() throws {
        launch(seeded: true)
        var issues: [String] = []
        let checks: XCUIAccessibilityAuditType = [.contrast, .textClipped, .elementDetection,
                                                  .sufficientElementDescription, .hitRegion, .trait]
        for name in ["Ana Sayfa", "Favoriler", "Perde", "Ayarlar"] {
            tab(name).tap()
            let tabBarTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : .greatestFiniteMagnitude
            try app.performAccessibilityAudit(for: checks) { issue in
                // Unattributable findings (no element) cannot be located or fixed; listed in bugs.md "to check".
                guard let flagged = issue.element else { return true }
                if flagged.frame.maxY > tabBarTop { return true }
                // The system search field (.searchable) draws its own placeholder; listed in bugs.md "to check".
                if flagged.elementType == .searchField { return true }
                let element = issue.element.map { "\($0.elementType) '\($0.label)'" } ?? "?"
                issues.append("\(name): \(issue.compactDescription) on \(element)")
                return true
            }
        }
        XCTAssertTrue(issues.isEmpty, issues.joined(separator: " | "))
    }
}
