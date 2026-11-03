import Foundation

/// A calendar day with no time and no zone, the unit the scheduler works in
/// (README decision 7: "days are local calendar days"). Arithmetic between
/// days uses a fixed Gregorian calendar so adding 30 days means the same thing
/// on every device; only `today(...)` consults the device's calendar.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar day that `date` falls on in `calendar` (the device's by default).
    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(calendar: Calendar = .current, now: Date = Date()) -> Day {
        Day(now, calendar: calendar)
    }

    /// Parses "YYYY-MM-DD". Anything else is nil.
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func adding(days: Int) -> Day {
        let moved = Day.calendar.date(byAdding: .day, value: days, to: noon)!
        return Day(moved, calendar: Day.calendar)
    }

    /// Number of days from `self` to `other`; negative when `other` is earlier.
    public func days(until other: Day) -> Int {
        Day.calendar.dateComponents([.day], from: noon, to: other.noon).day!
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private var noon: Date {
        Day.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
}

extension Day: Codable {
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let day = Day(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                   debugDescription: "Not a day: \(text)"))
        }
        self = day
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
