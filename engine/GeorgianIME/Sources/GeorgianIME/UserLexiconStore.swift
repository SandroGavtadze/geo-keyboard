import Foundation

public final class UserLexiconStore {
    private let store: SQLiteStore
    private let trustThreshold: Int

    public init(store: SQLiteStore, trustThreshold: Int = 3) {
        self.store = store
        self.trustThreshold = trustThreshold
    }

    public func markAccepted(word: String, prev: String?) {
        do {
            try store.upsertUserWord(word, increment: 1)
            if let p = prev, !p.isEmpty {
                try store.upsertBigram(prev: p, word: word, increment: 1)
            }
        } catch {
            // swallow for keyboard safety; optionally log in host app
        }
    }

    public func isTrusted(word: String) -> Bool {
        do {
            let c = try store.getUserWordCount(word)
            return c >= trustThreshold
        } catch {
            return false
        }
    }

    public func listUserWords(limit: Int = 500) -> [(String, Int)] {
        (try? store.listUserWords(limit: limit)) ?? []
    }

    public func delete(word: String) {
        try? store.deleteUserWord(word)
    }

    public func reset() {
        try? store.resetAll()
    }

    public func topPredictions(after prev: String, limit: Int = 5) -> [(String, Int)] {
        (try? store.topNextWords(after: prev, limit: limit)) ?? []
    }
}
