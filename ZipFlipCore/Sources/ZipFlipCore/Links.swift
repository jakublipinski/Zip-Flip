import Foundation

/// Spreadsheet ids, Zip Flip links and Google's endpoints (README decisions
/// 2 and 3).
public enum Links {
    public static let host = "zip-flip.app"

    private static let idShape = try! Regex(#"^[A-Za-z0-9_-]{20,}$"#)
    /// Also matches the `/spreadsheets/u/1/d/` form that appears when the browser is signed into several Google accounts.
    private static let idInSheetsURL = try! Regex(#"/spreadsheets/(?:u/\d+/)?d/([A-Za-z0-9_-]{20,})"#)
    private static let bareID = try! Regex(#"^[A-Za-z0-9_-]{25,}$"#)

    public static func isSpreadsheetID(_ s: String) -> Bool {
        s.wholeMatch(of: idShape) != nil
    }

    /// The spreadsheet id in a pasted Google Sheets address, or a bare id.
    public static func spreadsheetID(fromPastedText text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m = t.firstMatch(of: idInSheetsURL), let id = m.output[1].substring {
            return String(id)
        }
        if t.wholeMatch(of: bareID) != nil { return t }
        return nil
    }

    /// The id carried by a Zip Flip link, `https://zip-flip.app/s/?id=<id>`,
    /// with or without the trailing slash. Anything else is nil.
    public static func spreadsheetID(fromZipFlipLink url: URL) -> String? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.host?.lowercased() == host,
              parts.path == "/s" || parts.path == "/s/",
              let id = parts.queryItems?.first(where: { $0.name == "id" })?.value,
              isSpreadsheetID(id) else { return nil }
        return id
    }

    public static func zipFlipLink(for id: String) -> URL {
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = host
        parts.path = "/s/"
        parts.queryItems = [URLQueryItem(name: "id", value: id)]
        return parts.url!
    }

    public static func sheetPage(for id: String) -> URL {
        URL(string: "https://docs.google.com/spreadsheets/d/\(id)/edit")!
    }

    /// The HTML view that lists the visible tabs.
    public static func htmlView(for id: String) -> URL {
        URL(string: "https://docs.google.com/spreadsheets/d/\(id)/htmlview")!
    }

    /// The CSV export of one tab.
    public static func csvExport(for id: String, gid: String) -> URL {
        URL(string: "https://docs.google.com/spreadsheets/d/\(id)/export?format=csv&gid=\(gid)")!
    }

    /// The tab name Google puts in the export's Content-Disposition header,
    /// `attachment; filename="<title> - <tab>.csv"`, or nil.
    public static func tabName(fromContentDisposition header: String) -> String? {
        exportFileName(fromContentDisposition: header).flatMap { split($0)?.tab }
    }

    /// The spreadsheet title from the same header, or nil.
    public static func spreadsheetTitle(fromContentDisposition header: String) -> String? {
        exportFileName(fromContentDisposition: header).flatMap { split($0)?.title }
    }

    private static let utf8FileName = try! Regex(#"filename\*=UTF-8''([^;]+)"#)
    private static let plainFileName = try! Regex(#"filename="([^"]*)""#)

    /// The UTF-8 form of the file name when present (it keeps spaces and
    /// non-ASCII letters), otherwise the plain one.
    static func exportFileName(fromContentDisposition header: String) -> String? {
        if let m = header.firstMatch(of: utf8FileName), let encoded = m.output[1].substring,
           let decoded = String(encoded).removingPercentEncoding {
            return decoded
        }
        if let m = header.firstMatch(of: plainFileName), let plain = m.output[1].substring {
            return String(plain)
        }
        return nil
    }

    /// "<title> - <tab>.csv" split at the last " - ".
    private static func split(_ fileName: String) -> (title: String, tab: String)? {
        guard fileName.hasSuffix(".csv") else { return nil }
        let stem = fileName.dropLast(4)
        guard let range = stem.range(of: " - ", options: .backwards) else { return nil }
        let title = String(stem[..<range.lowerBound])
        let tab = String(stem[range.upperBound...])
        guard !tab.isEmpty else { return nil }
        return (title, tab)
    }
}
