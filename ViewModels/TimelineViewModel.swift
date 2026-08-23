import Foundation
import SwiftUI
import Combine
import AppKit

final class TimelineViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var highlightedBundleId: String?
    @Published private(set) var sessions: [Session]
    @Published private(set) var mergedBlocks: [SessionBlock]

    private let sessionStore: SessionStore
    private let maxInterruptionDuration: TimeInterval = 300
    private let maxBridgeGap: TimeInterval = 600
    private let minimumBlockDuration: TimeInterval = 30

    private var assignedColors: [String: Color] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Material Design 500 colors
    static let palette: [Color] = [
        Color(hex: "58AAF8"), // Timemator Blue
        Color(hex: "908AF7"), // Timemator Purple
        Color(hex: "F0975B"), // Timemator Organge
        Color(hex: "74FBFC"), // Timemator Green
        Color(hex: "F44336"), // Red 500
        Color(hex: "E91E63"), // Pink 500
        Color(hex: "9C27B0"), // Purple 500
        Color(hex: "673AB7"), // Deep Purple 500
        Color(hex: "3F51B5"), // Indigo 500
        Color(hex: "2196F3"), // Blue 500
        Color(hex: "00BCD4"), // Cyan 500
        Color(hex: "009688"), // Teal 500
        Color(hex: "4CAF50"), // Green 500
        Color(hex: "8BC34A"), // Light Green 500
        Color(hex: "CDDC39"), // Lime 500
        Color(hex: "FFEB3B"), // Yellow 500
        Color(hex: "FF9800"), // Orange 500
        Color(hex: "FF5722"), // Deep Orange 500
        Color(hex: "795548"), // Brown 500
        Color(hex: "9E9E9E"), // Grey 500
        Color(hex: "607D8B")  // Blue Grey 500
    ]

    init(sessionStore: SessionStore, selectedDate: Date = Date(), initialSessions: [Session]? = nil) {
        self.sessionStore = sessionStore
        self.selectedDate = selectedDate
        let initial = initialSessions ?? []
        self.sessions = initial
        self.mergedBlocks = []
        
        // Load persisted colors
        if let saved = UserDefaults.standard.dictionary(forKey: "AppColors") as? [String: String] {
            for (bundle, hex) in saved {
                self.assignedColors[bundle] = Color(hex: hex)
            }
        }
        
        let blocks = Self.mergeSessions(
            initial,
            maxInterruptionDuration: maxInterruptionDuration,
            maxBridgeGap: maxBridgeGap,
            minimumDuration: minimumBlockDuration
        )
        self.mergedBlocks = assignColors(to: blocks)

        if initialSessions == nil {
            load()
        }
        
        // Listen for data updates
        NotificationCenter.default.publisher(for: .sessionDataDidUpdate)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }

    func load() {
        sessionStore.fetchSessions(for: selectedDate) { [weak self] sessions in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sessions = sessions
                let blocks = Self.mergeSessions(
                    sessions,
                    maxInterruptionDuration: self.maxInterruptionDuration,
                    maxBridgeGap: self.maxBridgeGap,
                    minimumDuration: self.minimumBlockDuration
                )
                self.mergedBlocks = self.assignColors(to: blocks)
            }
        }
    }

    func changeDate(_ date: Date) {
        selectedDate = date
        load()
    }

    func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            changeDate(newDate)
        }
    }

    func deleteSession(_ session: Session) {
        sessionStore.deleteSession(id: session.id)
    }

    func updateSession(_ session: Session, newName: String, newBundle: String, newStart: Date, newEnd: Date) {
        sessionStore.updateSession(
            id: session.id,
            appName: newName,
            bundleId: newBundle,
            start: newStart,
            end: newEnd
        )
    }

    func fetchUsageStats(
        for period: UsageStatsPeriod,
        completion: @escaping ([AppUsageStat]) -> Void
    ) {
        let range = Self.dateInterval(for: period, containing: selectedDate)

        sessionStore.fetchSessions(from: range.start, to: range.end) { sessions in
            let stats = Self.usageStats(from: sessions, in: range)
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }
    
    func updateColor(for bundleId: String, color: Color) {
        persistColor(for: bundleId, color: color)
        
        self.mergedBlocks = assignColors(to: self.mergedBlocks)
    }
    
    private func assignColors(to blocks: [SessionBlock]) -> [SessionBlock] {
        var updatedBlocks = blocks
        
        for i in 0..<updatedBlocks.count {
            let bundleId = updatedBlocks[i].bundleId
            
            if assignedColors[bundleId] == nil {
                var newColor: Color?
                
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let icon = NSWorkspace.shared.icon(forFile: appUrl.path)
                    if let iconColor = icon.averageColor {
                        newColor = iconColor
                    }
                }
                
                if newColor == nil {
                    let usedColors = Set(assignedColors.values)
                    let availableColors = Self.palette.filter { !usedColors.contains($0) }
                    
                    if let randomAvailable = availableColors.randomElement() {
                        newColor = randomAvailable
                    } else {
                        newColor = Self.palette.randomElement() ?? .blue
                    }
                }
                
                if let decidedColor = newColor {
                    persistColor(for: bundleId, color: decidedColor)
                }
            }
            
            updatedBlocks[i].color = assignedColors[bundleId]
        }
        return updatedBlocks
    }

    func getColor(for bundleId: String) -> Color? {
        return assignedColors[bundleId]
    }
    
    private func persistColor(for bundleId: String, color: Color) {
        assignedColors[bundleId] = color
        
        var saved = UserDefaults.standard.dictionary(forKey: "AppColors") as? [String: String] ?? [:]
        if let hex = color.toHex() {
            saved[bundleId] = hex
            UserDefaults.standard.set(saved, forKey: "AppColors")
        }
    }

    nonisolated static func mergeSessions(
        _ sessions: [Session],
        maxInterruptionDuration: TimeInterval = 300,
        maxBridgeGap: TimeInterval = 600,
        minimumDuration: TimeInterval = 30
    ) -> [SessionBlock] {
        guard !sessions.isEmpty else { return [] }
        let sorted = sessions.sorted { $0.startAt < $1.startAt }
        
        var blocks: [SessionBlock] = []
        var i = 0

        while i < sorted.count {
            let session = sorted[i]
            let currentStart = session.startAt
            var currentEnd = session.endAt
            let currentBundle = session.bundleId
            let currentAppName = session.appName
            
            var blockSegments: [Session] = [session]
            
            var nextIndex = i + 1
            
            while nextIndex < sorted.count {
                let nextSession = sorted[nextIndex]
                
                let gapToNext = nextSession.startAt.timeIntervalSince(currentEnd)
                
                if nextSession.bundleId == currentBundle {
                    if gapToNext <= maxBridgeGap {
                        currentEnd = max(currentEnd, nextSession.endAt)
                        blockSegments.append(nextSession)
                        nextIndex += 1
                        continue
                    } else {
                        break
                    }
                }
                
                var foundBridge = false
                var lookAhead = nextIndex
                
                while lookAhead < sorted.count {
                    let futureSession = sorted[lookAhead]
                    let totalDistance = futureSession.startAt.timeIntervalSince(currentEnd)
                    
                    if totalDistance > maxBridgeGap {
                        break
                    }
                    
                    if futureSession.bundleId == currentBundle {
                        var interruptionTotal: TimeInterval = 0
                        var interruptSegments: [Session] = []
                        
                        for k in nextIndex..<lookAhead {
                            let s = sorted[k]
                            interruptionTotal += s.duration
                            interruptSegments.append(s)
                        }
                        
                        if interruptionTotal <= maxInterruptionDuration {
                            currentEnd = max(currentEnd, futureSession.endAt)
                            
                            blockSegments.append(contentsOf: interruptSegments)
                            blockSegments.append(futureSession)
                            
                            nextIndex = lookAhead + 1
                            foundBridge = true
                            break
                        } else {
                            break
                        }
                    }
                    
                    lookAhead += 1
                }
                
                if foundBridge {
                    continue
                } else {
                    break
                }
            }
            
            var newBlock = SessionBlock(bundleId: currentBundle, appName: currentAppName, startAt: currentStart, endAt: currentEnd)
            newBlock.segments = blockSegments
            blocks.append(newBlock)
            i = nextIndex
        }
        
        return blocks.filter { $0.duration >= minimumDuration }
    }

    nonisolated static func dateInterval(
        for period: UsageStatsPeriod,
        containing date: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        if let interval = calendar.dateInterval(of: period.calendarComponent, for: date) {
            return interval
        }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: period.calendarComponent, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    nonisolated static func usageStats(
        from sessions: [Session],
        in range: DateInterval
    ) -> [AppUsageStat] {
        var totals: [String: (appName: String, duration: TimeInterval)] = [:]

        for session in sessions {
            let start = max(session.startAt, range.start)
            let end = min(session.endAt, range.end)
            let clippedDuration = end.timeIntervalSince(start)

            guard clippedDuration > 0 else { continue }

            let existing = totals[session.bundleId]
            totals[session.bundleId] = (
                appName: existing?.appName ?? session.appName,
                duration: (existing?.duration ?? 0) + clippedDuration
            )
        }

        return totals
            .map { bundleId, value in
                AppUsageStat(
                    bundleId: bundleId,
                    appName: value.appName,
                    duration: value.duration
                )
            }
            .sorted {
                if $0.duration == $1.duration {
                    return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
                }
                return $0.duration > $1.duration
            }
    }
}

private extension UsageStatsPeriod {
    var calendarComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .month:
            return .month
        case .year:
            return .year
        }
    }
}

#if DEBUG
extension TimelineViewModel {
    static var preview: TimelineViewModel {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())

        func makeSession(id: Int64, name: String, bundle: String, hour: Int, minute: Int, durationMin: Int) -> Session {
            let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
            let end = start.addingTimeInterval(TimeInterval(durationMin * 60))
            return Session(
                id: id,
                bundleId: bundle,
                appName: name,
                windowTitle: nil,
                startAt: start,
                endAt: end,
                duration: end.timeIntervalSince(start)
            )
        }

        let mockSessions: [Session] = [
            makeSession(id: 1, name: "Xcode", bundle: "com.apple.dt.Xcode", hour: 9, minute: 0, durationMin: 90),
            makeSession(id: 2, name: "Safari", bundle: "com.apple.Safari", hour: 10, minute: 45, durationMin: 60),
            makeSession(id: 3, name: "Slack", bundle: "com.tinyspeck.slackmacgap", hour: 13, minute: 30, durationMin: 45),
            makeSession(id: 4, name: "Notes", bundle: "com.apple.Notes", hour: 14, minute: 30, durationMin: 30),
            makeSession(id: 5, name: "Terminal", bundle: "com.apple.Terminal", hour: 15, minute: 30, durationMin: 15),
            // Test limits
            makeSession(id: 6, name: "Short 1m", bundle: "test.short.1m", hour: 16, minute: 0, durationMin: 1),
            makeSession(id: 7, name: "Limit 2m", bundle: "test.limit.2m", hour: 16, minute: 5, durationMin: 2),
            makeSession(id: 8, name: "Short 3m", bundle: "test.short.3m", hour: 16, minute: 10, durationMin: 3),
            makeSession(id: 9, name: "Short 5m", bundle: "test.short.5m", hour: 16, minute: 15, durationMin: 5),
            makeSession(id: 10, name: "Short 10m", bundle: "test.short.10m", hour: 16, minute: 25, durationMin: 10)
        ]

        return TimelineViewModel(
            sessionStore: SessionStore(),
            selectedDate: Date(),
            initialSessions: mockSessions
        )
    }
}
#endif
