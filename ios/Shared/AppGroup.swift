import Foundation

enum AppGroup {
    // Update to your actual app group identifier.
    static let id = "group.com.yourcompany.georgiankeyboard"

    static func containerURL() -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            // Fallback for simulator/dev; should not happen if App Group enabled.
            return FileManager.default.temporaryDirectory
        }
        return url
    }

    static func sqlitePath(filename: String = "userdict.sqlite3") -> String {
        containerURL().appendingPathComponent(filename).path
    }
}
