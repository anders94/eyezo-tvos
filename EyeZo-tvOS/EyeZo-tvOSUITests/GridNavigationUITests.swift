import XCTest

/// Exercises the browser grid with the simulated Siri Remote.
///
/// These tests need a live EyeZo server whose root contains a "Movies"
/// directory holding "1408 (2007).mp4" plus enough videos to scroll.
///
/// The server address is never checked in. Provide it one of two ways:
///
/// 1. `EYEZO_SERVER_URL` in the test runner's environment, e.g. in Xcode under
///    Edit Scheme > Test > Arguments > Environment Variables.
/// 2. A git-ignored `TestServer.plist` next to this file containing a single
///    `serverURL` string key. The test target is a file-system synchronized
///    group, so the file is bundled automatically.
///
/// Without either, the tests are skipped.
final class GridNavigationUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static var configuredServerURL: String? {
        if let url = ProcessInfo.processInfo.environment["EYEZO_SERVER_URL"], !url.isEmpty {
            return url
        }
        guard let plist = Bundle(for: GridNavigationUITests.self).url(forResource: "TestServer", withExtension: "plist"),
              let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let url = dict["serverURL"] as? String, !url.isEmpty else {
            return nil
        }
        return url
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let serverURL = Self.configuredServerURL else {
            throw XCTSkip("No test server configured; see the header of GridNavigationUITests.swift")
        }
        app = XCUIApplication()
        // UserDefaults argument domain: seeds the stored server URL for this launch.
        app.launchArguments += ["-serverURL", serverURL]
        app.launch()
    }

    // MARK: - Helpers

    private var focusedElement: XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "hasFocus == true"))
            .firstMatch
    }

    private func focusedLabel(_ timeout: TimeInterval = 5) -> String {
        let element = focusedElement
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Nothing has focus")
        return element.label
    }

    private func saveScreenshot(_ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["EYEZO_SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            do {
                try shot.pngRepresentation.write(to: url)
            } catch {
                NSLog("EYEZO screenshot write failed: \(error)")
            }
        } else {
            NSLog("EYEZO no EYEZO_SCREENSHOT_DIR in environment")
        }
    }

    /// Moves focus onto the "Movies" directory card and opens it.
    private func openMovies() {
        let movies = app.buttons["Movies"]
        XCTAssertTrue(movies.waitForExistence(timeout: 15), "Root listing did not load")

        // Enter the grid if focus is still in the toolbar, then walk to Movies.
        var trail = [focusedLabel()]
        if trail[0] == "gearshape" || trail[0] == "Settings" {
            remote.press(.down)
            usleep(300_000)
            trail.append(focusedLabel())
        }
        var steps = 0
        while !focusedLabel().hasPrefix("Movies") && steps < 12 {
            let focusedX = focusedElement.frame.midX
            remote.press(focusedX < movies.frame.midX ? .right : .left)
            usleep(300_000)
            trail.append(focusedLabel())
            steps += 1
        }
        XCTAssertTrue(focusedLabel().hasPrefix("Movies"), "Could not focus Movies card, focus trail: \(trail)")
        remote.press(.select)
        let firstVideo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1408'")).firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 20), "Movies listing did not load")
        // Let focus settle after the push.
        sleep(1)
    }

    // MARK: - Tests

    @MainActor
    func testInitialFocusLandsOnFirstCard() throws {
        XCTAssertTrue(app.buttons["Documentary"].waitForExistence(timeout: 15))
        sleep(1)
        saveScreenshot("root")
        XCTAssertTrue(app.buttons["Documentary"].hasFocus, "First card should have focus after load, focused: \(focusedLabel())")
    }

    @MainActor
    func testAllCardsShareOneWidthAndAlignToColumns() throws {
        openMovies()
        saveScreenshot("movies")

        // Grid cards only: skip the header's settings control, and skip the
        // focused card because the card button style scales it.
        let cards = app.buttons.allElementsBoundByIndex.filter {
            $0.label != "Settings" && !$0.hasFocus && $0.frame.minY > 0
        }
        XCTAssertGreaterThan(cards.count, 4)

        let widths = Set(cards.map { Int($0.frame.width.rounded()) })
        XCTAssertEqual(widths.count, 1, "Cards have differing widths: \(widths)")

        let columns = Set(cards.map { Int($0.frame.minX.rounded()) })
        XCTAssertLessThanOrEqual(columns.count, 4, "Cards are not aligned to columns: \(columns.sorted())")

        // No two cards overlap horizontally within a row.
        let byRow = Dictionary(grouping: cards) { Int($0.frame.minY.rounded()) }
        for (_, row) in byRow {
            let sorted = row.sorted { $0.frame.minX < $1.frame.minX }
            for (a, b) in zip(sorted, sorted.dropFirst()) {
                XCTAssertLessThanOrEqual(a.frame.maxX, b.frame.minX + 1, "\(a.label) overlaps \(b.label)")
            }
        }

        // Menu pops back to the root listing.
        remote.press(.menu)
        XCTAssertTrue(app.buttons["Documentary"].waitForExistence(timeout: 10), "Menu did not navigate back to the root")
    }

    @MainActor
    func testRapidDownPressesStayInColumn() throws {
        openMovies()
        // Start one column in, on a video row, so there is room to move.
        remote.press(.down)
        remote.press(.right)
        sleep(1)
        let startLabel = focusedLabel()
        let startX = focusedElement.frame.midX

        for round in 1...3 {
            for _ in 1...5 { remote.press(.down) }
            sleep(1)
            let x = focusedElement.frame.midX
            saveScreenshot("rapid-down-\(round)")
            XCTAssertEqual(x, startX, accuracy: 10,
                           "Round \(round): rapid down presses drifted from \(startLabel) column to \(focusedLabel())")
            for _ in 1...5 { remote.press(.up) }
            sleep(1)
            XCTAssertEqual(focusedElement.frame.midX, startX, accuracy: 10,
                           "Round \(round): rapid up presses drifted to \(focusedLabel())")
        }
        XCTAssertEqual(focusedLabel(), startLabel)
    }

    @MainActor
    func testSlowDownPressesStayInColumn() throws {
        openMovies()
        remote.press(.down)
        remote.press(.right)
        sleep(1)
        let startX = focusedElement.frame.midX

        for _ in 1...5 {
            remote.press(.down)
            usleep(600_000)
        }
        sleep(1)
        saveScreenshot("slow-down")
        XCTAssertEqual(focusedElement.frame.midX, startX, accuracy: 10,
                       "Slow down presses drifted to \(focusedLabel())")
    }
}
