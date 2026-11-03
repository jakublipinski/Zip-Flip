import Foundation

/// Where the app keeps its files (README decision 14): one folder per
/// spreadsheet under the root, holding a metadata file, the last CSV of each
/// tab and the progress file of each tab, both named by the tab's gid.
public struct StoreLayout: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func folder(spreadsheet id: String) -> URL {
        root.appendingPathComponent(id, isDirectory: true)
    }

    public func metadataFile(spreadsheet id: String) -> URL {
        folder(spreadsheet: id).appendingPathComponent("spreadsheet.json")
    }

    public func csvFile(spreadsheet id: String, gid: String) -> URL {
        folder(spreadsheet: id).appendingPathComponent("\(gid).csv")
    }

    public func progressFile(spreadsheet id: String, gid: String) -> URL {
        folder(spreadsheet: id).appendingPathComponent("\(gid).progress.json")
    }

    public static func progressGid(fromFileName name: String) -> String? {
        let suffix = ".progress.json"
        guard name.hasSuffix(suffix) else { return nil }
        return String(name.dropLast(suffix.count))
    }
}

/// Reads and writes the progress files. Every write is atomic. A missing or
/// unreadable file reads as empty progress, so a corrupt file costs the
/// progress of one deck, never a crash.
public final class ProgressStore {
    public static let keepUnseenForDays = 180

    public let layout: StoreLayout
    private let fileManager = FileManager.default

    public init(layout: StoreLayout) {
        self.layout = layout
    }

    public convenience init(root: URL) {
        self.init(layout: StoreLayout(root: root))
    }

    public func load(spreadsheet id: String, gid: String) -> DeckProgress {
        let url = layout.progressFile(spreadsheet: id, gid: gid)
        guard let data = try? Data(contentsOf: url),
              let progress = try? ProgressStore.decoder.decode(DeckProgress.self, from: data),
              progress.schema <= DeckProgress.currentSchema else {
            return DeckProgress(gid: gid)
        }
        return progress
    }

    public func save(_ progress: DeckProgress, spreadsheet id: String) throws {
        try fileManager.createDirectory(at: layout.folder(spreadsheet: id), withIntermediateDirectories: true)
        let data = try ProgressStore.encoder.encode(progress)
        try data.write(to: layout.progressFile(spreadsheet: id, gid: progress.gid), options: .atomic)
    }

    /// Drops entries for cards no longer in the deck once they have gone
    /// unreviewed for `keepUnseenForDays` (README decision 14).
    public static func pruned(_ progress: DeckProgress, keeping keys: Set<String>, today: Day) -> DeckProgress {
        var p = progress
        p.cards = p.cards.filter { key, card in
            keys.contains(key) || card.lastReviewed.days(until: today) <= keepUnseenForDays
        }
        return p
    }

    /// Removes progress files of tabs that are no longer in the sheet, once the
    /// file has not been written for `keepUnseenForDays`.
    public func removeStaleDecks(spreadsheet id: String, currentGids: Set<String>, now: Date = Date()) throws {
        let folder = layout.folder(spreadsheet: id)
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return }
        let cutoff = now.addingTimeInterval(-Double(ProgressStore.keepUnseenForDays) * 86_400)
        for name in names {
            guard let gid = StoreLayout.progressGid(fromFileName: name), !currentGids.contains(gid) else { continue }
            let url = folder.appendingPathComponent(name)
            let modified = (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? now
            if modified < cutoff {
                try fileManager.removeItem(at: url)
            }
        }
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder = JSONDecoder()
}
