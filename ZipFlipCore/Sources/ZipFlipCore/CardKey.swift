import CryptoKit
import Foundation

/// The identity of a card (README decision 14): SHA-256 of the front text
/// after Unicode NFC normalisation, trimming, collapsing inner whitespace and
/// case folding. Fixing a typo in the answer keeps the progress; rewriting the
/// question starts it fresh.
public enum CardKey {
    public static func make(_ front: String) -> String {
        let digest = SHA256.hash(data: Data(normalise(front).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The text that gets hashed; exposed for tests and debugging.
    public static func normalise(_ front: String) -> String {
        let composed = front.precomposedStringWithCanonicalMapping
        let collapsed = composed
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        return collapsed.folding(options: [.caseInsensitive], locale: nil)
    }
}
