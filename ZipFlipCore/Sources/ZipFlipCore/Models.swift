import Foundation

/// One flashcard. `key` identifies the card across edits of the sheet
/// (README decision 14): a hash of the normalised front text.
public struct Card: Hashable, Sendable {
    public let front: String
    public let back: String
    public let key: String

    public init(front: String, back: String) {
        self.front = front
        self.back = back
        self.key = CardKey.make(front)
    }
}

/// One tab of the spreadsheet (README decision 5).
public struct Deck: Equatable, Sendable {
    public let name: String
    /// Google's tab id. It never changes when the tab is renamed or moved.
    public let gid: String
    public let cards: [Card]

    public init(name: String, gid: String, cards: [Card]) {
        self.name = name
        self.gid = gid
        self.cards = cards
    }
}

/// A tab as listed by the spreadsheet's HTML view.
public struct Tab: Hashable, Sendable {
    public let name: String
    public let gid: String

    public init(name: String, gid: String) {
        self.name = name
        self.gid = gid
    }
}

public struct Spreadsheet: Equatable, Sendable {
    public let id: String
    public let decks: [Deck]

    public init(id: String, decks: [Deck]) {
        self.id = id
        self.decks = decks
    }
}

/// The two answers (README decision 7).
public enum Answer: String, Codable, Sendable {
    case gotIt
    case again
}

/// What the watch remembers about one card.
public struct CardProgress: Codable, Equatable, Sendable {
    /// 0 means not yet learned, or just forgotten; 1 to 8 are rungs of the
    /// ladder, each setting the gap to the next review (`Scheduler.ladder`).
    public var level: Int
    public var due: Day
    public var reviews: Int
    public var lapses: Int
    /// The day the card was first answered. Counts against the daily new-card
    /// allowance (README decision 13).
    public var introduced: Day
    public var lastReviewed: Day

    public init(level: Int, due: Day, reviews: Int, lapses: Int, introduced: Day, lastReviewed: Day) {
        self.level = level
        self.due = due
        self.reviews = reviews
        self.lapses = lapses
        self.introduced = introduced
        self.lastReviewed = lastReviewed
    }
}

/// The progress file of one deck (README decision 14), keyed by card key.
public struct DeckProgress: Codable, Equatable, Sendable {
    public static let currentSchema = 1

    public var schema: Int
    public var gid: String
    public var cards: [String: CardProgress]

    public init(gid: String, cards: [String: CardProgress] = [:], schema: Int = DeckProgress.currentSchema) {
        self.schema = schema
        self.gid = gid
        self.cards = cards
    }

    public subscript(card: Card) -> CardProgress? {
        get { cards[card.key] }
        set { cards[card.key] = newValue }
    }
}
