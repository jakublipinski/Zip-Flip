import Foundation

/// Spreadsheet ids, Zip Flip links and Google's endpoints (README decisions
/// 2 and 3).
public enum Links {
    public static let host = "zip-flip.app"

    private static let idShape = try! Regex(#"^[A-Za-z0-9_-]{20,}$"#)
    private static let idInSheetsURL = try! Regex(#"/spreadsheets/d/([A-Za-z0-9_-]{20,})"#)
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
        if let m = header.firstMatch(of: utf8FileName), let encoded = m.output[1].substring,
           let decoded = String(encoded).removingPercentEncoding, let name = tabPart(of: decoded) {
            return name
        }
        if let m = header.firstMatch(of: plainFileName), let plain = m.output[1].substring,
           let name = tabPart(of: String(plain)) {
            return name
        }
        return nil
    }

    private static let utf8FileName = try! Regex(#"filename\*=UTF-8''([^;]+)"#)
    private static let plainFileName = try! Regex(#"filename="([^"]*)""#)

    private static func tabPart(of fileName: String) -> String? {
        guard fileName.hasSuffix(".csv") else { return nil }
        let stem = fileName.dropLast(4)
        guard let range = stem.range(of: " - ", options: .backwards) else { return nil }
        let tab = stem[range.upperBound...]
        return tab.isEmpty ? nil : String(tab)
    }
}
