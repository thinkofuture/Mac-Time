import Foundation

struct ActivityEvent {
    let bundleId: String?
    let appName: String?
    let windowTitle: String?
    let happenedAt: Date
}

struct KnownApp: Identifiable, Equatable {
    let bundleId: String
    let appName: String
    var totalDuration: TimeInterval = 0

    var id: String { bundleId }
}

struct PomodoroWorkApp: Codable, Identifiable, Equatable {
    let bundleId: String
    var appName: String

    var id: String { bundleId }
}

struct PomodoroSettings: Codable, Equatable {
    var isEnabled: Bool
    var durationMinutes: Int
    var interruptionGraceMinutes: Int
    var reminderIntervalMinutes: Int
    var showsStatusBarWorkTime: Bool
    var workApps: [PomodoroWorkApp]

    static let defaultDurationMinutes = 25
    static let defaultInterruptionGraceMinutes = 5

    static var defaults: PomodoroSettings {
        PomodoroSettings(
            isEnabled: true,
            durationMinutes: defaultDurationMinutes,
            interruptionGraceMinutes: defaultInterruptionGraceMinutes,
            reminderIntervalMinutes: defaultDurationMinutes,
            showsStatusBarWorkTime: true,
            workApps: []
        )
    }
}

struct PomodoroState: Equatable {
    var accumulatedWorkDuration: TimeInterval = 0
    var currentWorkAppBundleId: String?
    var interruptionStart: Date?
    var nextReminderThreshold: TimeInterval

    init(settings: PomodoroSettings) {
        nextReminderThreshold = TimeInterval(settings.durationMinutes * 60)
    }

    var isWorking: Bool {
        currentWorkAppBundleId != nil
    }
}

extension Notification.Name {
    static let activityDidUpdate = Notification.Name("activityDidUpdate")
}
