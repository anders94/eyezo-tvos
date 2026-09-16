import XCTest

/// Exercises the server address flow with the simulated Siri Remote and the
/// simulator's hardware keyboard.
///
/// Needs a live EyeZo server, configured the same way as GridNavigationUITests
/// (EYEZO_SERVER_URL in the environment, or the git-ignored TestServer.plist).
/// Skipped when neither is present.
final class ServerSetupUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private var serverURL = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let url = GridNavigationUITests.configuredServerURL else {
            throw XCTSkip("No test server configured; see the header of GridNavigationUITests.swift")
        }
        serverURL = url
        app = XCUIApplication()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var rootLoaded: XCUIElement {
        app.buttons["Movies"]
    }

    @MainActor
    func testFirstRunAsksForAddressAndOpensBrowserOnDone() throws {
        // An empty stored address means no server is known.
        app.launchArguments += ["-serverURL", ""]
        app.launch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Setup screen did not show a text field")
        sleep(1)
        attach("first-run")
        XCTAssertTrue(field.hasFocus, "Address field should have focus on first run")

        remote.press(.select)
        sleep(1)
        app.typeText(serverURL + "\n")

        XCTAssertTrue(rootLoaded.waitForExistence(timeout: 20), "Browser did not open after entering the address")
        attach("after-done")
    }

    @MainActor
    func testServerButtonShowsCurrentAddressAndMenuCancels() throws {
        app.launchArguments += ["-serverURL", serverURL]
        app.launch()
        XCTAssertTrue(rootLoaded.waitForExistence(timeout: 20))

        let server = app.buttons["Server"]
        XCTAssertTrue(server.exists)
        // Move focus from the grid to the header button and open it.
        var trail: [String] = []
        var steps = 0
        while !server.hasFocus && steps < 4 {
            remote.press(.up)
            usleep(400_000)
            trail.append(app.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch.label)
            steps += 1
        }
        XCTAssertTrue(server.hasFocus, "Could not focus the Server button; focus trail: \(trail)")
        remote.press(.select)

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Server screen did not appear")
        sleep(1)
        attach("server-cover")
        XCTAssertEqual(field.value as? String, serverURL, "Field should show the current address")

        remote.press(.menu)
        XCTAssertTrue(rootLoaded.waitForExistence(timeout: 10), "Menu did not return to the browser")
        sleep(1)
        XCTAssertFalse(field.exists, "Server screen should be dismissed")
        XCTAssertTrue(server.hasFocus, "Focus should return to the Server button")
    }

    @MainActor
    func testUnreachableServerShowsErrorWithRetryAndServerButton() throws {
        app.launchArguments += ["-serverURL", "http://127.0.0.1:1"]
        app.launch()

        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 20), "Error state did not appear for an unreachable server")
        sleep(1)
        attach("unreachable")
        XCTAssertTrue(app.buttons["Server"].exists, "Server button should stay reachable in the error state")
    }
}
