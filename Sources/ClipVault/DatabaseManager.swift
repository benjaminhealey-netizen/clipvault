import Foundation
import SQLite3

// SQLITE_TRANSIENT is a C macro not imported by Swift — define it manually
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseManager {
    private let dbPath: String
    private var db: OpaquePointer?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClipVault")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("clips.db").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database at \(dbPath)")
        }
        setupDatabase()
    }

    deinit {
        sqlite3_close(db)
    }

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let msg = errMsg {
                print("SQL error: \(String(cString: msg))")
                sqlite3_free(errMsg)
            }
        }
    }

    private func setupDatabase() {
        execute("PRAGMA journal_mode=WAL;")
        execute("""
            CREATE TABLE IF NOT EXISTS clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL UNIQUE,
                type TEXT NOT NULL DEFAULT 'text',
                created_at REAL NOT NULL,
                last_used REAL NOT NULL,
                use_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0
            );
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS snippets (
                slot INTEGER PRIMARY KEY,
                name TEXT NOT NULL DEFAULT '',
                content TEXT NOT NULL DEFAULT ''
            );
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """)
        // Default settings
        execute("INSERT OR IGNORE INTO settings (key, value) VALUES ('historyLimit', '500');")
        execute("INSERT OR IGNORE INTO settings (key, value) VALUES ('theme', 'system');")
        execute("INSERT OR IGNORE INTO settings (key, value) VALUES ('launchAtLogin', 'false');")
        // Default snippet slots
        for i in 1...9 {
            execute("INSERT OR IGNORE INTO snippets (slot, name, content) VALUES (\(i), 'Snippet \(i)', '');")
        }
        execute("CREATE INDEX IF NOT EXISTS idx_clips_last_used ON clips(last_used DESC);")
        execute("CREATE INDEX IF NOT EXISTS idx_clips_pinned ON clips(pinned DESC);")
    }

    // MARK: - Clips

    @discardableResult
    func addClip(content: String, type: ClipType) -> Int64 {
        let now = Date().timeIntervalSince1970
        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO clips (content, type, created_at, last_used, use_count, pinned)
            VALUES (?, ?, ?, ?, 1, 0)
            ON CONFLICT(content) DO UPDATE SET
                last_used = excluded.last_used,
                use_count = use_count + 1;
        """
        var lastId: Int64 = -1
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, now)
            sqlite3_bind_double(stmt, 4, now)
            if sqlite3_step(stmt) == SQLITE_DONE {
                lastId = sqlite3_last_insert_rowid(db)
            }
        }
        sqlite3_finalize(stmt)
        return lastId
    }

    func getClips(search: String? = nil, limit: Int = 200, offset: Int = 0) -> [Clip] {
        var clips: [Clip] = []
        var stmt: OpaquePointer?
        let sql: String

        if let search = search, !search.isEmpty {
            sql = """
                SELECT id, content, type, created_at, last_used, use_count, pinned
                FROM clips
                WHERE content LIKE ?
                ORDER BY pinned DESC, last_used DESC
                LIMIT ? OFFSET ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_text(stmt, 1, "%\(search)%", -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            sqlite3_bind_int(stmt, 3, Int32(offset))
        } else {
            sql = """
                SELECT id, content, type, created_at, last_used, use_count, pinned
                FROM clips
                ORDER BY pinned DESC, last_used DESC
                LIMIT ? OFFSET ?;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int(stmt, 1, Int32(limit))
            sqlite3_bind_int(stmt, 2, Int32(offset))
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let content = String(cString: sqlite3_column_text(stmt, 1))
            let typeStr = String(cString: sqlite3_column_text(stmt, 2))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            let lastUsed = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let useCount = Int(sqlite3_column_int(stmt, 5))
            let pinned = sqlite3_column_int(stmt, 6) != 0
            let clipType = ClipType(rawValue: typeStr) ?? .text
            clips.append(Clip(id: id, content: content, type: clipType,
                             createdAt: createdAt, lastUsed: lastUsed,
                             useCount: useCount, isPinned: pinned))
        }
        sqlite3_finalize(stmt)
        return clips
    }

    func deleteClip(id: Int64) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM clips WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func pinClip(id: Int64, pinned: Bool) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "UPDATE clips SET pinned = ? WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
            sqlite3_bind_int64(stmt, 2, id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func updateUsage(id: Int64) {
        var stmt: OpaquePointer?
        let sql = "UPDATE clips SET last_used = ?, use_count = use_count + 1 WHERE id = ?;"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 2, id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func clearHistory() {
        execute("DELETE FROM clips WHERE pinned = 0;")
    }

    // MARK: - Snippets

    func getSnippets() -> [Snippet] {
        var snippets: [Snippet] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT slot, name, content FROM snippets ORDER BY slot;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let slot = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let content = String(cString: sqlite3_column_text(stmt, 2))
                snippets.append(Snippet(slot: slot, name: name, content: content))
            }
        }
        sqlite3_finalize(stmt)
        return snippets
    }

    func saveSnippet(slot: Int, name: String, content: String) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO snippets (slot, name, content) VALUES (?, ?, ?);"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(slot))
            sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, content, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Settings

    func getSetting(_ key: String) -> String? {
        var stmt: OpaquePointer?
        var value: String?
        if sqlite3_prepare_v2(db, "SELECT value FROM settings WHERE key = ?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                value = String(cString: sqlite3_column_text(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return value
    }

    func setSetting(_ key: String, value: String) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?);"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, value, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
}
