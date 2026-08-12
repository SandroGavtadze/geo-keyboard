import Foundation

public final class Tokenizer {
    public init() {}

    /// Extract the current token and previous token from limited context.
    /// - Parameters:
    ///   - before: text before caret (may be truncated by iOS)
    /// - Returns: TokenContext (prev token optional, current token possibly empty)
    public func extract(fromBeforeCaret before: String) -> TokenContext {
        // Split on whitespace; keep only recent portion.
        let trimmed = before.suffix(200)
        let s = String(trimmed)

        // Identify current token: trailing letters/digits in Georgian/Latin.
        let current = trailingToken(in: s)

        // Remove current token, then find previous.
        let remainder = String(s.dropLast(current.count))
        let prev = trailingToken(in: remainder.trimmingCharacters(in: .whitespacesAndNewlines))

        return TokenContext(prevToken: prev.isEmpty ? nil : prev, currentToken: current)
    }

    private func trailingToken(in s: String) -> String {
        if s.isEmpty { return "" }
        // Accept Georgian Mkhedruli + Mtavruli + Latin + digits.
        let allowed = CharacterSet(charactersIn:
            "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ" +
            "ႠႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿ" +
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        )

        var tokenScalars: [UnicodeScalar] = []
        for scalar in s.unicodeScalars.reversed() {
            if allowed.contains(scalar) {
                tokenScalars.append(scalar)
            } else {
                break
            }
        }
        return String(String.UnicodeScalarView(tokenScalars.reversed()))
    }
}
