//
//  StatisticsService.swift
//  KezboardSwitcher
//
//  Created by Stefan Viol on 07.03.26.
//

import Foundation
import SQLite3
import os.log

struct SwitchEvent {
    let id: Int64
    let timestamp: Date
    let keyboardName: String
    let layoutId: String
    let layoutName: String
}

struct KeyboardUsage: Identifiable {
    let keyboardName: String
    let switchCount: Int
    let percentage: Double

    var id: String { keyboardName }
}

struct DailySwitchCount: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

final class StatisticsService: Sendable {
    private let dbPath: String
    private let logger = Logger(subsystem: "de.stevio.KezboardSwitcher", category: "StatisticsService")

    init(dbPath: String? = nil) {
        if let path = dbPath {
            self.dbPath = path
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home
                .appendingPathComponent(".config")
                .appendingPathComponent("KezboardSwitcher")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.dbPath = dir.appendingPathComponent("stats.db").path
        }
        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        withDB { db in
            let sql = """
                CREATE TABLE IF NOT EXISTS switch_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp REAL NOT NULL,
                    keyboard_name TEXT NOT NULL,
                    layout_id TEXT NOT NULL,
                    layout_name TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_timestamp ON switch_events(timestamp);
                """
            var errMsg: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
            if result != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown"
                logger.error("Failed to create table: \(msg)")
                sqlite3_free(errMsg)
            }
        }
    }

    func recordSwitch(keyboardName: String, layoutId: String, layoutName: String) {
        withDB { db in
            let sql = "INSERT INTO switch_events (timestamp, keyboard_name, layout_id, layout_name) VALUES (?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, (keyboardName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (layoutId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (layoutName as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
    }

    func switchCountToday() -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var count = 0
        withDB { db in
            let sql = "SELECT COUNT(*) FROM switch_events WHERE timestamp >= ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, startOfDay)
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int64(stmt, 0))
            }
        }
        return count
    }

    func totalSwitchCount() -> Int {
        var count = 0
        withDB { db in
            let sql = "SELECT COUNT(*) FROM switch_events"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int64(stmt, 0))
            }
        }
        return count
    }

    func keyboardUsage() -> [KeyboardUsage] {
        var results: [(String, Int)] = []
        withDB { db in
            let sql = "SELECT keyboard_name, COUNT(*) as cnt FROM switch_events GROUP BY keyboard_name ORDER BY cnt DESC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
                let name = String(cString: cStr)
                let count = Int(sqlite3_column_int64(stmt, 1))
                results.append((name, count))
            }
        }

        let total = max(results.reduce(0) { $0 + $1.1 }, 1)
        return results.map { KeyboardUsage(keyboardName: $0.0, switchCount: $0.1, percentage: Double($0.1) / Double(total)) }
    }

    func dailySwitchCounts(days: Int = 7) -> [DailySwitchCount] {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(days - 1), to: Date())!)

        var results: [Date: Int] = [:]
        withDB { db in
            let sql = "SELECT timestamp FROM switch_events WHERE timestamp >= ? ORDER BY timestamp"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, startDate.timeIntervalSince1970)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let ts = sqlite3_column_double(stmt, 0)
                let date = calendar.startOfDay(for: Date(timeIntervalSince1970: ts))
                results[date, default: 0] += 1
            }
        }

        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            return DailySwitchCount(date: date, count: results[date] ?? 0)
        }
    }

    // MARK: - SQLite Helpers

    private func withDB(_ body: (OpaquePointer) -> Void) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else {
            logger.error("Failed to open database at \(self.dbPath)")
            if db != nil { sqlite3_close(db) }
            return
        }
        defer { sqlite3_close(db) }
        body(db)
    }
}
