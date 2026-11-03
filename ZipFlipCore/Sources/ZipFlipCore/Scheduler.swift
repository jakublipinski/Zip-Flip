import Foundation

/// The doubling ladder (README decision 7), as a pure function of the card's
/// progress, the answer, today and a random source.
///
/// Level 0 is a card not yet learned or just forgotten. Got it moves the card
/// up one rung and the rung sets the gap in days; Again sends it back to 0 and
/// leaves it due today, so the session shows it again. A new card that gets
/// Got it on first sight lands on rung 1, due tomorrow. Gaps of four days or
/// more get up to ten percent of random extra so reviews do not pile up.
public enum Scheduler {
    /// Gap in days for levels 1 to 8.
    public static let ladder = [1, 2, 4, 8, 16, 32, 64, 128]
    public static var maxLevel: Int { ladder.count }
    /// Gaps from this length up are jittered.
    public static let jitterFrom = 4

    public static func gap(forLevel level: Int) -> Int {
        precondition((1...maxLevel).contains(level), "level out of range")
        return ladder[level - 1]
    }

    /// The most extra days a gap can receive: ten percent, rounded down.
    public static func maxJitter(forGap gap: Int) -> Int {
        gap >= jitterFrom ? gap / 10 : 0
    }

    public static func apply(
        _ answer: Answer,
        to current: CardProgress?,
        today: Day,
        using rng: inout some RandomNumberGenerator
    ) -> CardProgress {
        var p = current ?? CardProgress(level: 0, due: today, reviews: 0, lapses: 0,
                                        introduced: today, lastReviewed: today)
        p.reviews += 1
        p.lastReviewed = today
        switch answer {
        case .again:
            if p.level > 0 { p.lapses += 1 }
            p.level = 0
            p.due = today
        case .gotIt:
            p.level = min(p.level + 1, maxLevel)
            let gap = Scheduler.gap(forLevel: p.level)
            let extra = maxJitter(forGap: gap)
            let jitter = extra > 0 ? Int.random(in: 0...extra, using: &rng) : 0
            p.due = today.adding(days: gap + jitter)
        }
        return p
    }

    public static func apply(_ answer: Answer, to current: CardProgress?, today: Day) -> CardProgress {
        var rng = SystemRandomNumberGenerator()
        return apply(answer, to: current, today: today, using: &rng)
    }
}
