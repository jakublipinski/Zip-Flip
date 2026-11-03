import XCTest
@testable import ZipFlipCore

final class CardKeyTests: XCTestCase {
    func testNormalisation() {
        XCTAssertEqual(CardKey.normalise("  Hello   World "), "hello world")
        XCTAssertEqual(CardKey.normalise("to be\n(permanent)"), "to be (permanent)")
        XCTAssertEqual(CardKey.normalise("caf\u{65}\u{301}"), "café", "decomposed input is composed")
    }

    func testEquivalentFrontsShareAKey() {
        XCTAssertEqual(CardKey.make("Dog"), CardKey.make(" dog "))
        XCTAssertEqual(CardKey.make("caf\u{E9}"), CardKey.make("cafe\u{301}"))
        XCTAssertNotEqual(CardKey.make("resume"), CardKey.make("résumé"), "accents are meaning, not noise")
        XCTAssertNotEqual(CardKey.make("dog"), CardKey.make("dogs"))
    }

    func testKeyIsSHA256Hex() {
        XCTAssertEqual(CardKey.make("hello"), "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        XCTAssertEqual(CardKey.make("hello").count, 64)
    }
}
