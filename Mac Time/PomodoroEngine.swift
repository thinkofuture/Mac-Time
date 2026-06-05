import Foundation

struct PomodoroEngine {
    private(set) var state: PomodoroState
    private var settings: PomodoroSettings
    private var lastTickAt: Date?

    init(settings: PomodoroSettings) {
        self.settings = settings
        self.state = PomodoroState(settings: settings)
    }

    mutating func updateSettings(_ newSettings: PomodoroSettings, at now: Date) {
        _ = tick(at: now)
        settings = newSettings

        if !settings.isEnabled || settings.workApps.isEmpty {
            reset()
            return
        }

        if let currentWorkAppBundleId = state.currentWorkAppBundleId,
           !settings.workApps.contains(where: { $0.bundleId == currentWorkAppBundleId }) {
            state.currentWorkAppBundleId = nil
            state.interruptionStart = state.accumulatedWorkDuration > 0 ? now : nil
        }

        let firstThreshold = TimeInterval(settings.durationMinutes * 60)
        let reminderInterval = TimeInterval(settings.reminderIntervalMinutes * 60)

        if state.accumulatedWorkDuration < firstThreshold {
            state.nextReminderThreshold = firstThreshold
        } else {
            var threshold = firstThreshold
            while threshold <= state.accumulatedWorkDuration {
                threshold += reminderInterval
            }
            state.nextReminderThreshold = threshold
        }
    }

    mutating func handleActivity(_ event: ActivityEvent) {
        _ = tick(at: event.happenedAt)

        guard settings.isEnabled,
              let bundleId = event.bundleId,
              settings.workApps.contains(where: { $0.bundleId == bundleId }) else {
            if state.currentWorkAppBundleId != nil {
                state.currentWorkAppBundleId = nil
                state.interruptionStart = event.happenedAt
            } else if state.accumulatedWorkDuration > 0 && state.interruptionStart == nil {
                state.interruptionStart = event.happenedAt
            }
            return
        }

        if let interruptionStart = state.interruptionStart,
           event.happenedAt.timeIntervalSince(interruptionStart) > TimeInterval(settings.interruptionGraceMinutes * 60) {
            reset(keepingLastTickAt: event.happenedAt)
        }

        state.currentWorkAppBundleId = bundleId
        state.interruptionStart = nil
        lastTickAt = event.happenedAt
    }

    mutating func tick(at now: Date) -> Int? {
        guard settings.isEnabled,
              !settings.workApps.isEmpty else {
            reset(keepingLastTickAt: now)
            return nil
        }

        defer {
            lastTickAt = now
        }

        if let interruptionStart = state.interruptionStart,
           now.timeIntervalSince(interruptionStart) > TimeInterval(settings.interruptionGraceMinutes * 60) {
            reset(keepingLastTickAt: now)
            return nil
        }

        guard state.currentWorkAppBundleId != nil else {
            return nil
        }

        if let lastTickAt, now > lastTickAt {
            state.accumulatedWorkDuration += now.timeIntervalSince(lastTickAt)
        }

        if state.accumulatedWorkDuration >= state.nextReminderThreshold {
            let reminderMinutes = Int(state.nextReminderThreshold / 60)
            state.nextReminderThreshold += TimeInterval(settings.reminderIntervalMinutes * 60)
            return reminderMinutes
        }

        return nil
    }

    mutating func reset() {
        reset(keepingLastTickAt: nil)
    }

    mutating func discard() {
        reset()
    }

    private mutating func reset(keepingLastTickAt date: Date?) {
        state = PomodoroState(settings: settings)
        lastTickAt = date
    }
}
