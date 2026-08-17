import Foundation

/// A suggestion produced by the engine.
public struct Suggestion: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case exact       // full dictionary word matching all typed input
        case completion  // dictionary word extending the typed prefix
        case verbatim    // literal letter-by-letter transliteration (may not be a word)
        case prediction  // next-word prediction from bigrams
    }
    public let text: String
    public let score: Double
    public let kind: Kind
}

/// Latin → Georgian transliteration engine (pinyin-style IME).
/// Direct port of engine/translit.js — the JS file is the reference implementation;
/// EngineTests mirrors the JS test harness to keep the two in lockstep.
public final class Engine {

    /// Memory-lean trie node. Keyboard extensions are jetsam-killed around
    /// ~60 MB; a [Character: TrieNode] Dictionary per node blew that budget
    /// (the extension died seconds after launch in Simulator testing), so
    /// children live in a compact array — average branching factor is small,
    /// linear scan is fast.
    final class TrieNode {
        var children: ContiguousArray<(Character, TrieNode)> = []
        var freq: Int32 = 0        // >0 iff a word ends here
        var best: Int32 = 0        // max word freq in subtree (for completion walk)
        var word: String? = nil    // full word, terminal nodes only

        @inline(__always) func child(_ c: Character) -> TrieNode? {
            for (ch, n) in children where ch == c { return n }
            return nil
        }
    }

    private let root = TrieNode()
    private var freqs: [String: Int] = [:]
    private var bigrams: [String: [(String, Int)]] = [:]
    public private(set) var wordCount = 0

    private static let maxDFSSteps = 20_000
    private static let exactBonus = 1.5
    private static let penaltyWeight = 2.0
    private static let completionDepthCost = 0.35

    // MARK: - Init

    public init(words: [(String, Int)], bigrams: [(String, String, Int)] = []) {
        for (w, f) in words { insert(w, freq: f) }
        wordCount = words.count
        var bg: [String: [(String, Int)]] = [:]
        for (a, b, c) in bigrams { bg[a, default: []].append((b, c)) }
        for (k, v) in bg { self.bigrams[k] = v.sorted { $0.1 > $1.1 } }
    }

    /// Word cap for the bundled dictionary — memory guardrail for the
    /// extension process. Top-30k covers everyday vocabulary; raise once the
    /// trie is a precompiled binary blob.
    public static var bundledWordLimit = 30_000

    /// Loads the bundled frequency list + bigrams.
    /// Parsing takes ~100–300 ms on device; call off the main thread.
    public static func loadBundled() -> Engine {
        func rows(_ name: String) -> [[Substring]] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "tsv"),
                  let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return raw.split(separator: "\n").map { $0.split(separator: "\t") }
        }
        var words: [(String, Int)] = rows("ka_words_freq").compactMap {
            guard $0.count == 2, let f = Int($0[1]) else { return nil }
            return (String($0[0]), f)
        }
        if words.count > bundledWordLimit { words = Array(words.prefix(bundledWordLimit)) }
        let bigrams: [(String, String, Int)] = rows("ka_bigrams").compactMap {
            guard $0.count == 3, let c = Int($0[2]) else { return nil }
            return (String($0[0]), String($0[1]), c)
        }
        return Engine(words: words, bigrams: bigrams)
    }

    private func insert(_ word: String, freq: Int) {
        let f = Int32(clamping: freq)
        var node = root
        for ch in word {
            if node.best < f { node.best = f }
            if let next = node.child(ch) {
                node = next
            } else {
                let next = TrieNode()
                node.children.append((ch, next))
                node = next
            }
        }
        if node.best < f { node.best = f }
        node.freq = f
        node.word = word
        freqs[word] = freq
    }

    public func isWord(_ w: String) -> Bool { freqs[w] != nil }

    // MARK: - Literal transliteration

    /// Best-effort greedy conversion; used for the verbatim candidate so
    /// out-of-vocabulary words (names, slang) still convert.
    public func literal(_ latin: String) -> String {
        var out = ""
        let chars = Array(latin)
        var i = 0
        while i < chars.count {
            var matched = false
            for len in stride(from: Mappings.maxSequenceLength, through: 1, by: -1) {
                guard i + len <= chars.count else { continue }
                let rawSeq = String(chars[i..<i+len])
                if len == 1, let opts = Mappings.caseSensitive[rawSeq], let first = opts.first {
                    out.append(first.0); i += 1; matched = true; break
                }
                if let opts = Mappings.lower[rawSeq.lowercased()], let first = opts.first {
                    out.append(first.0); i += len; matched = true; break
                }
            }
            if !matched { out.append(chars[i]); i += 1 }
        }
        return out
    }

    // MARK: - Suggestions

    private struct Option { let length: Int; let char: Character; let penalty: Double }

    private func options(at i: Int, in chars: [Character]) -> [Option] {
        var seen: [String: Option] = [:]
        let maxLen = min(Mappings.maxSequenceLength, chars.count - i)
        for len in stride(from: maxLen, through: 1, by: -1) {
            let raw = String(chars[i..<i+len])
            if len == 1 {
                if let opts = Mappings.caseSensitive[raw] {
                    for (g, p) in opts { mergeOption(&seen, Option(length: 1, char: g, penalty: p)) }
                }
                if let opts = Mappings.lower[raw.lowercased()] {
                    for (g, p) in opts { mergeOption(&seen, Option(length: 1, char: g, penalty: p)) }
                }
            } else if let opts = Mappings.lower[raw.lowercased()] {
                for (g, p) in opts { mergeOption(&seen, Option(length: len, char: g, penalty: p)) }
            }
        }
        return Array(seen.values)
    }

    private func mergeOption(_ seen: inout [String: Option], _ o: Option) {
        let key = "\(o.length)\(o.char)"
        if let existing = seen[key], existing.penalty <= o.penalty { return }
        seen[key] = o
    }

    /// Main entry: suggestions for a Latin (or Georgian) token.
    public func suggest(_ token: String, max: Int = 5, prev: String? = nil) -> [Suggestion] {
        if token.isEmpty { return predictNext(after: prev, max: max) }

        // Georgian input → prefix/completion mode.
        if token.allSatisfy({ ("ა"..."ჰ").contains($0) }) {
            return georgianPrefix(token, max: max)
        }

        let chars = Array(token)
        var results: [String: (score: Double, kind: Suggestion.Kind)] = [:]
        var reachedEnds: [(TrieNode, Double)] = []
        var stack: [(Int, TrieNode, Double)] = [(0, root, 0)]
        var bestAt: [Int: [ObjectIdentifier: Double]] = [:]
        var steps = 0

        while let (pos, node, pen) = stack.popLast(), steps < Self.maxDFSSteps {
            steps += 1
            if pos == chars.count {
                reachedEnds.append((node, pen))
                continue
            }
            for opt in options(at: pos, in: chars) {
                guard let child = node.child(opt.char) else { continue }
                let npos = pos + opt.length
                let npen = pen + opt.penalty
                let id = ObjectIdentifier(child)
                if let prevPen = bestAt[npos]?[id], prevPen <= npen { continue }
                bestAt[npos, default: [:]][id] = npen
                stack.append((npos, child, npen))
            }
        }

        for (node, pen) in reachedEnds {
            if node.freq > 0, let w = node.word {
                let score = log(1 + Double(node.freq)) - pen * Self.penaltyWeight + Self.exactBonus
                if results[w]?.score ?? -.infinity < score { results[w] = (score, .exact) }
            }
            collectCompletions(from: node, penalty: pen, into: &results, maxPerNode: 4)
        }

        var out = results.map { Suggestion(text: $0.key, score: $0.value.score, kind: $0.value.kind) }
            .sorted { $0.score > $1.score }
        if out.count > max { out = Array(out.prefix(max)) }

        // Verbatim literal conversion as fallback / first-class option.
        let lit = literal(token)
        if !out.contains(where: { $0.text == lit }) {
            out.append(Suggestion(text: lit, score: -1, kind: .verbatim))
            if out.count > max { out.removeLast(out.count - max) }
        }
        return out
    }

    private func collectCompletions(
        from node: TrieNode, penalty: Double,
        into results: inout [String: (score: Double, kind: Suggestion.Kind)],
        maxPerNode: Int
    ) {
        // Best-first shallow walk, mirroring the JS implementation.
        var heap: [(TrieNode, Int)] = [(node, 0)]
        var visited = Set<ObjectIdentifier>()
        var found = 0
        while !heap.isEmpty && found < maxPerNode {
            heap.sort { $0.0.best > $1.0.best }
            let (n, depth) = heap.removeFirst()
            let id = ObjectIdentifier(n)
            if visited.contains(id) { continue }
            visited.insert(id)
            if n.freq > 0, depth > 0, let w = n.word {
                let complPenalty = penalty + Self.completionDepthCost * Double(depth)
                let score = log(1 + Double(n.freq)) - complPenalty * Self.penaltyWeight
                if results[w]?.score ?? -.infinity < score { results[w] = (score, .completion) }
                found += 1
            }
            if depth < 8 {
                for (_, c) in n.children { heap.append((c, depth + 1)) }
            }
        }
    }

    private func georgianPrefix(_ token: String, max: Int) -> [Suggestion] {
        var node = root
        for ch in token {
            guard let next = node.child(ch) else {
                return [Suggestion(text: token, score: 0, kind: .verbatim)]
            }
            node = next
        }
        var results: [String: (score: Double, kind: Suggestion.Kind)] = [:]
        if node.freq > 0 {
            results[token] = (log(1 + Double(node.freq)), .exact)
        }
        collectCompletions(from: node, penalty: 0, into: &results, maxPerNode: 6)
        var out = results.map { Suggestion(text: $0.key, score: $0.value.score, kind: $0.value.kind) }
            .sorted { $0.score > $1.score }
        if !out.contains(where: { $0.text == token }) {
            out.insert(Suggestion(text: token, score: 0, kind: .verbatim), at: 0)
        }
        return Array(out.prefix(max))
    }

    public func predictNext(after prev: String?, max: Int = 3) -> [Suggestion] {
        guard let prev, let list = bigrams[prev] else { return [] }
        return list.prefix(max).map { Suggestion(text: $0.0, score: Double($0.1), kind: .prediction) }
    }
}
