import Foundation
import XCTest
@testable import ZipFlipCore

/// Files captured from the project's test sheet on 2026-11-02:
/// tab-<gid>.csv is Google's CSV export of each tab (1003 is the hidden one,
/// 1004 the empty one) and htmlview.html is the spreadsheet's HTML view.
enum Fixtures {
    static func text(_ name: String) throws -> String {
        let parts = name.split(separator: ".")
        guard let url = Bundle.module.url(forResource: String(parts[0]), withExtension: String(parts[1]), subdirectory: "Fixtures") else {
            throw XCTSkip("fixture \(name) missing")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// A generator that always answers with the largest value, so every
/// `Int.random(in:)` picks the top of its range.
struct MaxRNG: RandomNumberGenerator {
    mutating func next() -> UInt64 { .max }
}

/// SplitMix64, for repeatable spreads.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
