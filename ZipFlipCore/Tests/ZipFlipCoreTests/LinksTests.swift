import XCTest
@testable import ZipFlipCore

final class LinksTests: XCTestCase {
    let id = "1gqG1A6OSHIcWcxnPhfF7ouWymoo5u67F6eJLOPTXHSI"

    func testIDFromPastedSheetsAddress() {
        XCTAssertEqual(Links.spreadsheetID(fromPastedText: "https://docs.google.com/spreadsheets/d/\(id)/edit?usp=sharing"), id)
        XCTAssertEqual(Links.spreadsheetID(fromPastedText: " https://docs.google.com/spreadsheets/d/\(id)/edit#gid=0\n"), id)
        XCTAssertEqual(Links.spreadsheetID(fromPastedText: id), id, "a bare id is accepted")
        XCTAssertNil(Links.spreadsheetID(fromPastedText: "https://docs.google.com/document/d/\(id)/edit"))
        XCTAssertNil(Links.spreadsheetID(fromPastedText: "short"))
        XCTAssertNil(Links.spreadsheetID(fromPastedText: ""))
    }

    func testIDFromZipFlipLink() {
        XCTAssertEqual(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://zip-flip.app/s/?id=\(id)")!), id)
        XCTAssertEqual(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://zip-flip.app/s?id=\(id)")!), id)
        XCTAssertEqual(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://ZIP-FLIP.app/s/?utm=x&id=\(id)")!), id)
        XCTAssertNil(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://zip-flip.app/s/")!))
        XCTAssertNil(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://zip-flip.app/?id=\(id)")!))
        XCTAssertNil(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://example.com/s/?id=\(id)")!))
        XCTAssertNil(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://zip-flip.app/s/?id=short")!))
        XCTAssertNil(Links.spreadsheetID(fromZipFlipLink: URL(string: "https://zip-flip.app/s/?id=../etc")!))
    }

    func testLinkRoundTrip() {
        let link = Links.zipFlipLink(for: id)
        XCTAssertEqual(link.absoluteString, "https://zip-flip.app/s/?id=\(id)")
        XCTAssertEqual(Links.spreadsheetID(fromZipFlipLink: link), id)
    }

    func testGoogleEndpoints() {
        XCTAssertEqual(Links.htmlView(for: id).absoluteString, "https://docs.google.com/spreadsheets/d/\(id)/htmlview")
        XCTAssertEqual(Links.csvExport(for: id, gid: "1001").absoluteString, "https://docs.google.com/spreadsheets/d/\(id)/export?format=csv&gid=1001")
        XCTAssertEqual(Links.sheetPage(for: id).absoluteString, "https://docs.google.com/spreadsheets/d/\(id)/edit")
    }

    func testTabNameFromContentDisposition() {
        let google = #"attachment; filename="Zip-Fliptest-Spanish.csv"; filename*=UTF-8''Zip-Flip%20test%20-%20Spanish.csv"#
        XCTAssertEqual(Links.tabName(fromContentDisposition: google), "Spanish")
        XCTAssertEqual(Links.tabName(fromContentDisposition: #"attachment; filename*=UTF-8''Sheet%20-%20Polski%20%C5%82.csv"#), "Polski ł")
        XCTAssertEqual(Links.tabName(fromContentDisposition: #"attachment; filename="Title - Tab.csv""#), "Tab")
        XCTAssertNil(Links.tabName(fromContentDisposition: #"attachment; filename="data.csv""#))
        XCTAssertNil(Links.tabName(fromContentDisposition: "inline"))
    }
}
