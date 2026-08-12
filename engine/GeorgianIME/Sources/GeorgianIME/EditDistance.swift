import Foundation

public enum EditOp {
    case insert(Character)
    case delete
    case substitute(Character)
    case transpose
}

public final class CandidateGenerator {
    private let adjacency: KeyboardAdjacency
    private let maxCandidates: Int

    public init(adjacency: KeyboardAdjacency = .init(), maxCandidates: Int = 200) {
        self.adjacency = adjacency
        self.maxCandidates = maxCandidates
    }

    /// Generate candidates at edit distance 1 (bounded).
    public func edits1(_ word: String, alphabet: [Character]) -> [String] {
        if word.isEmpty { return [] }
        var out: [String] = []
        out.reserveCapacity(min(maxCandidates, 200))

        let chars = Array(word)
        let n = chars.count

        func push(_ s: String) {
            if out.count < maxCandidates { out.append(s) }
        }

        // Deletes
        for i in 0..<n {
            var tmp = chars
            tmp.remove(at: i)
            push(String(tmp))
            if out.count >= maxCandidates { return out }
        }

        // Transposes
        if n >= 2 {
            for i in 0..<(n-1) {
                var tmp = chars
                tmp.swapAt(i, i+1)
                push(String(tmp))
                if out.count >= maxCandidates { return out }
            }
        }

        // Substitutions (alphabet + adjacency neighbors)
        for i in 0..<n {
            let base = chars[i]
            let neigh = adjacency.neighbors(for: base)
            let subs = neigh.isEmpty ? alphabet : Array(Set(neigh + alphabet))
            for c in subs {
                if c == base { continue }
                var tmp = chars
                tmp[i] = c
                push(String(tmp))
                if out.count >= maxCandidates { return out }
            }
        }

        // Inserts
        for i in 0...n {
            for c in alphabet {
                var tmp = chars
                tmp.insert(c, at: i)
                push(String(tmp))
                if out.count >= maxCandidates { return out }
            }
        }

        return out
    }
}
