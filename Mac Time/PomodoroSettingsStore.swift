import Foundation
import Combine

final class PomodoroSettingsStore: ObservableObject {
    @Published private(set) var settings: PomodoroSettings

    private let userDefaults: UserDefaults
    private let key = "pomodoro_settings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults, key: key)
    }

    func update(_ transform: (inout PomodoroSettings) -> Void) {
        var newSettings = settings
        transform(&newSettings)
        apply(newSettings)
    }

    func addWorkApp(_ app: KnownApp) {
        update { settings in
            guard !settings.workApps.contains(where: { $0.bundleId == app.bundleId }) else {
                return
            }

            settings.workApps.append(PomodoroWorkApp(bundleId: app.bundleId, appName: app.appName))
            settings.workApps.sort {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }
        }
    }

    func removeWorkApp(bundleId: String) {
        update { settings in
            settings.workApps.removeAll { $0.bundleId == bundleId }
        }
    }

    private func apply(_ newSettings: PomodoroSettings) {
        settings = sanitized(newSettings)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }

    private func sanitized(_ value: PomodoroSettings) -> PomodoroSettings {
        var settings = value
        settings.durationMinutes = min(max(settings.durationMinutes, 1), 240)
        settings.interruptionGraceMinutes = min(max(settings.interruptionGraceMinutes, 0), 120)
        settings.reminderIntervalMinutes = min(max(settings.reminderIntervalMinutes, 1), 240)

        var seenBundleIds = Set<String>()
        settings.workApps = settings.workApps
            .filter { !$0.bundleId.isEmpty && seenBundleIds.insert($0.bundleId).inserted }
            .sorted {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }

        return settings
    }

    private static func loadSettings(from userDefaults: UserDefaults, key: String) -> PomodoroSettings {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(PomodoroSettings.self, from: data) else {
            return .defaults
        }

        return decoded
    }
}
