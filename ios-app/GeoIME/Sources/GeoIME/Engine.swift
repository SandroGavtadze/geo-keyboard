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

    private let dict: CompiledDictionary?
    public var wordCount: Int { dict?.wordCount ?? 0 }

    private static let maxDFSSteps = 20_000
    private static let exactBonus = 1.5
    private static let penaltyWeight = 2.0
    private static let completionDepthCost = 0.35

    // MARK: - Init

    /// Opens a dictionary compiled by tools/build_dictionary.py. With a missing
    /// or unreadable file the engine still works, but only offers the literal
    /// transliteration.
    public init(dictionaryURL: URL?) {
        dict = dictionaryURL.flatMap(CompiledDictionary.init(contentsOf:))
    }

    /// Opens the bundled dictionary. The file is memory-mapped, so this is
    /// cheap and the trie costs no heap — keyboard extensions are jetsam-killed
    /// around ~60 MB, which an in-memory trie of the full word list approached.
    public static func loadBundled() -> Engine {
        Engine(dictionaryURL: Bundle.module.url(forResource: "ka_dictionary", withExtension: "bin"))
    }

    public func isWord(_ w: String) -> Bool {
        guard let dict, let node = dict.node(for: w) else { return false }
        return dict.freq(node) > 0
    }

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

        let lit = literal(token)
        guard let dict else { return [Suggestion(text: lit, score: -1, kind: .verbatim)] }

        let chars = Array(token)
        var results: [String: (score: Double, kind: Suggestion.Kind)] = [:]
        var reachedEnds: [(CompiledDictionary.Node, Double)] = []
        var stack: [(Int, CompiledDictionary.Node, Double)] = [(0, CompiledDictionary.root, 0)]
        var bestAt: [Int: [CompiledDictionary.Node: Double]] = [:]
        var steps = 0

        while let (pos, node, pen) = stack.popLast(), steps < Self.maxDFSSteps {
            steps += 1
            if pos == chars.count {
                reachedEnds.append((node, pen))
                continue
            }
            for opt in options(at: pos, in: chars) {
                guard let child = dict.child(of: node, opt.char) else { continue }
                let npos = pos + opt.length
                let npen = pen + opt.penalty
                if let prevPen = bestAt[npos]?[child], prevPen <= npen { continue }
                bestAt[npos, default: [:]][child] = npen
                stack.append((npos, child, npen))
            }
        }

        for (node, pen) in reachedEnds {
            let freq = dict.freq(node)
            if freq > 0 {
                let w = dict.word(at: node)
                let score = log(1 + Double(freq)) - pen * Self.penaltyWeight + Self.exactBonus
                if results[w]?.score ?? -.infinity < score { results[w] = (score, .exact) }
            }
            collectCompletions(in: dict, from: node, penalty: pen, into: &results, maxPerNode: 4)
        }

        var out = results.map { Suggestion(text: $0.key, score: $0.value.score, kind: $0.value.kind) }
            .sorted { $0.score > $1.score }
        if out.count > max { out = Array(out.prefix(max)) }

        // Verbatim literal conversion as fallback / first-class option.
        if !out.contains(where: { $0.text == lit }) {
            out.append(Suggestion(text: lit, score: -1, kind: .verbatim))
            if out.count > max { out.removeLast(out.count - max) }
        }
        return out
    }

    private func collectCompletions(
        in dict: CompiledDictionary, from node: CompiledDictionary.Node, penalty: Double,
        into results: inout [String: (score: Double, kind: Suggestion.Kind)],
        maxPerNode: Int
    ) {
        // Best-first shallow walk, mirroring the JS implementation.
        var heap: [(CompiledDictionary.Node, Int)] = [(node, 0)]
        var visited = Set<CompiledDictionary.Node>()
        var found = 0
        while !heap.isEmpty && found < maxPerNode {
            heap.sort { dict.best($0.0) > dict.best($1.0) }
            let (n, depth) = heap.removeFirst()
            if visited.contains(n) { continue }
            visited.insert(n)
            let freq = dict.freq(n)
            if freq > 0, depth > 0 {
                let w = dict.word(at: n)
                let complPenalty = penalty + Self.completionDepthCost * Double(depth)
                let score = log(1 + Double(freq)) - complPenalty * Self.penaltyWeight
                if results[w]?.score ?? -.infinity < score { results[w] = (score, .completion) }
                found += 1
            }
            if depth < 8 {
                for c in dict.children(of: n) { heap.append((c, depth + 1)) }
            }
        }
    }

    private func georgianPrefix(_ token: String, max: Int) -> [Suggestion] {
        guard let dict, let node = dict.node(for: token) else {
            return [Suggestion(text: token, score: 0, kind: .verbatim)]
        }
        var results: [String: (score: Double, kind: Suggestion.Kind)] = [:]
        if dict.freq(node) > 0 {
            results[token] = (log(1 + Double(dict.freq(node))), .exact)
        }
        collectCompletions(in: dict, from: node, penalty: 0, into: &results, maxPerNode: 6)
        var out = results.map { Suggestion(text: $0.key, score: $0.value.score, kind: $0.value.kind) }
            .sorted { $0.score > $1.score }
        if !out.contains(where: { $0.text == token }) {
            out.insert(Suggestion(text: token, score: 0, kind: .verbatim), at: 0)
        }
        return Array(out.prefix(max))
    }

    public func predictNext(after prev: String?, max: Int = 3) -> [Suggestion] {
        guard let dict, let prev, let node = dict.node(for: prev) else { return [] }
        return dict.bigrams(after: node, max: max).map {
            Suggestion(text: dict.word(at: $0.next), score: Double($0.count), kind: .prediction)
        }
    }
}

/// Read-only view over the memory-mapped dictionary file. Nodes are addressed
/// by index; node 0 is the root. Layout is documented in tools/build_dictionary.py.
final class CompiledDictionary {
    typealias Node = UInt32
    static let root: Node = 0

    private static let version: UInt32 = 1
    private static let headerSize = 24
    private static let nodeSize = 20
    private static let bigramSize = 12

    private let storage: NSData          // keeps the mapping alive
    private let base: UnsafeRawPointer
    private let nodesOffset: Int
    private let bigramsOffset: Int
    private let bigramCount: Int
    private let alphabet: [Character]
    private let charIndex: [Character: UInt8]
    let wordCount: Int

    init?(contentsOf url: URL) {
        guard let data = try? NSData(contentsOf: url, options: .alwaysMapped),
              data.length >= Self.headerSize else { return nil }
        let base = data.bytes
        func u32(_ offset: Int) -> UInt32 {
            UInt32(littleEndian: base.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
        guard u32(0) == 0x544F_4547 /* "GEOT" */, u32(4) == Self.version else { return nil }
        let alphabetCount = Int(u32(8)), nodeCount = Int(u32(12))
        let bigramCount = Int(u32(20))
        let nodesOffset = Self.headerSize + alphabetCount * 4
        let bigramsOffset = nodesOffset + nodeCount * Self.nodeSize
        guard alphabetCount <= 255, nodeCount > 0,
              data.length == bigramsOffset + bigramCount * Self.bigramSize else { return nil }

        var alphabet: [Character] = []
        for i in 0..<alphabetCount {
            guard let scalar = Unicode.Scalar(u32(Self.headerSize + i * 4)) else { return nil }
            alphabet.append(Character(scalar))
        }
        self.storage = data
        self.base = base
        self.nodesOffset = nodesOffset
        self.bigramsOffset = bigramsOffset
        self.bigramCount = bigramCount
        self.alphabet = alphabet
        self.charIndex = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, UInt8($0)) })
        self.wordCount = Int(u32(16))
    }

    // MARK: Node fields

    @inline(__always) private func u32(_ node: Node, _ field: Int) -> UInt32 {
        UInt32(littleEndian: base.loadUnaligned(fromByteOffset: nodesOffset + Int(node) * Self.nodeSize + field, as: UInt32.self))
    }
    @inline(__always) private func u8(_ node: Node, _ field: Int) -> UInt8 {
        base.load(fromByteOffset: nodesOffset + Int(node) * Self.nodeSize + field, as: UInt8.self)
    }

    /// >0 iff a word ends at this node.
    @inline(__always) func freq(_ node: Node) -> Int32 { Int32(bitPattern: u32(node, 8)) }
    /// Max word frequency in the node's subtree (for the completion walk).
    @inline(__always) func best(_ node: Node) -> Int32 { Int32(bitPattern: u32(node, 12)) }

    /// Siblings are stored contiguously, most frequent branch first.
    @inline(__always) func children(of node: Node) -> Range<Node> {
        let first = u32(node, 0)
        return first..<(first + Node(u8(node, 16)))
    }

    func child(of node: Node, _ c: Character) -> Node? {
        guard let index = charIndex[c] else { return nil }
        for child in children(of: node) where u8(child, 17) == index { return child }
        return nil
    }

    func node(for word: String) -> Node? {
        var node = Self.root
        for c in word {
            guard let next = child(of: node, c) else { return nil }
            node = next
        }
        return node
    }

    /// Rebuilds the text spelled by the path from the root to `node`.
    func word(at node: Node) -> String {
        var chars: [Character] = []
        var n = node
        while n != Self.root {
            chars.append(alphabet[Int(u8(n, 17))])
            n = u32(n, 4)
        }
        return String(chars.reversed())
    }

    // MARK: Bigrams

    private func bigram(_ i: Int) -> (prev: Node, next: Node, count: Int) {
        func field(_ f: Int) -> UInt32 {
            UInt32(littleEndian: base.loadUnaligned(fromByteOffset: bigramsOffset + i * Self.bigramSize + f, as: UInt32.self))
        }
        return (field(0), field(4), Int(field(8)))
    }

    /// Most frequent followers of the word ending at `prev`, best first.
    func bigrams(after prev: Node, max: Int) -> [(next: Node, count: Int)] {
        var lo = 0, hi = bigramCount
        while lo < hi {
            let mid = (lo + hi) / 2
            if bigram(mid).prev < prev { lo = mid + 1 } else { hi = mid }
        }
        var out: [(next: Node, count: Int)] = []
        while lo < bigramCount, out.count < max {
            let entry = bigram(lo)
            guard entry.prev == prev else { break }
            out.append((entry.next, entry.count))
            lo += 1
        }
        return out
    }
}
