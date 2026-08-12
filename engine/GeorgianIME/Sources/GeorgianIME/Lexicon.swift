import Foundation

public final class Lexicon {
    private var words: [String] = []
    private var wordSet: Set<String> = []

    public init() {}

    public func loadBundledWordList() {
        guard let url = Bundle.module.url(forResource: "ka_wordlist", withExtension: "txt") else {
            return
        }
        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let lines = raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            let cleaned = lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            self.words = cleaned.sorted()
            self.wordSet = Set(cleaned)
        } catch {
            // leave empty
        }
    }

    public func contains(_ word: String) -> Bool {
        if word.isEmpty { return true }
        return wordSet.contains(word)
    }
}
