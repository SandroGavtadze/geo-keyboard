import Foundation

/// Optional: define adjacency substitutions based on Georgian key neighbors.
/// This improves candidate generation by prioritizing plausible typos.
public struct KeyboardAdjacency {
    public init() {}

    public func neighbors(for ch: Character) -> [Character] {
        // TODO: populate based on the actual layout geometry.
        // Return empty for now (MVP still works with generic edits).
        return []
    }
}
