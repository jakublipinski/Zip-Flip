#if DEBUG
import SwiftUI
import ZipFlipCore

/// Debug builds only: launch arguments that open one screen directly, for
/// simulator review and screenshots without synthesised taps.
///
///     -spreadsheetID <id> -zfScreen deck:<gid>
///     -zfScreen session:<gid> [-zfFlip YES]     card front, or back with -zfFlip
///     -zfScreen practice:<gid>
///     -zfScreen done:<gid>
///     -zfScreen problem:notReadable|offline|other
///     -zfScreen about
///
/// Release builds never read these keys (`#if DEBUG` around the whole file).
enum DebugScreen {
    static var requested: String? {
        UserDefaults.standard.string(forKey: "zfScreen")
    }

    static var flip: Bool {
        UserDefaults.standard.bool(forKey: "zfFlip")
    }
}

struct DebugScreenView: View {
    @Environment(Library.self) private var library
    let screen: String

    var body: some View {
        let parts = screen.split(separator: ":", maxSplits: 1).map(String.init)
        let kind = parts.first ?? ""
        let arg = parts.count > 1 ? parts[1] : ""
        let deck = library.decks.first { $0.gid == arg }

        switch kind {
        case "about":
            AboutView()
        case "problem":
            ProblemView(kind: arg == "offline" ? .offline : arg == "other" ? .other : .notReadable)
        case "deck", "session", "practice", "done":
            if let deck {
                switch kind {
                case "deck":
                    DeckView(deck: deck)
                case "session":
                    SessionView(deck: deck, mode: .study, onDecks: {}, onContinue: {}, debugShowBack: DebugScreen.flip)
                case "practice":
                    SessionView(deck: deck, mode: .practice, onDecks: {}, onContinue: {}, debugShowBack: DebugScreen.flip)
                default:
                    DoneView(deck: deck, mode: .study, reviewed: 20, gotIt: 17, onDecks: {}, onContinue: {}, onPractice: {})
                        .navigationTitle(deck.name)
                        .toolbarForegroundStyle(Design.teal, for: .navigationBar)
                }
            } else {
                ProgressView()
                    .navigationTitle("Loading")
            }
        default:
            Text(verbatim: "Unknown -zfScreen \(screen)")
        }
    }
}

/// Debug builds only: the last link the app was handed and by which entry
/// point, kept across launches, so a tap in Messages can be diagnosed on the
/// watch itself. Shown on the first-run screen and in About.
@Observable
@MainActor
final class DebugLinkLog {
    static let shared = DebugLinkLog()
    private static let key = "zfLastLink"

    private(set) var last: String? = UserDefaults.standard.string(forKey: DebugLinkLog.key)

    func record(_ text: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        last = "\(stamp) \(text)"
        UserDefaults.standard.set(last, forKey: DebugLinkLog.key)
    }
}

struct DebugLinkLine: View {
    var body: some View {
        Text(verbatim: "Last link: \(DebugLinkLog.shared.last ?? "none received")")
            .font(.system(size: 10))
            .foregroundStyle(Design.secondary)
            .multilineTextAlignment(.center)
    }
}
#endif
