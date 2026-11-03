import Foundation

/// Turns the rows of one tab into a deck (README decision 5): column A is the
/// front, column B the back, other columns are ignored, rows with either side
/// empty are skipped, a first row saying "front"/"back" is a header, and a
/// repeated front keeps the first row.
public enum DeckBuilder {
    public static func deck(name: String, gid: String, rows: [[String]]) -> Deck {
        var cards: [Card] = []
        var seen = Set<String>()
        for (index, row) in rows.enumerated() {
            let front = cell(row, 0)
            let back = cell(row, 1)
            if index == 0, isHeader(front: front, back: back) { continue }
            guard !front.isEmpty, !back.isEmpty else { continue }
            let card = Card(front: front, back: back)
            guard seen.insert(card.key).inserted else { continue }
            cards.append(card)
        }
        return Deck(name: name, gid: gid, cards: cards)
    }

    public static func deck(name: String, gid: String, csv: String) -> Deck {
        deck(name: name, gid: gid, rows: CSV.parse(csv))
    }

    static func isHeader(front: String, back: String) -> Bool {
        front.lowercased() == "front" && back.lowercased() == "back"
    }

    private static func cell(_ row: [String], _ index: Int) -> String {
        guard index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
