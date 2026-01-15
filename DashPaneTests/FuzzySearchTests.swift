import XCTest
@testable import DashPane

final class FuzzySearchTests: XCTestCase {

    var searchEngine: FuzzySearchEngine!

    override func setUp() {
        super.setUp()
        searchEngine = FuzzySearchEngine()
    }

    override func tearDown() {
        searchEngine = nil
        super.tearDown()
    }

    // MARK: - Test Windows

    private func createTestWindow(
        id: CGWindowID = 1,
        ownerName: String,
        windowTitle: String
    ) -> WindowInfo {
        return WindowInfo(
            id: id,
            ownerPID: pid_t(id),
            ownerName: ownerName,
            windowTitle: windowTitle,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            isOnScreen: true,
            spaceID: nil
        )
    }

    // MARK: - Basic Search Tests

    func testEmptyQueryReturnsAllWindows() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple"),
            createTestWindow(id: 2, ownerName: "Chrome", windowTitle: "Google")
        ]

        let results = searchEngine.search(query: "", in: windows)

        XCTAssertEqual(results.count, 2)
    }

    func testExactMatch() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple"),
            createTestWindow(id: 2, ownerName: "Chrome", windowTitle: "Google")
        ]

        let results = searchEngine.search(query: "Safari", in: windows)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.window.ownerName, "Safari")
    }

    func testCaseInsensitiveMatch() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple")
        ]

        let results = searchEngine.search(query: "safari", in: windows)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.window.ownerName, "Safari")
    }

    func testPartialMatch() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple")
        ]

        let results = searchEngine.search(query: "saf", in: windows)

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Fuzzy Match Tests

    func testNonConsecutiveMatch() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Visual Studio Code", windowTitle: "main.swift")
        ]

        let results = searchEngine.search(query: "vsc", in: windows)

        XCTAssertEqual(results.count, 1)
    }

    func testWindowTitleMatch() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "GitHub - Repository")
        ]

        let results = searchEngine.search(query: "github", in: windows)

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Acronym Tests

    func testAcronymMatch() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Google Chrome", windowTitle: "Gmail"),
            createTestWindow(id: 2, ownerName: "Calculator", windowTitle: "gctest")
        ]

        let results = searchEngine.search(query: "gc", in: windows)

        XCTAssertGreaterThan(results.count, 0)
        // Acronym match (Google Chrome) should rank higher
        XCTAssertEqual(results.first?.window.ownerName, "Google Chrome")
    }

    func testIsPotentialAcronym() {
        XCTAssertTrue(searchEngine.isPotentialAcronym("gc"))
        XCTAssertTrue(searchEngine.isPotentialAcronym("vsc"))
        XCTAssertFalse(searchEngine.isPotentialAcronym("Google Chrome"))
        XCTAssertFalse(searchEngine.isPotentialAcronym("VS Code"))
    }

    // MARK: - Scoring Tests

    func testExactMatchScoresHigher() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: ""),
            createTestWindow(id: 2, ownerName: "SafariTechnologyPreview", windowTitle: "")
        ]

        let results = searchEngine.search(query: "Safari", in: windows)

        XCTAssertEqual(results.count, 2)
        // Exact match should score higher
        XCTAssertEqual(results.first?.window.ownerName, "Safari")
    }

    func testStartOfStringScoresHigher() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple"),
            createTestWindow(id: 2, ownerName: "Apple Safari", windowTitle: "")
        ]

        let results = searchEngine.search(query: "Safari", in: windows)

        // "Safari" at start should score higher than "Apple Safari"
        XCTAssertEqual(results.first?.window.ownerName, "Safari")
    }

    // MARK: - No Match Tests

    func testNoMatchReturnsEmpty() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple")
        ]

        let results = searchEngine.search(query: "xyz", in: windows)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Multiple Windows Tests

    func testSearchMultipleWindows() {
        let windows = [
            createTestWindow(id: 1, ownerName: "Safari", windowTitle: "Apple"),
            createTestWindow(id: 2, ownerName: "Safari", windowTitle: "Google"),
            createTestWindow(id: 3, ownerName: "Chrome", windowTitle: "GitHub")
        ]

        let results = searchEngine.search(query: "Safari", in: windows)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.window.ownerName == "Safari" })
    }

    // MARK: - Performance Tests

    func testSearchPerformance() {
        // Create many windows
        let windows = (0..<1000).map { i in
            createTestWindow(
                id: CGWindowID(i),
                ownerName: "App\(i)",
                windowTitle: "Window \(i) Title"
            )
        }

        measure {
            _ = searchEngine.search(query: "app50", in: windows)
        }
    }
}
