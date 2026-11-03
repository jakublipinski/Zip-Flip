import XCTest
@testable import ZipFlipCore

final class SchedulerTests: XCTestCase {
    let today = Day("2026-11-02")!

    func testNewCardGotItLandsOnRungOneDueTomorrow() {
        var rng = MaxRNG()
        let p = Scheduler.apply(.gotIt, to: nil, today: today, using: &rng)
        XCTAssertEqual(p, CardProgress(level: 1, due: today.adding(days: 1), reviews: 1, lapses: 0,
                                       introduced: today, lastReviewed: today))
    }

    func testNewCardAgainStaysDueTodayAndIsNotALapse() {
        var rng = MaxRNG()
        let p = Scheduler.apply(.again, to: nil, today: today, using: &rng)
        XCTAssertEqual(p.level, 0)
        XCTAssertEqual(p.due, today)
        XCTAssertEqual(p.lapses, 0)
        XCTAssertEqual(p.reviews, 1)
    }

    func testAgainOnALearnedCardIsALapseBackToTheBottom() {
        var rng = MaxRNG()
        let learned = CardProgress(level: 5, due: today, reviews: 5, lapses: 0,
                                   introduced: today.adding(days: -40), lastReviewed: today.adding(days: -16))
        let p = Scheduler.apply(.again, to: learned, today: today, using: &rng)
        XCTAssertEqual(p.level, 0)
        XCTAssertEqual(p.due, today)
        XCTAssertEqual(p.lapses, 1)
        XCTAssertEqual(p.reviews, 6)
        XCTAssertEqual(p.introduced, learned.introduced)
        XCTAssertEqual(p.lastReviewed, today)
    }

    func testTheLadderWithMaximumJitter() {
        var rng = MaxRNG()
        var p: CardProgress? = nil
        var day = today
        var gaps: [Int] = []
        for _ in 0..<9 {
            let next = Scheduler.apply(.gotIt, to: p, today: day, using: &rng)
            gaps.append(day.days(until: next.due))
            day = next.due
            p = next
        }
        XCTAssertEqual(gaps, [1, 2, 4, 8, 17, 35, 70, 140, 140],
                       "1, 2, 4, 8 are exact; from 16 up to ten percent extra; the top rung repeats")
        XCTAssertEqual(p?.level, 8)
    }

    func testJitterStaysWithinTenPercentAndNeverShrinks() {
        var rng = SeededRNG(seed: 7)
        for level in 1...8 {
            let gap = Scheduler.gap(forLevel: level)
            let before = CardProgress(level: level - 1, due: today, reviews: 1, lapses: 0, introduced: today, lastReviewed: today)
            var seen = Set<Int>()
            for _ in 0..<300 {
                let p = Scheduler.apply(.gotIt, to: before, today: today, using: &rng)
                let actual = today.days(until: p.due)
                XCTAssertGreaterThanOrEqual(actual, gap)
                XCTAssertLessThanOrEqual(actual, gap + gap / 10)
                seen.insert(actual)
            }
            if gap >= 16 {
                XCTAssertGreaterThan(seen.count, 1, "level \(level) should spread")
            } else {
                XCTAssertEqual(seen, [gap], "level \(level) is exact")
            }
        }
    }

    func testMaxJitterRule() {
        XCTAssertEqual(Scheduler.maxJitter(forGap: 1), 0)
        XCTAssertEqual(Scheduler.maxJitter(forGap: 2), 0)
        XCTAssertEqual(Scheduler.maxJitter(forGap: 4), 0)
        XCTAssertEqual(Scheduler.maxJitter(forGap: 8), 0)
        XCTAssertEqual(Scheduler.maxJitter(forGap: 16), 1)
        XCTAssertEqual(Scheduler.maxJitter(forGap: 128), 12)
    }
}
