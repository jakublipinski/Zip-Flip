import Foundation

/// What a deck has waiting today.
public struct SessionPlan: Equatable, Sendable {
    /// The cards of this session, due ones first, then new ones.
    public let cards: [Card]
    /// Cards due today or earlier, including those beyond this session.
    public let dueCount: Int
    /// New cards allowed today, including those beyond this session.
    public let newCount: Int
    /// Cards never answered, whether or not they fit today's allowance.
    public let unseenCount: Int
    /// The earliest day a card not yet due comes due, if any.
    public let nextDue: Day?

    /// Cards waiting beyond this session.
    public var remainingCount: Int { dueCount + newCount - cards.count }
}

/// Builds the queue for a deck (README decision 13): every card due today or
/// earlier, sorted by due date with ties shuffled, then new cards in sheet
/// order, at most `newCardsPerDay` new cards per deck per day, at most
/// `sessionSize` cards per session.
public enum SessionPlanner {
    public static let newCardsPerDay = 5
    public static let sessionSize = 20

    public static func plan(
        deck: Deck,
        progress: DeckProgress,
        today: Day,
        using rng: inout some RandomNumberGenerator
    ) -> SessionPlan {
        var due: [(Card, Day)] = []
        var unseen: [Card] = []
        var nextDue: Day? = nil
        for card in deck.cards {
            if let p = progress[card] {
                if p.due <= today {
                    due.append((card, p.due))
                } else if nextDue.map({ p.due < $0 }) ?? true {
                    nextDue = p.due
                }
            } else {
                unseen.append(card)
            }
        }
        due.shuffle(using: &rng)
        let dueCards = due.sorted { $0.1 < $1.1 }.map(\.0)   // sort is stable: ties keep the shuffle

        let introducedToday = progress.cards.values.filter { $0.introduced == today }.count
        let allowance = max(0, newCardsPerDay - introducedToday)
        let newCards = Array(unseen.prefix(allowance))

        let queue = Array((dueCards + newCards).prefix(sessionSize))
        return SessionPlan(cards: queue, dueCount: dueCards.count, newCount: newCards.count,
                           unseenCount: unseen.count, nextDue: nextDue)
    }

    public static func plan(deck: Deck, progress: DeckProgress, today: Day) -> SessionPlan {
        var rng = SystemRandomNumberGenerator()
        return plan(deck: deck, progress: progress, today: today, using: &rng)
    }

    /// Practice (README decision 15): the deck in random order, `sessionSize`
    /// at a time, touching nothing.
    public static func practice(deck: Deck, using rng: inout some RandomNumberGenerator) -> [Card] {
        Array(deck.cards.shuffled(using: &rng).prefix(sessionSize))
    }

    public static func practice(deck: Deck) -> [Card] {
        var rng = SystemRandomNumberGenerator()
        return practice(deck: deck, using: &rng)
    }
}

/// The running queue of one session. A card answered Again comes back a few
/// cards later until it gets a Got it (README decision 13).
public struct Session: Equatable, Sendable {
    public static let againDelay = 3

    public private(set) var upcoming: [Card]
    /// Cards that left the queue with a Got it.
    public private(set) var completed: Int = 0
    /// Answers given, Again included.
    public private(set) var answered: Int = 0

    public init(cards: [Card]) {
        self.upcoming = cards
    }

    public var current: Card? { upcoming.first }
    public var isFinished: Bool { upcoming.isEmpty }
    /// Distinct cards still to clear.
    public var remaining: Int { Set(upcoming.map(\.key)).count }

    /// Records the answer for the current card and advances.
    public mutating func answer(_ answer: Answer) {
        guard !upcoming.isEmpty else { return }
        let card = upcoming.removeFirst()
        answered += 1
        switch answer {
        case .gotIt:
            completed += 1
        case .again:
            upcoming.insert(card, at: min(Session.againDelay, upcoming.count))
        }
    }
}
