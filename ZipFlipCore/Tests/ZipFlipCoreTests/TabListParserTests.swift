import XCTest
@testable import ZipFlipCore

final class TabListParserTests: XCTestCase {
    func testHTMLViewOfTheTestSheet() throws {
        let tabs = TabListParser.tabs(fromHTML: try Fixtures.text("htmlview.html"))
        XCTAssertEqual(tabs, [
            Tab(name: "Spanish", gid: "0"),
            Tab(name: "Capitals", gid: "1001"),
            Tab(name: "Times tables", gid: "1002"),
            Tab(name: "Empty", gid: "1004"),
        ], "visible tabs in display order; the hidden Archive tab (1003) is absent")
    }

    func testEscapesInNames() {
        let html = #"items.push({name: "Café \x22quoted\x22 a\/b\\c", pageUrl: "\/x?a\x3d1", gid: "42",initialSheet: ("42" == gid)});"#
        XCTAssertEqual(TabListParser.tabs(fromHTML: html), [Tab(name: "Café \"quoted\" a/b\\c", gid: "42")])
    }

    func testDuplicateEntriesCountOnce() {
        let one = #"items.push({name: "A", pageUrl: "p", gid: "7", initialSheet: true});"#
        XCTAssertEqual(TabListParser.tabs(fromHTML: one + one).count, 1)
    }

    func testNothingParsesGivesEmptyAndFallback() {
        XCTAssertEqual(TabListParser.tabs(fromHTML: "<html>Sign in</html>"), [])
        XCTAssertEqual(TabListParser.tabsOrFallback(fromHTML: ""), [Tab(name: "", gid: "0")])
    }

    func testDecodeJavaScriptString() {
        XCTAssertEqual(TabListParser.decodeJavaScriptString(#"a\x3dbł\n\t\\\"\/"#), "a=bł\n\t\\\"/")
        XCTAssertEqual(TabListParser.decodeJavaScriptString(#"trailing\"#), "trailing\\")
    }
}
