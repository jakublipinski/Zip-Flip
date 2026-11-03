import XCTest
@testable import ZipFlipCore

final class DayTests: XCTestCase {
    func testParseAndPrint() {
        XCTAssertEqual(Day("2026-11-02"), Day(year: 2026, month: 11, day: 2))
        XCTAssertEqual(Day(year: 2026, month: 1, day: 5).description, "2026-01-05")
        XCTAssertNil(Day("2026-13-01"))
        XCTAssertNil(Day("yesterday"))
    }

    func testArithmeticAcrossMonthsAndLeapYears() {
        XCTAssertEqual(Day("2026-11-02")!.adding(days: 30), Day("2026-12-02"))
        XCTAssertEqual(Day("2026-01-31")!.adding(days: 1), Day("2026-02-01"))
        XCTAssertEqual(Day("2028-02-28")!.adding(days: 1), Day("2028-02-29"))
        XCTAssertEqual(Day("2026-12-31")!.adding(days: 128), Day("2027-05-08"))
        XCTAssertEqual(Day("2026-11-02")!.days(until: Day("2026-12-02")!), 30)
        XCTAssertEqual(Day("2026-11-02")!.days(until: Day("2026-11-01")!), -1)
    }

    func testOrdering() {
        XCTAssertLessThan(Day("2026-11-02")!, Day("2026-11-03")!)
        XCTAssertLessThan(Day("2025-12-31")!, Day("2026-01-01")!)
    }

    func testCodableAsString() throws {
        let data = try JSONEncoder().encode([Day("2026-11-02")!])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"["2026-11-02"]"#)
        XCTAssertEqual(try JSONDecoder().decode([Day].self, from: data), [Day("2026-11-02")!])
        XCTAssertThrowsError(try JSONDecoder().decode([Day].self, from: Data(#"["soon"]"#.utf8)))
    }

    func testTodayUsesTheGivenCalendar() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!   // UTC+14
        let instant = Date(timeIntervalSince1970: 1_793_577_600)      // 2026-11-02 00:00 UTC
        XCTAssertEqual(Day.today(calendar: cal, now: instant), Day("2026-11-02"))
        cal.timeZone = TimeZone(identifier: "Pacific/Honolulu")!     // UTC-10
        XCTAssertEqual(Day.today(calendar: cal, now: instant), Day("2026-11-01"))
    }
}
