import Foundation
import SQLite3

public final class SQLiteStore {
    public enum StoreError: Error {
        case openFailed
        case execFailed(String)
    }

    private var db: OpaquePointer?
    private let path: String

    public init(path: String) throws {
        self.path = path
        try open()
        try migrate()
    }

    deinit { sqlite3_close(db) }

    private func open() throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw StoreError.openFailed
        }
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw StoreError.execFailed(msg)
        }
    }

    private func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS user_words(
            word TEXT PRIMARY KEY,
            count INTEGER NOT NULL,
            last_seen INTEGER NOT NULL
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS bigrams(
            prev TEXT NOT NULL,
            word TEXT NOT NULL,
            count INTEGER NOT NULL,
            PRIMARY KEY(prev, word)
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """)
    }

    // MARK: - User Words

    public func upsertUserWord(_ word: String, increment: Int = 1) throws {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
        INSERT INTO user_words(word, count, last_seen)
        VALUES (?1, ?2, ?3)
        ON CONFLICT(word) DO UPDATE SET
          count = count + excluded.count,
          last_seen = excluded.last_seen;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(increment))
        sqlite3_bind_int(stmt, 3, Int32(now))

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw StoreError.execFailed("step failed")
        }
    }

    public func getUserWordCount(_ word: String) throws -> Int {
        let sql = "SELECT count FROM user_words WHERE word = ?1 LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    public func listUserWords(limit: Int = 500) throws -> [(String, Int)] {
        let sql = "SELECT word, count FROM user_words ORDER BY last_seen DESC LIMIT ?1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var out: [(String, Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let w = String(cString: sqlite3_column_text(stmt, 0))
            let c = Int(sqlite3_column_int(stmt, 1))
            out.append((w, c))
        }
        return out
    }

    public func deleteUserWord(_ word: String) throws {
        let sql = "DELETE FROM user_words WHERE word = ?1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    public func resetAll() throws {
        try exec("DELETE FROM user_words;")
        try exec("DELETE FROM bigrams;")
        try exec("DELETE FROM settings;")
    }

    // MARK: - Bigrams

    public func upsertBigram(prev: String, word: String, increment: Int = 1) throws {
        let sql = """
        INSERT INTO bigrams(prev, word, count)
        VALUES (?1, ?2, ?3)
        ON CONFLICT(prev, word) DO UPDATE SET
          count = count + excluded.count;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, prev, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, word, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(increment))
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw StoreError.execFailed("step failed")
        }
    }

    public func topNextWords(after prev: String, limit: Int = 5) throws -> [(String, Int)] {
        let sql = "SELECT word, count FROM bigrams WHERE prev = ?1 ORDER BY count DESC LIMIT ?2;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.execFailed("prepare failed")
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, prev, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var out: [(String, Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let w = String(cString: sqlite3_column_text(stmt, 0))
            let c = Int(sqlite3_column_int(stmt, 1))
            out.append((w, c))
        }
        return out
    }
}
