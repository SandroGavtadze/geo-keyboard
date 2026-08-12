import Foundation

public final class SuggestionEngine {
    private let lexicon: Lexicon
    private let generator: CandidateGenerator
    private let userStore: UserLexiconStore
    private let alphabet: [Character]

    // Cache last token -> suggestions
    private var lastToken: String = ""
    private var lastPrev: String? = nil
    private var lastSuggestions: [Suggestion] = []

    public init(lexicon: Lexicon, generator: CandidateGenerator, userStore: UserLexiconStore) {
        self.lexicon = lexicon
        self.generator = generator
        self.userStore = userStore
        self.alphabet = Array("აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ")
    }

    public func suggest(token: String, prevToken: String?, max: Int = 3) -> [Suggestion] {
        // Cache
        if token == lastToken && prevToken == lastPrev {
            return Array(lastSuggestions.prefix(max))
        }

        var out: [Suggestion] = []

        let normalized = token // future: lowercase/normalize

        // If token empty, offer predictions based on prev token
        if normalized.isEmpty, let prev = prevToken, !prev.isEmpty {
            let preds = userStore.topPredictions(after: prev, limit: max)
            out = preds.map { Suggestion(text: $0.0, score: Double($0.1), kind: .prediction) }
            lastToken = token; lastPrev = prevToken; lastSuggestions = out
            return out
        }

        // Always include verbatim
        out.append(Suggestion(text: normalized, score: 0, kind: .verbatim))

        // If correct or trusted, don't autocorrect; optionally show predictions
        if lexicon.contains(normalized) || userStore.isTrusted(word: normalized) {
            lastToken = token; lastPrev = prevToken; lastSuggestions = out
            return out
        }

        // Generate candidates (edits1)
        let candidates = generator.edits1(normalized, alphabet: alphabet)

        // Filter to lexicon or trusted user words
        var scored: [(String, Double, Suggestion.Kind)] = []
        scored.reserveCapacity(50)

        for c in candidates {
            if lexicon.contains(c) || userStore.isTrusted(word: c) {
                let freq = Double((try? userStore.listUserWords().first(where: { $0.0 == c })?.1) ?? 0)
                // Basic score: distance=1 => base, + user freq boost
                let score = 100.0 + freq
                let kind: Suggestion.Kind = userStore.isTrusted(word: c) ? .userWord : .correction
                scored.append((c, score, kind))
            }
        }

        // Dedup by best score
        var best: [String: (Double, Suggestion.Kind)] = [:]
        for (w, s, k) in scored {
            if let existing = best[w] {
                if s > existing.0 { best[w] = (s, k) }
            } else {
                best[w] = (s, k)
            }
        }

        let ranked = best
            .map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.1 > $1.1 }
            .prefix(max)

        for (w, s, k) in ranked {
            out.append(Suggestion(text: w, score: s, kind: k))
        }

        lastToken = token
        lastPrev = prevToken
        lastSuggestions = out
        return out
    }

    public func learnAccepted(word: String, prevToken: String?) {
        userStore.markAccepted(word: word, prev: prevToken)
    }
}
