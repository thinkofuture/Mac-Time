import SwiftUI

struct Session: Identifiable {
    let id: Int64
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let startAt: Date
    let endAt: Date
    let duration: TimeInterval
}

struct SessionBlock: Identifiable {
    let id = UUID()
    let bundleId: String
    let appName: String
    let startAt: Date
    let endAt: Date
    var color: Color? = nil
    var segments: [Session] = []

    var duration: TimeInterval { endAt.timeIntervalSince(startAt) }
    
    var displayTitle: String {
        // Find segments belonging to this app (exclude interruptions)
        let mySegments = segments.filter { $0.bundleId == bundleId }
        
        // Pick the segment with the longest duration to be representative
        if let longest = mySegments.max(by: { $0.duration < $1.duration }),
           let title = longest.windowTitle, !title.isEmpty {
            return title
        }
        
        // Fallback: Try any segment with a title
        if let firstWithTitle = mySegments.first(where: { !($0.windowTitle ?? "").isEmpty }),
           let title = firstWithTitle.windowTitle {
            return title
        }
        
        return appName
    }
}

enum UsageStatsPeriod: String, CaseIterable, Identifiable {
    case day
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return L10n.UsagePeriod.day
        case .month:
            return L10n.UsagePeriod.month
        case .year:
            return L10n.UsagePeriod.year
        }
    }
}

struct AppUsageStat: Identifiable, Equatable {
    let bundleId: String
    let appName: String
    let duration: TimeInterval

    var id: String { bundleId }
}
