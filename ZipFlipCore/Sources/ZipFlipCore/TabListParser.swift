import Foundation

/// Reads the tab list out of a spreadsheet's HTML view (README decision 5).
/// The page embeds one script entry per visible tab:
///
///     items.push({name: "Capitals", pageUrl: "...", gid: "1001", initialSheet: ...});
///
/// Hidden tabs are not listed. This is the one piece of fragile parsing in the
/// app, kept here on its own; when nothing parses the caller falls back to a
/// single tab with gid 0 (`fallback`).
public enum TabListParser {
    public static let fallback = [Tab(name: "", gid: "0")]

    private static let entry = try! Regex(
        #"items\.push\(\{name:\s*"((?:[^"\\]|\\.)*)",\s*pageUrl:\s*"(?:[^"\\]|\\.)*",\s*gid:\s*"(\d+)""#
    )

    /// The visible tabs in display order, or an empty array when the page
    /// does not look like a spreadsheet's HTML view.
    public static func tabs(fromHTML html: String) -> [Tab] {
        var tabs: [Tab] = []
        var seen = Set<String>()
        for match in html.matches(of: entry) {
            guard let name = match.output[1].substring, let gid = match.output[2].substring else { continue }
            let g = String(gid)
            guard seen.insert(g).inserted else { continue }
            tabs.append(Tab(name: decodeJavaScriptString(String(name)), gid: g))
        }
        return tabs
    }

    public static func tabsOrFallback(fromHTML html: String) -> [Tab] {
        let found = tabs(fromHTML: html)
        return found.isEmpty ? fallback : found
    }

    /// Decodes the escapes Google uses inside script string literals:
    /// `\x3d`, `é`, `\"`, `\\`, `\/`, `\n`, `\t`.
    static func decodeJavaScriptString(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        let scalars = Array(s.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            guard c == "\\", i + 1 < scalars.count else { out.append(c); i += 1; continue }
            let e = scalars[i + 1]
            switch e {
            case "x" where i + 3 < scalars.count:
                if let v = UInt32(String(String.UnicodeScalarView(scalars[(i + 2)...(i + 3)])), radix: 16),
                   let u = Unicode.Scalar(v) {
                    out.append(u); i += 4; continue
                }
            case "u" where i + 5 < scalars.count:
                if let v = UInt32(String(String.UnicodeScalarView(scalars[(i + 2)...(i + 5)])), radix: 16),
                   let u = Unicode.Scalar(v) {
                    out.append(u); i += 6; continue
                }
            case "n": out.append("\n"); i += 2; continue
            case "t": out.append("\t"); i += 2; continue
            case "r": out.append("\r"); i += 2; continue
            default: break
            }
            out.append(e)
            i += 2
        }
        return String(out)
    }
}
