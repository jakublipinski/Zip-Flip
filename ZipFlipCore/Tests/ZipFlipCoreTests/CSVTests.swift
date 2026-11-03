import XCTest
@testable import ZipFlipCore

final class CSVTests: XCTestCase {
    func testGoogleExportOfTheSpanishTab() throws {
        let rows = CSV.parse(try Fixtures.text("tab-0.csv"))
        XCTAssertEqual(rows.count, 12)
        XCTAssertEqual(rows[0], ["front", "back", "notes"])
        XCTAssertEqual(rows[1], ["yes", "sí", ""])
        XCTAssertEqual(rows[4], ["Hello, how are you?", "Hola, ¿qué tal?", "comma in both cells"])
        XCTAssertEqual(rows[5], ["", "", ""], "an empty row in the middle survives as empty fields")
        XCTAssertEqual(rows[9][0], "to be\n(permanent)", "a line break inside a quoted field is a bare LF")
        XCTAssertEqual(rows[10], ["thank you", "", "no back"])
        XCTAssertEqual(rows[11], ["water", "el agua", ""], "the last record has no trailing CRLF")
    }

    func testEmptyTabIsNoRows() throws {
        XCTAssertEqual(CSV.parse(try Fixtures.text("tab-1004.csv")), [])
        XCTAssertEqual(CSV.parse(""), [])
    }

    func testLineEndings() {
        XCTAssertEqual(CSV.parse("a,b\r\nc,d\r\n"), [["a", "b"], ["c", "d"]])
        XCTAssertEqual(CSV.parse("a,b\nc,d"), [["a", "b"], ["c", "d"]])
        XCTAssertEqual(CSV.parse("a,b\rc,d\r"), [["a", "b"], ["c", "d"]])
        XCTAssertEqual(CSV.parse("a,b\n\nc,d\n"), [["a", "b"], [""], ["c", "d"]])
    }

    func testQuoting() {
        XCTAssertEqual(CSV.parse(#""say ""hi""",x"#), [["say \"hi\"", "x"]])
        XCTAssertEqual(CSV.parse("\"one\r\ntwo\",x"), [["one\r\ntwo", "x"]])
        XCTAssertEqual(CSV.parse("\"a,b\",\"\"\n"), [["a,b", ""]])
        XCTAssertEqual(CSV.parse("\"\""), [[""]])
        XCTAssertEqual(CSV.parse("it's 5\" tall,x"), [["it's 5\" tall", "x"]], "a stray quote inside a bare field is text")
    }

    func testByteOrderMarkIsDropped() {
        XCTAssertEqual(CSV.parse("\u{FEFF}a,b"), [["a", "b"]])
    }

    func testUnicodeSurvives() {
        XCTAssertEqual(CSV.parse("6 × 1,6\r\nżółw,🐢"), [["6 × 1", "6"], ["żółw", "🐢"]])
    }
}
