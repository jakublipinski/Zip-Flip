import Foundation

/// Why a fetch failed, in the three ways the watch tells apart (README
/// decision 6 and the "sheet not readable" screen).
public enum FetchFailure: Error, CustomStringConvertible, Sendable {
    /// Google would not hand the sheet over: it is not shared as "Anyone with
    /// the link", or the id is wrong. Carries the HTTP status when there was one.
    case notReadable(status: Int?)
    /// No network, or none that reaches Google.
    case offline(URLError.Code)
    /// Anything else: a Google outage, an unexpected answer, a bug.
    case other(String)

    public var description: String {
        switch self {
        case .notReadable(let status): return "sheet not readable" + (status.map { " (HTTP \($0))" } ?? "")
        case .offline(let code): return "offline (\(code.rawValue))"
        case .other(let message): return "error: \(message)"
        }
    }
}

/// What triggered a refresh; it decides how much is re-fetched.
public enum RefreshReason: Sendable {
    /// A Zip Flip link was opened: everything is fetched.
    case linkOpened
    /// The Refresh button: everything is fetched.
    case manual
    /// The app came to the front: only what is stale (`RefreshPolicy`).
    case launch
}

/// README decision 6: cards refresh every few hours, the tab list rarely.
public enum RefreshPolicy {
    public static let cardsMaxAge: TimeInterval = 3 * 3600
    public static let tabsMaxAge: TimeInterval = 24 * 3600
}

public struct RefreshResult: Equatable, Sendable {
    public let cached: CachedSpreadsheet
    /// False when the cache was fresh enough and nothing was fetched.
    public let fetched: Bool
    public let tabsFetched: Bool

    public var spreadsheet: Spreadsheet { cached.spreadsheet }
}

/// Downloads a spreadsheet: the HTML view for the tab list, then one CSV per
/// tab, and keeps the result in the cache (README decisions 2, 5, 6).
public final class SheetClient {
    public let transport: HTTPTransport
    public let cache: SheetCache
    private let now: @Sendable () -> Date

    public init(transport: HTTPTransport, cache: SheetCache, now: @escaping @Sendable () -> Date = { Date() }) {
        self.transport = transport
        self.cache = cache
        self.now = now
    }

    public func cached(_ id: String) -> CachedSpreadsheet? {
        cache.load(id)
    }

    /// Refreshes according to `reason` and the cache's age. Throws a
    /// `FetchFailure`; the cache is left as it was when nothing new arrived.
    public func refresh(_ id: String, reason: RefreshReason) async throws -> RefreshResult {
        let start = now()
        let existing = cache.metadata(for: id)

        if reason == .launch, let meta = existing, let at = meta.cardsFetchedAt,
           start.timeIntervalSince(at) < RefreshPolicy.cardsMaxAge, let cached = cache.load(id) {
            return RefreshResult(cached: cached, fetched: false, tabsFetched: false)
        }

        let tabsStale = existing?.tabsFetchedAt.map { start.timeIntervalSince($0) >= RefreshPolicy.tabsMaxAge } ?? true
        var tabs: [Tab]
        var tabsFetched = false
        if reason != .launch || tabsStale || existing?.tabs.isEmpty != false {
            tabs = try await fetchTabs(id)
            tabsFetched = true
        } else {
            tabs = existing!.tabs
        }

        var downloads: [TabDownload]
        do {
            downloads = try await fetchAll(id, tabs: tabs)
        } catch FetchFailure.notReadable(let status) where status == 400 && !tabsFetched {
            // A tab was deleted since the list was cached: list again, once.
            tabs = try await fetchTabs(id)
            tabsFetched = true
            downloads = try await fetchAll(id, tabs: tabs)
        }

        var meta = existing ?? SpreadsheetMetadata(id: id)
        meta.tabs = downloads.map(\.tab)
        meta.title = downloads.compactMap(\.title).first ?? meta.title
        meta.cardsFetchedAt = start
        if tabsFetched { meta.tabsFetchedAt = start }
        for d in downloads {
            try cache.save(csv: d.csv, for: id, gid: d.tab.gid)
        }
        cache.removeCSVs(for: id, notIn: Set(tabs.map(\.gid)))
        try cache.save(meta)

        let decks = downloads.map { DeckBuilder.deck(name: $0.tab.name, gid: $0.tab.gid, csv: $0.csv) }
        let cached = CachedSpreadsheet(metadata: meta, spreadsheet: Spreadsheet(id: id, decks: decks))
        return RefreshResult(cached: cached, fetched: true, tabsFetched: tabsFetched)
    }

    // MARK: - Pieces

    struct TabDownload: Sendable {
        var tab: Tab
        var csv: String
        var title: String?
    }

    func fetchTabs(_ id: String) async throws -> [Tab] {
        let reply = try await get(Links.htmlView(for: id))
        guard reply.status == 200, !isSignIn(reply.finalURL),
              reply.contentType?.lowercased().hasPrefix("text/html") == true else {
            throw FetchFailure.notReadable(status: reply.status)
        }
        return TabListParser.tabsOrFallback(fromHTML: reply.text)
    }

    func fetchAll(_ id: String, tabs: [Tab]) async throws -> [TabDownload] {
        try await withThrowingTaskGroup(of: (Int, TabDownload).self) { group in
            for (index, tab) in tabs.enumerated() {
                group.addTask { (index, try await self.fetchTab(id, tab: tab)) }
            }
            var results: [(Int, TabDownload)] = []
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    func fetchTab(_ id: String, tab: Tab) async throws -> TabDownload {
        // The export answers 307 to a googleusercontent.com host; URLSession
        // follows it, so only the final answer is checked.
        let reply = try await get(Links.csvExport(for: id, gid: tab.gid))
        guard reply.status == 200, !isSignIn(reply.finalURL),
              reply.contentType?.lowercased().hasPrefix("text/csv") == true else {
            // 400 is Google's answer for a gid that no longer exists; a sign-in
            // page is HTML with status 200 after the redirect.
            throw FetchFailure.notReadable(status: reply.status)
        }
        let disposition = reply.contentDisposition
        let name = disposition.flatMap(Links.tabName(fromContentDisposition:)) ?? tab.name
        let title = disposition.flatMap(Links.spreadsheetTitle(fromContentDisposition:))
        return TabDownload(tab: Tab(name: name, gid: tab.gid), csv: reply.text, title: title)
    }

    private func get(_ url: URL) async throws -> HTTPReply {
        let reply: HTTPReply
        do {
            reply = try await transport.get(url)
        } catch let error as URLError {
            throw SheetClient.offlineCodes.contains(error.code)
                ? FetchFailure.offline(error.code)
                : FetchFailure.other(error.localizedDescription)
        } catch let failure as FetchFailure {
            throw failure
        } catch {
            throw FetchFailure.other(String(describing: error))
        }
        switch reply.status {
        case 200...299, 400, 401, 403, 404:
            return reply
        default:
            throw FetchFailure.other("HTTP \(reply.status)")
        }
    }

    /// A redirect to accounts.google.com means the sheet needs a sign-in.
    private func isSignIn(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.hasPrefix("accounts.google.")
    }

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dnsLookupFailed, .timedOut, .internationalRoamingOff, .dataNotAllowed, .callIsActive,
        .secureConnectionFailed,
    ]
}
