import Foundation
import SQLite

// MARK: - Notification Names

extension Notification.Name {
    static let sessionDataDidUpdate = Notification.Name("sessionDataDidUpdate")
}

final class SessionStore {
    private let db: Connection
    private let sessions = Table("sessions")

    // Columns
    private let id = Expression<Int64>("id")
    private let bundleId = Expression<String>("bundle_id")
    private let appName = Expression<String>("app_name")
    private let windowTitle = Expression<String?>("window_title")
    private let startAt = Expression<Double>("start_at")
    private let endAt = Expression<Double>("end_at")
    private let durationSec = Expression<Double>("duration_sec")
    private let createdAt = Expression<Double>("created_at")
    private let updatedAt = Expression<Double>("updated_at")

    private let queue = DispatchQueue(label: "com.mactime.sessionstore")

    init() {
        let url = SessionStore.databaseURL()
        do {
            db = try Connection(url.path)
            try createTableIfNeeded()
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }

    func appendSession(appName: String, bundleId: String, windowTitle: String?, start: Date, end: Date) {
        queue.async {
            let now = Date().timeIntervalSince1970
            let duration = end.timeIntervalSince(start)
            let insert = self.sessions.insert(
                self.bundleId <- bundleId,
                self.appName <- appName,
                self.windowTitle <- windowTitle,
                self.startAt <- start.timeIntervalSince1970,
                self.endAt <- end.timeIntervalSince1970,
                self.durationSec <- duration,
                self.createdAt <- now,
                self.updatedAt <- now
            )
            do {
                try self.db.run(insert)
                self.notifyUpdate()
            } catch {
                print("Failed to insert session: \(error)")
            }
        }
    }

    func fetchSessions(for date: Date, completion: @escaping ([Session]) -> Void) {
        queue.async {
            let dayStart = Calendar.current.startOfDay(for: date)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
                completion([])
                return
            }

            let lower = dayStart.timeIntervalSince1970
            let upper = dayEnd.timeIntervalSince1970

            let query = self.sessions
                .filter(self.endAt > lower && self.startAt < upper)
                .order(self.startAt.asc)

            var results: [Session] = []
            do {
                for row in try self.db.prepare(query) {
                    let session = Session(
                        id: row[self.id],
                        bundleId: row[self.bundleId],
                        appName: row[self.appName],
                        windowTitle: row[self.windowTitle],
                        startAt: Date(timeIntervalSince1970: row[self.startAt]),
                        endAt: Date(timeIntervalSince1970: row[self.endAt]),
                        duration: row[self.durationSec]
                    )
                    results.append(session)
                }
                completion(results)
            } catch {
                print("Failed to fetch sessions: \(error)")
                completion([])
            }
        }
    }

    func deleteSession(id: Int64) {
        queue.async {
            let target = self.sessions.filter(self.id == id)
            do {
                try self.db.run(target.delete())
                self.notifyUpdate()
            } catch {
                print("Failed to delete session: \(error)")
            }
        }
    }

    func updateSession(id: Int64, appName: String, bundleId: String, start: Date, end: Date) {
        queue.async {
            let target = self.sessions.filter(self.id == id)
            let now = Date().timeIntervalSince1970
            let duration = end.timeIntervalSince(start)
            let update = target.update(
                self.appName <- appName,
                self.bundleId <- bundleId,
                self.startAt <- start.timeIntervalSince1970,
                self.endAt <- end.timeIntervalSince1970,
                self.durationSec <- duration,
                self.updatedAt <- now
            )
            do {
                try self.db.run(update)
                self.notifyUpdate()
            } catch {
                print("Failed to update session: \(error)")
            }
        }
    }

    // MARK: - Private helpers
    
    private func notifyUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sessionDataDidUpdate, object: nil)
        }
    }
}

// MARK: - Private helpers

private extension SessionStore {
    static func databaseURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MacTime", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("records.db")
    }

    func createTableIfNeeded() throws {
        try db.run(sessions.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(bundleId)
            t.column(appName)
            t.column(windowTitle)
            t.column(startAt)
            t.column(endAt)
            t.column(durationSec)
            t.column(createdAt)
            t.column(updatedAt)
        })
        try db.run(sessions.createIndex(startAt, ifNotExists: true))
        try db.run(sessions.createIndex(bundleId, ifNotExists: true))
    }
}
