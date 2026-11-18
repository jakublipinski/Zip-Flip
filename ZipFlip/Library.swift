import Foundation
import Observation
import WatchKit
import ZipFlipCore

/// Everything the screens read and change: the current spreadsheet, its
/// decks, the progress files, and the state of the last refresh.
/// One instance for the app, created in `ZipFlipApp`.
@Observable
@MainActor
final class Library {
    enum RefreshState: Equatable {
        case idle
        case refreshing
        case failed(FetchFailure, at: Date)

        static func == (lhs: RefreshState, rhs: RefreshState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.refreshing, .refreshing): return true
            case (.failed(let a, let at1), .failed(let b, let at2)): return a.description == b.description && at1 == at2
            default: return false
            }
        }
    }

    static let spreadsheetKey = "spreadsheetID"

    private(set) var spreadsheetID: String?
    private(set) var cached: CachedSpreadsheet?
    private(set) var refreshState: RefreshState = .idle
    /// Progress per deck gid, loaded when a deck is first looked at.
    private(set) var progress: [String: DeckProgress] = [:]

    private let client: SheetClient
    private let store: ProgressStore
    private let defaults: UserDefaults

    init(root: URL = Library.defaultRoot, transport: HTTPTransport = URLSessionTransport(),
         defaults: UserDefaults = .standard) {
        let layout = StoreLayout(root: root)
        self.client = SheetClient(transport: transport, cache: SheetCache(layout: layout))
        self.store = ProgressStore(layout: layout)
        self.defaults = defaults
        // A launch argument -spreadsheetID <id> wins for one launch (screenshots, debugging).
        if let id = defaults.string(forKey: Library.spreadsheetKey), Links.isSpreadsheetID(id) {
            spreadsheetID = id
            cached = client.cached(id)
        }
    }

    nonisolated static var defaultRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ZipFlip", isDirectory: true)
    }

    var decks: [Deck] { cached?.spreadsheet.decks ?? [] }

    func deck(_ gid: String) -> Deck? {
        decks.first { $0.gid == gid }
    }
    var title: String? { cached?.metadata.title }
    var updatedAt: Date? { cached?.metadata.cardsFetchedAt }
    var hasSpreadsheet: Bool { spreadsheetID != nil }
    var today: Day { Day.today() }

    // MARK: Spreadsheet

    /// A Zip Flip link was opened. Anything else is ignored.
    /// `route` says which entry point delivered it; only Debug builds show it.
    func open(_ url: URL, via route: String = "") {
        let id = Links.spreadsheetID(fromZipFlipLink: url)
        #if DEBUG
        DebugLinkLog.shared.record("\(route): \(url.absoluteString) \(id == nil ? "ignored" : "accepted")")
        #endif
        guard let id else { return }
        use(spreadsheetID: id)
    }

    /// Switches to a spreadsheet and fetches it. Progress of the previous one
    /// stays on disk (README decision 5).
    func use(spreadsheetID id: String) {
        if id != spreadsheetID {
            spreadsheetID = id
            defaults.set(id, forKey: Library.spreadsheetKey)
            cached = client.cached(id)
            progress = [:]
            refreshState = .idle
        }
        refresh(reason: .linkOpened)
    }

    /// Forgets the spreadsheet. Its files stay for when it comes back.
    func forgetSpreadsheet() {
        spreadsheetID = nil
        defaults.removeObject(forKey: Library.spreadsheetKey)
        cached = nil
        progress = [:]
        refreshState = .idle
    }

    func refresh(reason: RefreshReason) {
        guard let id = spreadsheetID, refreshState != .refreshing else { return }
        refreshState = .refreshing
        Task {
            do {
                let result = try await client.refresh(id, reason: reason)
                guard id == spreadsheetID else { return }
                cached = result.cached
                refreshState = .idle
            } catch let failure as FetchFailure {
                guard id == spreadsheetID else { return }
                refreshState = .failed(failure, at: Date())
            } catch {
                guard id == spreadsheetID else { return }
                refreshState = .failed(.other(String(describing: error)), at: Date())
            }
        }
    }

    /// Called when the app comes to the front: fetches only what is stale.
    func refreshIfStale() {
        refresh(reason: .launch)
    }

    // MARK: Progress

    func progress(for deck: Deck) -> DeckProgress {
        if let p = progress[deck.gid] { return p }
        guard let id = spreadsheetID else { return DeckProgress(gid: deck.gid) }
        var p = store.load(spreadsheet: id, gid: deck.gid)
        let pruned = ProgressStore.pruned(p, keeping: Set(deck.cards.map(\.key)), today: today)
        if pruned != p {
            p = pruned
            try? store.save(p, spreadsheet: id)
        }
        progress[deck.gid] = p
        return p
    }

    func summary(for deck: Deck) -> DeckSummary {
        SessionPlanner.summary(deck: deck, progress: progress(for: deck), today: today)
    }

    func plan(for deck: Deck) -> SessionPlan {
        SessionPlanner.plan(deck: deck, progress: progress(for: deck), today: today)
    }

    /// Records an answer and writes the deck's progress file at once.
    func record(_ answer: Answer, for card: Card, in deck: Deck) {
        guard let id = spreadsheetID else { return }
        var p = progress(for: deck)
        p[card] = Scheduler.apply(answer, to: p[card], today: today)
        progress[deck.gid] = p
        try? store.save(p, spreadsheet: id)
    }

    // MARK: Haptics

    /// `.click` is the one built-in haptic that stays silent when the watch
    /// is not in Silent Mode (Silent Bell README); a classroom is the likely room.
    nonisolated func tap() {
        WKInterfaceDevice.current().play(.click)
    }
}
