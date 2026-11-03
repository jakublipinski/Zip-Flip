import XCTest
@testable import ZipFlipCore

final class ProgressStoreTests: XCTestCase {
    var root: URL!
    var store: ProgressStore!
    let today = Day("2026-11-02")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ZipFlipCoreTests-\(UUID().uuidString)")
        store = ProgressStore(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testMissingFileReadsAsEmptyProgress() {
        XCTAssertEqual(store.load(spreadsheet: "sheet", gid: "7"), DeckProgress(gid: "7"))
    }

    func testRoundTrip() throws {
        let card = Card(front: "dog", back: "perro")
        var p = DeckProgress(gid: "7")
        p[card] = CardProgress(level: 2, due: today.adding(days: 2), reviews: 3, lapses: 1, introduced: today.adding(days: -4), lastReviewed: today)
        try store.save(p, spreadsheet: "sheet")
        XCTAssertEqual(store.load(spreadsheet: "sheet", gid: "7"), p)
        let text = try String(contentsOf: store.layout.progressFile(spreadsheet: "sheet", gid: "7"), encoding: .utf8)
        XCTAssertTrue(text.contains("\"schema\" : 1"))
        XCTAssertTrue(text.contains("\"due\" : \"2026-11-04\""))
    }

    func testCorruptOrFutureFileReadsAsEmpty() throws {
        let url = store.layout.progressFile(spreadsheet: "sheet", gid: "7")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)
        XCTAssertEqual(store.load(spreadsheet: "sheet", gid: "7"), DeckProgress(gid: "7"))
        try Data(#"{"schema": 99, "gid": "7", "cards": {}}"#.utf8).write(to: url)
        XCTAssertEqual(store.load(spreadsheet: "sheet", gid: "7"), DeckProgress(gid: "7"), "a newer schema is not guessed at")
    }

    func testPruningKeepsDeckCardsAndRecentStrays() {
        let kept = Card(front: "kept", back: "")
        let recentStray = Card(front: "recent", back: "")
        let oldStray = Card(front: "old", back: "")
        var p = DeckProgress(gid: "7")
        let stale = CardProgress(level: 3, due: today, reviews: 1, lapses: 0, introduced: today.adding(days: -400), lastReviewed: today.adding(days: -400))
        p[kept] = stale
        p[oldStray] = stale
        p[recentStray] = CardProgress(level: 3, due: today, reviews: 1, lapses: 0, introduced: today.adding(days: -179), lastReviewed: today.adding(days: -179))
        let pruned = ProgressStore.pruned(p, keeping: [kept.key], today: today)
        XCTAssertEqual(Set(pruned.cards.keys), [kept.key, recentStray.key])
    }

    func testStaleDeckFilesAreRemovedAfter180Days() throws {
        try store.save(DeckProgress(gid: "1"), spreadsheet: "sheet")
        try store.save(DeckProgress(gid: "2"), spreadsheet: "sheet")
        try store.save(DeckProgress(gid: "3"), spreadsheet: "sheet")
        let old = Date().addingTimeInterval(-200 * 86_400)
        for gid in ["2", "3"] {
            try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: store.layout.progressFile(spreadsheet: "sheet", gid: gid).path)
        }
        try store.removeStaleDecks(spreadsheet: "sheet", currentGids: ["1", "3"])
        let names = try FileManager.default.contentsOfDirectory(atPath: store.layout.folder(spreadsheet: "sheet").path).sorted()
        XCTAssertEqual(names, ["1.progress.json", "3.progress.json"], "2 is gone: not in the sheet and untouched for 200 days")
    }

    func testLayout() {
        let layout = StoreLayout(root: URL(fileURLWithPath: "/tmp/zf"))
        XCTAssertEqual(layout.progressFile(spreadsheet: "abc", gid: "12").path, "/tmp/zf/abc/12.progress.json")
        XCTAssertEqual(layout.csvFile(spreadsheet: "abc", gid: "12").path, "/tmp/zf/abc/12.csv")
        XCTAssertEqual(layout.metadataFile(spreadsheet: "abc").path, "/tmp/zf/abc/spreadsheet.json")
        XCTAssertEqual(StoreLayout.progressGid(fromFileName: "12.progress.json"), "12")
        XCTAssertNil(StoreLayout.progressGid(fromFileName: "12.csv"))
    }
}
