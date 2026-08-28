import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    func testCaptureKeyScreens() {
        if app.buttons["Skip and use default targets"].firstMatch.waitForExistence(timeout: 6) {
            ShotIO.save("09-onboarding")
            app.buttons["Skip and use default targets"].firstMatch.tap()
        }
        _ = app.buttons["Catalog"].firstMatch.waitForExistence(timeout: 12)
        pause(2.2)
        ShotIO.save("01-today")

        tap("Catalog")
        pause(0.4)
        typeQuery("Protein")
        _ = app.staticTexts["Calibrated Protein Bar"].waitForExistence(timeout: 6)
        ShotIO.save("02-search")

        tapContaining("Protein")
        pause(0.7)
        ShotIO.save("03-detail")
        tap("Assign weigh-in")
        pause(0.5)
        ShotIO.save("04-assign")
        goHub()
        pause(0.5)
        ShotIO.save("01-today")

        tap("Log")
        pause(0.5)
        ShotIO.save("05-daylog")
        goHub()

        tap("Plan")
        pause(0.5)
        ShotIO.save("06-plan")
        goHub()

        tap("Reserved")
        pause(0.5)
        ShotIO.save("07-wish")
        goHub()

        tap("Targets")
        pause(0.5)
        ShotIO.save("08-goals")
        goHub()

        tap("Weigh")
        pause(0.6)
        ShotIO.save("10-scan")
    }

    func goHub() {
        if tap("Discard", timeout: 0.8) { return }
        tap("Back to hub")
        tap("Discard")
        pause(0.3)
    }

    @discardableResult
    func tap(_ label: String, timeout: TimeInterval = 3) -> Bool {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        return false
    }

    func tapContaining(_ token: String) {
        let hit = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", token))
            .firstMatch
        if hit.waitForExistence(timeout: 5) { hit.tap() }
    }

    func typeQuery(_ text: String) {
        let named = app.textFields["Search the catalog"].firstMatch
        let field = named.waitForExistence(timeout: 3) ? named : app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText(text)
            pause(0.8)
        }
    }

    func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}

enum ShotIO {
    @MainActor
    static func save(_ name: String) {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        let idiom = device.localizedCaseInsensitiveContains("iPad") ? "ipad" : "iphone"
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("screenshots", isDirectory: true)
            .appendingPathComponent(idiom, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
