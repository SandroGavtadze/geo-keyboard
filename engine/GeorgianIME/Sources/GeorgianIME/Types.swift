import Foundation

public struct Suggestion: Hashable {
    public let text: String
    public let score: Double
    public let kind: Kind

    public enum Kind: String {
        case verbatim
        case correction
        case prediction
        case userWord
    }

    public init(text: String, score: Double, kind: Kind) {
        self.text = text
        self.score = score
        self.kind = kind
    }
}

public struct TokenContext: Equatable {
    public let prevToken: String?
    public let currentToken: String
    public init(prevToken: String?, currentToken: String) {
        self.prevToken = prevToken
        self.currentToken = currentToken
    }
}
