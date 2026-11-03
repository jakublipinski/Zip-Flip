import XCTest
@testable import ZipFlipCore

final class DeckBuilderTests: XCTestCase {
    func testSpanishTab() throws {
        let deck = DeckBuilder.deck(name: "Spanish", gid: "0", csv: try Fixtures.text("tab-0.csv"))
        XCTAssertEqual(deck.cards.map(\.front), [
            "yes", "no", "the dog", "Hello, how are you?", "the house", "good morning",
            "one, two, three", "to be\n(permanent)", "water",
        ], "header row, empty row and the row without a back are skipped")
        XCTAssertEqual(deck.cards[2].back, "el perro")
        XCTAssertEqual(deck.cards[3].back, "Hola, ¿qué tal?")
        XCTAssertEqual(deck.name, "Spanish")
        XCTAssertEqual(deck.gid, "0")
    }

    func testCapitalsTabCollapsesTheDuplicateFront() throws {
        let deck = DeckBuilder.deck(name: "Capitals", gid: "1001", csv: try Fixtures.text("tab-1001.csv"))
        XCTAssertEqual(deck.cards.map(\.front), ["Poland", "France", "Japan", "Australia"])
        XCTAssertEqual(deck.cards[0].back, "Warsaw", "the first row wins")
    }

    func testTimesTablesTab() throws {
        let deck = DeckBuilder.deck(name: "Times tables", gid: "1002", csv: try Fixtures.text("tab-1002.csv"))
        XCTAssertEqual(deck.cards.count, 12)
        XCTAssertEqual(deck.cards[0].front, "6 × 1")
        XCTAssertEqual(deck.cards[11].back, "72")
    }

    func testEmptyTab() throws {
        XCTAssertEqual(DeckBuilder.deck(name: "Empty", gid: "1004", csv: try Fixtures.text("tab-1004.csv")).cards, [])
    }

    func testHeaderOnlyCountsOnTheFirstRow() {
        let deck = DeckBuilder.deck(name: "x", gid: "1", rows: [["x", "y"], ["front", "back"]])
        XCTAssertEqual(deck.cards.map(\.front), ["x", "front"])
        XCTAssertEqual(DeckBuilder.deck(name: "x", gid: "1", rows: [["FRONT", "Back"], ["a", "b"]]).cards.count, 1)
        XCTAssertEqual(DeckBuilder.deck(name: "x", gid: "1", rows: [["front", "back", "notes"], ["a", "b"]]).cards.count, 1)
    }

    func testTrimmingAndThirdColumn() {
        let deck = DeckBuilder.deck(name: "x", gid: "1", rows: [["  dog ", " perro\n", "ignored"], ["cat"], ["", "gato"]])
        XCTAssertEqual(deck.cards.count, 1)
        XCTAssertEqual(deck.cards[0].front, "dog")
        XCTAssertEqual(deck.cards[0].back, "perro")
    }

    func testFrontsThatDifferOnlyInCaseOrSpacingAreOneCard() {
        let deck = DeckBuilder.deck(name: "x", gid: "1", rows: [["Dog", "a"], ["dog  ", "b"], ["DOG", "c"]])
        XCTAssertEqual(deck.cards.count, 1)
        XCTAssertEqual(deck.cards[0].back, "a")
    }
}
