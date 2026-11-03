import XCTest
@testable import ZipFlipCore

final class SessionPlannerTests: XCTestCase {
    let today = Day("2026-11-02")!

    func makeDeck(_ n: Int) -> Deck {
        Deck(name: "d", gid: "1", cards: (0..<n).map { Card(front: "f\($0)", back: "b\($0)") })
    }

    func progress(due: Day, introduced: Day? = nil, level: Int = 2) -> CardProgress {
        CardProgress(level: level, due: due, reviews: 1, lapses: 0, introduced: introduced ?? due.adding(days: -10), lastReviewed: due.adding(days: -2))
    }

    func testDueFirstByDateThenNewInSheetOrder() {
        let deck = makeDeck(30)
        var p = DeckProgress(gid: "1")
        p[deck.cards[0]] = progress(due: today)
        p[deck.cards[1]] = progress(due: today.adding(days: -5))
        p[deck.cards[2]] = progress(due: today.adding(days: -1))
        p[deck.cards[3]] = progress(due: today.adding(days: 3))   // not due
        var rng = SeededRNG(seed: 1)
        let plan = SessionPlanner.plan(deck: deck, progress: p, today: today, using: &rng)
        XCTAssertEqual(plan.cards.prefix(3).map(\.front), ["f1", "f2", "f0"])
        XCTAssertEqual(plan.cards.dropFirst(3).map(\.front), ["f4", "f5", "f6", "f7", "f8"], "five new cards in sheet order")
        XCTAssertEqual(plan.dueCount, 3)
        XCTAssertEqual(plan.newCount, 5)
        XCTAssertEqual(plan.unseenCount, 26)
        XCTAssertEqual(plan.remainingCount, 0)
        XCTAssertEqual(plan.nextDue, today.adding(days: 3))
    }

    func testTiesAreShuffledButStillSortedByDate() {
        let deck = makeDeck(12)
        var p = DeckProgress(gid: "1")
        for (i, card) in deck.cards.enumerated() {
            p[card] = progress(due: i < 6 ? today.adding(days: -2) : today)
        }
        var orders = Set<[String]>()
        for seed in 0..<10 {
            var rng = SeededRNG(seed: UInt64(seed))
            let plan = SessionPlanner.plan(deck: deck, progress: p, today: today, using: &rng)
            let fronts = plan.cards.map(\.front)
            XCTAssertEqual(Set(fronts.prefix(6)), Set((0..<6).map { "f\($0)" }), "older due dates come first")
            orders.insert(fronts)
        }
        XCTAssertGreaterThan(orders.count, 1, "ties come in different orders")
    }

    func testDailyNewCardAllowanceCountsCardsIntroducedToday() {
        let deck = makeDeck(10)
        var p = DeckProgress(gid: "1")
        for card in deck.cards.prefix(3) {
            p[card] = progress(due: today.adding(days: 1), introduced: today)
        }
        var rng = SeededRNG(seed: 1)
        let plan = SessionPlanner.plan(deck: deck, progress: p, today: today, using: &rng)
        XCTAssertEqual(plan.cards.map(\.front), ["f3", "f4"], "three introduced today leaves two")
        XCTAssertEqual(plan.newCount, 2)
    }

    func testSessionSizeCapsTheQueue() {
        let deck = makeDeck(40)
        var p = DeckProgress(gid: "1")
        for card in deck.cards.prefix(25) { p[card] = progress(due: today) }
        var rng = SeededRNG(seed: 1)
        let plan = SessionPlanner.plan(deck: deck, progress: p, today: today, using: &rng)
        XCTAssertEqual(plan.cards.count, 20)
        XCTAssertEqual(plan.dueCount, 25)
        XCTAssertEqual(plan.newCount, 5)
        XCTAssertEqual(plan.remainingCount, 10)
    }

    func testNothingDueAndNothingNew() {
        let deck = makeDeck(2)
        var p = DeckProgress(gid: "1")
        p[deck.cards[0]] = progress(due: today.adding(days: 9))
        p[deck.cards[1]] = progress(due: today.adding(days: 2))
        var rng = SeededRNG(seed: 1)
        let plan = SessionPlanner.plan(deck: deck, progress: p, today: today, using: &rng)
        XCTAssertEqual(plan.cards, [])
        XCTAssertEqual(plan.nextDue, today.adding(days: 2))
    }

    func testPracticeIsAShuffledSlice() {
        let deck = makeDeck(25)
        var rng = SeededRNG(seed: 3)
        let cards = SessionPlanner.practice(deck: deck, using: &rng)
        XCTAssertEqual(cards.count, 20)
        XCTAssertEqual(Set(cards).count, 20)
        XCTAssertNotEqual(cards.map(\.front), deck.cards.prefix(20).map(\.front))
    }

    func testSessionBringsAnAgainBackThreeCardsLater() {
        let cards = makeDeck(5).cards
        var s = Session(cards: cards)
        XCTAssertEqual(s.current?.front, "f0")
        s.answer(.again)
        XCTAssertEqual(s.upcoming.map(\.front), ["f1", "f2", "f3", "f0", "f4"])
        s.answer(.gotIt); s.answer(.gotIt); s.answer(.gotIt)
        XCTAssertEqual(s.current?.front, "f0")
        XCTAssertEqual(s.completed, 3)
        XCTAssertEqual(s.remaining, 2)
        s.answer(.gotIt)
        s.answer(.again)
        XCTAssertEqual(s.current?.front, "f4", "an Again on the last card shows it again at once")
        s.answer(.gotIt)
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.completed, 5)
        XCTAssertEqual(s.answered, 7)
        s.answer(.gotIt)
        XCTAssertEqual(s.answered, 7, "answers after the end are ignored")
    }
}
