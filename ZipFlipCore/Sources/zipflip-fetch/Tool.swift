import Foundation
import ZipFlipCore

/// Runs the sheet client from the Mac against a real spreadsheet.
///
///     swift run zipflip-fetch <sheet id or address> [--manual] [--cache DIR] [--base-url URL]
///
/// --manual     refresh everything (default: as the app does on launch)
/// --cache DIR  where to keep the cache (default: ~/Library/Caches/zipflip-fetch)
/// --base-url   send the requests to another origin, e.g. http://127.0.0.1:9/
///              to see the offline failure
@main
struct Tool {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        var reason: RefreshReason = .launch
        var cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("zipflip-fetch")
        var baseURL: URL? = nil

        func take(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            let value = args[i + 1]
            args.removeSubrange(i...(i + 1))
            return value
        }
        if let i = args.firstIndex(of: "--manual") { reason = .manual; args.remove(at: i) }
        if let dir = take("--cache") { cacheDir = URL(fileURLWithPath: dir) }
        if let base = take("--base-url") { baseURL = URL(string: base) }

        guard let input = args.first, let id = Links.spreadsheetID(fromPastedText: input) else {
            print("usage: zipflip-fetch <sheet id or address> [--manual] [--cache DIR] [--base-url URL]")
            exit(64)
        }

        let transport: HTTPTransport = baseURL.map { RewritingTransport(base: $0) } ?? URLSessionTransport()
        let client = SheetClient(transport: transport, cache: SheetCache(root: cacheDir))
        print("spreadsheet \(id)")
        print("cache       \(cacheDir.path)")
        if let cached = client.cached(id) {
            print("cached      tabs \(fmt(cached.metadata.tabsFetchedAt)), cards \(fmt(cached.metadata.cardsFetchedAt))")
        } else {
            print("cached      nothing")
        }

        let started = Date()
        do {
            let result = try await client.refresh(id, reason: reason)
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            print("result      \(result.fetched ? "fetched" : "served from cache")\(result.tabsFetched ? ", tab list refreshed" : "") in \(ms) ms")
            print("title       \(result.cached.metadata.title ?? "-")")
            for deck in result.spreadsheet.decks {
                print(String(format: "  %-20@ gid %-12@ %3d cards", deck.name as NSString, deck.gid as NSString, deck.cards.count))
                for card in deck.cards.prefix(2) {
                    print("      \(card.front.replacingOccurrences(of: "\n", with: "⏎"))  →  \(card.back)")
                }
            }
        } catch let failure as FetchFailure {
            print("failed      \(failure)")
            switch failure {
            case .notReadable: exit(2)
            case .offline: exit(3)
            case .other: exit(4)
            }
        } catch {
            print("failed      \(error)")
            exit(4)
        }
    }

    static func fmt(_ date: Date?) -> String {
        guard let date else { return "never" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

/// Sends every request to `base` instead of Google (same path and query).
struct RewritingTransport: HTTPTransport {
    let base: URL
    let inner = URLSessionTransport(timeout: 10)

    func get(_ url: URL) async throws -> HTTPReply {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let target = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        parts.scheme = target.scheme
        parts.host = target.host
        parts.port = target.port
        return try await inner.get(parts.url!)
    }
}
