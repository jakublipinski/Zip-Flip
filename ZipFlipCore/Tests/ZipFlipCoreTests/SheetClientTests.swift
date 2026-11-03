import XCTest
@testable import ZipFlipCore

/// Answers from a script of URL → reply and records every request.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    enum Scripted {
        case reply(HTTPReply)
        case error(Error)
    }

    private let lock = NSLock()
    private var script: [String: Scripted] = [:]
    private(set) var requests: [String] = []

    func set(_ url: URL, _ scripted: Scripted) {
        lock.lock(); defer { lock.unlock() }
        script[url.absoluteString] = scripted
    }

    func html(_ url: URL, _ body: String, status: Int = 200, finalURL: URL? = nil) {
        set(url, .reply(HTTPReply(data: Data(body.utf8), status: status,
                                  headers: ["Content-Type": "text/html; charset=utf-8"], finalURL: finalURL ?? url)))
    }

    func csv(_ url: URL, _ body: String, title: String = "Zip-Flip test", tab: String, status: Int = 200) {
        let name = "\(title) - \(tab).csv"
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        set(url, .reply(HTTPReply(data: Data(body.utf8), status: status, headers: [
            "Content-Type": "text/csv; charset=utf-8",
            "Content-Disposition": "attachment; filename=\"x.csv\"; filename*=UTF-8''\(encoded)",
        ], finalURL: url)))
    }

    func get(_ url: URL) async throws -> HTTPReply {
        let scripted: Scripted? = lock.withLock {
            requests.append(url.absoluteString)
            return script[url.absoluteString]
        }
        guard let scripted else {
            return HTTPReply(data: Data("<html>404</html>".utf8), status: 404,
                             headers: ["Content-Type": "text/html"], finalURL: url)
        }
        switch scripted {
        case .reply(let reply): return reply
        case .error(let error): throw error
        }
    }

    func clearRequests() {
        lock.lock(); defer { lock.unlock() }
        requests = []
    }

    var htmlViewRequests: Int { requests.filter { $0.hasSuffix("/htmlview") }.count }
    var csvRequests: Int { requests.filter { $0.contains("format=csv") }.count }
}

final class SheetClientTests: XCTestCase {
    let id = "1gqG1A6OSHIcWcxnPhfF7ouWymoo5u67F6eJLOPTXHSI"
    var root: URL!
    var transport: FakeTransport!
    var cache: SheetCache!
    var clock = Date(timeIntervalSince1970: 1_793_600_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SheetClientTests-\(UUID().uuidString)")
        transport = FakeTransport()
        cache = SheetCache(root: root)
        try scriptTheTestSheet()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func scriptTheTestSheet() throws {
        transport.html(Links.htmlView(for: id), try Fixtures.text("htmlview.html"))
        for (gid, tab) in [("0", "Spanish"), ("1001", "Capitals"), ("1002", "Times tables"), ("1003", "Archive"), ("1004", "Empty")] {
            transport.csv(Links.csvExport(for: id, gid: gid), try Fixtures.text("tab-\(gid).csv"), tab: tab)
        }
    }

    func makeClient() -> SheetClient {
        SheetClient(transport: transport, cache: cache, now: { [clock] in clock })
    }

    // MARK: Happy path

    func testLinkOpenedFetchesTabsAndEveryVisibleTab() async throws {
        let result = try await makeClient().refresh(id, reason: .linkOpened)
        XCTAssertTrue(result.fetched)
        XCTAssertTrue(result.tabsFetched)
        XCTAssertEqual(result.spreadsheet.decks.map(\.name), ["Spanish", "Capitals", "Times tables", "Empty"])
        XCTAssertEqual(result.spreadsheet.decks.map(\.gid), ["0", "1001", "1002", "1004"])
        XCTAssertEqual(result.spreadsheet.decks.map(\.cards.count), [9, 4, 12, 0])
        XCTAssertEqual(result.cached.metadata.title, "Zip-Flip test")
        XCTAssertEqual(result.cached.metadata.tabsFetchedAt, clock)
        XCTAssertEqual(result.cached.metadata.cardsFetchedAt, clock)
        XCTAssertEqual(transport.htmlViewRequests, 1)
        XCTAssertEqual(transport.csvRequests, 4, "the hidden tab is never requested")

        let reloaded = cache.load(id)
        XCTAssertEqual(reloaded, result.cached, "the cache rebuilds the same decks")
        XCTAssertNil(cache.csv(for: id, gid: "1003"))
    }

    func testLaunchWithinThreeHoursServesTheCache() async throws {
        let client = makeClient()
        _ = try await client.refresh(id, reason: .linkOpened)
        transport.clearRequests()
        clock = clock.addingTimeInterval(2 * 3600)
        let result = try await makeClient().refresh(id, reason: .launch)
        XCTAssertFalse(result.fetched)
        XCTAssertEqual(transport.requests, [])
        XCTAssertEqual(result.spreadsheet.decks.map(\.cards.count), [9, 4, 12, 0])
    }

    func testLaunchAfterThreeHoursFetchesCardsOnly() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        transport.clearRequests()
        clock = clock.addingTimeInterval(4 * 3600)
        let result = try await makeClient().refresh(id, reason: .launch)
        XCTAssertTrue(result.fetched)
        XCTAssertFalse(result.tabsFetched)
        XCTAssertEqual(transport.htmlViewRequests, 0)
        XCTAssertEqual(transport.csvRequests, 4)
        XCTAssertEqual(result.cached.metadata.cardsFetchedAt, clock)
        XCTAssertNotEqual(result.cached.metadata.tabsFetchedAt, clock)
    }

    func testLaunchAfterADayFetchesTheTabListToo() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        transport.clearRequests()
        clock = clock.addingTimeInterval(25 * 3600)
        let result = try await makeClient().refresh(id, reason: .launch)
        XCTAssertTrue(result.tabsFetched)
        XCTAssertEqual(transport.htmlViewRequests, 1)
    }

    func testManualRefreshFetchesEverythingEvenWhenFresh() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        transport.clearRequests()
        let result = try await makeClient().refresh(id, reason: .manual)
        XCTAssertTrue(result.tabsFetched)
        XCTAssertEqual(transport.htmlViewRequests, 1)
        XCTAssertEqual(transport.csvRequests, 4)
    }

    // MARK: Tabs changing

    func testARenamedTabIsNoticedFromTheCSVAlone() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        transport.csv(Links.csvExport(for: id, gid: "1001"), try Fixtures.text("tab-1001.csv"), tab: "World capitals")
        clock = clock.addingTimeInterval(4 * 3600)
        let result = try await makeClient().refresh(id, reason: .launch)
        XCTAssertFalse(result.tabsFetched)
        XCTAssertEqual(result.spreadsheet.decks[1].name, "World capitals")
        XCTAssertEqual(cache.metadata(for: id)?.tabs[1], Tab(name: "World capitals", gid: "1001"))
    }

    func testADeletedTabTriggersOneTabListRefresh() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        // Google answers 400 for a gid that no longer exists; the new HTML view omits it.
        transport.html(Links.csvExport(for: id, gid: "1002"), "<html>bad request</html>", status: 400)
        let html = try Fixtures.text("htmlview.html")
            .replacingOccurrences(of: #"items.push({name: "Times tables", pageUrl: "#, with: #"items.pushX({name: "Times tables", pageUrl: "#)
        transport.html(Links.htmlView(for: id), html)
        transport.clearRequests()
        clock = clock.addingTimeInterval(4 * 3600)
        let result = try await makeClient().refresh(id, reason: .launch)
        XCTAssertTrue(result.tabsFetched)
        XCTAssertEqual(transport.htmlViewRequests, 1)
        XCTAssertEqual(result.spreadsheet.decks.map(\.gid), ["0", "1001", "1004"])
        XCTAssertNil(cache.csv(for: id, gid: "1002"), "the stale CSV is gone")
    }

    func testAnUnparseableHTMLViewFallsBackToTheFirstTab() async throws {
        transport.html(Links.htmlView(for: id), "<html><body>no script here</body></html>")
        let result = try await makeClient().refresh(id, reason: .linkOpened)
        XCTAssertEqual(result.spreadsheet.decks.map(\.gid), ["0"])
        XCTAssertEqual(result.spreadsheet.decks[0].name, "Spanish", "the name comes from the CSV's Content-Disposition")
        XCTAssertEqual(result.spreadsheet.decks[0].cards.count, 9)
    }

    func testTheExportRedirectToGoogleusercontentIsAccepted() async throws {
        let final = URL(string: "https://doc-04-ag-sheets.googleusercontent.com/export/abc/def/123/*/\(id)?format=csv&gid=1001")!
        transport.set(Links.csvExport(for: id, gid: "1001"), .reply(HTTPReply(
            data: Data(try Fixtures.text("tab-1001.csv").utf8), status: 200,
            headers: ["Content-Type": "text/csv; charset=utf-8",
                      "Content-Disposition": "attachment; filename=\"x.csv\"; filename*=UTF-8''Zip-Flip%20test%20-%20Capitals.csv"],
            finalURL: final)))
        let result = try await makeClient().refresh(id, reason: .linkOpened)
        XCTAssertEqual(result.spreadsheet.decks[1].cards.count, 4)
    }

    // MARK: The three failures

    func testNotSharedSheetAnswersHTMLWithASignInRedirect() async throws {
        let signIn = URL(string: "https://accounts.google.com/ServiceLogin?continue=x")!
        transport.html(Links.htmlView(for: id), "<html>Sign in</html>", finalURL: signIn)
        await assertFailure(reason: .linkOpened) { if case .notReadable = $0 { return true } else { return false } }
    }

    func testNotSharedSheetAnswersHTMLInsteadOfCSV() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        transport.html(Links.csvExport(for: id, gid: "0"), "<html>Sign in</html>")
        clock = clock.addingTimeInterval(4 * 3600)
        await assertFailure(reason: .launch) { if case .notReadable(let s) = $0 { return s == 200 } else { return false } }
        XCTAssertEqual(cache.load(id)?.spreadsheet.decks.map(\.cards.count), [9, 4, 12, 0], "the cache is untouched")
    }

    func testUnknownIdIs404() async throws {
        transport.html(Links.htmlView(for: id), "<html>Not found</html>", status: 404)
        await assertFailure(reason: .linkOpened) { if case .notReadable(let s) = $0 { return s == 404 } else { return false } }
        XCTAssertNil(cache.load(id))
    }

    func testOfflineIsItsOwnFailure() async throws {
        _ = try await makeClient().refresh(id, reason: .linkOpened)
        for gid in ["0", "1001", "1002", "1004"] {
            transport.set(Links.csvExport(for: id, gid: gid), .error(URLError(.notConnectedToInternet)))
        }
        clock = clock.addingTimeInterval(4 * 3600)
        await assertFailure(reason: .launch) { if case .offline(let c) = $0 { return c == .notConnectedToInternet } else { return false } }
        XCTAssertNotNil(cache.load(id))
    }

    func testServerErrorsAreOther() async throws {
        transport.html(Links.htmlView(for: id), "<html>oops</html>", status: 503)
        await assertFailure(reason: .linkOpened) { if case .other(let m) = $0 { return m == "HTTP 503" } else { return false } }
    }

    func assertFailure(reason: RefreshReason, _ check: (FetchFailure) -> Bool,
                       file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await makeClient().refresh(id, reason: reason)
            XCTFail("expected a failure", file: file, line: line)
        } catch let failure as FetchFailure {
            XCTAssertTrue(check(failure), "unexpected failure \(failure)", file: file, line: line)
        } catch {
            XCTFail("not a FetchFailure: \(error)", file: file, line: line)
        }
    }
}

final class SheetCacheTests: XCTestCase {
    func testMetadataRoundTripAndTolerance() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SheetCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = SheetCache(root: root)
        XCTAssertNil(cache.metadata(for: "abc"))
        let meta = SpreadsheetMetadata(id: "abc", title: "T", tabs: [Tab(name: "A", gid: "0")],
                                       tabsFetchedAt: Date(timeIntervalSince1970: 1_793_600_000), cardsFetchedAt: nil)
        try cache.save(meta)
        XCTAssertEqual(cache.metadata(for: "abc"), meta)
        try cache.save(csv: "a,b\n", for: "abc", gid: "0")
        XCTAssertEqual(cache.load("abc")?.spreadsheet.decks.first?.cards.count, 1)
        try Data("{broken".utf8).write(to: cache.layout.metadataFile(spreadsheet: "abc"))
        XCTAssertNil(cache.metadata(for: "abc"))
        XCTAssertNil(cache.load("abc"))
    }
}
