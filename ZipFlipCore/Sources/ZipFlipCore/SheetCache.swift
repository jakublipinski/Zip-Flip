import Foundation

/// What the watch remembers about the spreadsheet itself (README decision 6):
/// the tab list, the title, and when the tabs and the cards were last fetched.
public struct SpreadsheetMetadata: Codable, Equatable, Sendable {
    public static let currentSchema = 1

    public var schema: Int
    public var id: String
    public var title: String?
    public var tabs: [Tab]
    public var tabsFetchedAt: Date?
    public var cardsFetchedAt: Date?

    public init(id: String, title: String? = nil, tabs: [Tab] = [], tabsFetchedAt: Date? = nil,
                cardsFetchedAt: Date? = nil, schema: Int = SpreadsheetMetadata.currentSchema) {
        self.schema = schema
        self.id = id
        self.title = title
        self.tabs = tabs
        self.tabsFetchedAt = tabsFetchedAt
        self.cardsFetchedAt = cardsFetchedAt
    }
}

/// The last downloaded state of a spreadsheet, rebuilt from the cache files.
public struct CachedSpreadsheet: Equatable, Sendable {
    public let metadata: SpreadsheetMetadata
    public let spreadsheet: Spreadsheet
}

/// The cache files next to the progress files: `spreadsheet.json` and one
/// `<gid>.csv` per tab. Reading tolerates anything missing or corrupt.
public final class SheetCache {
    public let layout: StoreLayout
    private let fileManager = FileManager.default

    public init(layout: StoreLayout) {
        self.layout = layout
    }

    public convenience init(root: URL) {
        self.init(layout: StoreLayout(root: root))
    }

    public func metadata(for id: String) -> SpreadsheetMetadata? {
        guard let data = try? Data(contentsOf: layout.metadataFile(spreadsheet: id)),
              let meta = try? SheetCache.decoder.decode(SpreadsheetMetadata.self, from: data),
              meta.schema <= SpreadsheetMetadata.currentSchema, meta.id == id else { return nil }
        return meta
    }

    public func save(_ metadata: SpreadsheetMetadata) throws {
        try fileManager.createDirectory(at: layout.folder(spreadsheet: metadata.id), withIntermediateDirectories: true)
        let data = try SheetCache.encoder.encode(metadata)
        try data.write(to: layout.metadataFile(spreadsheet: metadata.id), options: .atomic)
    }

    public func csv(for id: String, gid: String) -> String? {
        guard let data = try? Data(contentsOf: layout.csvFile(spreadsheet: id, gid: gid)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public func save(csv: String, for id: String, gid: String) throws {
        try fileManager.createDirectory(at: layout.folder(spreadsheet: id), withIntermediateDirectories: true)
        try Data(csv.utf8).write(to: layout.csvFile(spreadsheet: id, gid: gid), options: .atomic)
    }

    /// Deletes cached CSVs of tabs that are no longer listed. Progress files stay
    /// (`ProgressStore.removeStaleDecks` handles those after 180 days).
    public func removeCSVs(for id: String, notIn gids: Set<String>) {
        let folder = layout.folder(spreadsheet: id)
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return }
        for name in names where name.hasSuffix(".csv") {
            let gid = String(name.dropLast(4))
            if !gids.contains(gid) {
                try? fileManager.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    /// The decks as last downloaded. A tab whose CSV is missing is an empty deck.
    public func load(_ id: String) -> CachedSpreadsheet? {
        guard let meta = metadata(for: id) else { return nil }
        let decks = meta.tabs.map { tab in
            DeckBuilder.deck(name: tab.name, gid: tab.gid, csv: csv(for: id, gid: tab.gid) ?? "")
        }
        return CachedSpreadsheet(metadata: meta, spreadsheet: Spreadsheet(id: id, decks: decks))
    }

    public func remove(_ id: String) {
        try? fileManager.removeItem(at: layout.folder(spreadsheet: id))
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
