import Foundation

enum L10n {
    enum App {
        static var quit: String { String(localized: "app.quit") }
    }

    enum Tab {
        static var timeline: String { String(localized: "tab.timeline") }
        static var data: String { String(localized: "tab.data") }
        static var stats: String { String(localized: "tab.stats") }
    }

    enum Toolbar {
        static var today: String { String(localized: "toolbar.today") }
        static var zoomOut: String { String(localized: "toolbar.zoom_out") }
        static var zoomIn: String { String(localized: "toolbar.zoom_in") }
    }

    enum Sessions {
        static var app: String { String(localized: "sessions.column.app") }
        static var bundleID: String { String(localized: "sessions.column.bundle_id") }
        static var start: String { String(localized: "sessions.column.start") }
        static var end: String { String(localized: "sessions.column.end") }
        static var duration: String { String(localized: "sessions.column.duration") }
        static var edit: String { String(localized: "sessions.action.edit") }
        static var delete: String { String(localized: "sessions.action.delete") }
        static var editTitle: String { String(localized: "sessions.edit.title") }
        static var appName: String { String(localized: "sessions.edit.app_name") }
        static var startTime: String { String(localized: "sessions.edit.start_time") }
        static var endTime: String { String(localized: "sessions.edit.end_time") }
        static var cancel: String { String(localized: "sessions.edit.cancel") }
        static var save: String { String(localized: "sessions.edit.save") }
    }

    enum Stats {
        static var empty: String { String(localized: "stats.empty") }
    }

    enum Pomodoro {
        static var settingsTitle: String { String(localized: "pomodoro.settings.title") }
        static var settingsMenu: String { String(localized: "pomodoro.settings.menu") }
        static var enabled: String { String(localized: "pomodoro.enabled") }
        static var duration: String { String(localized: "pomodoro.duration") }
        static var interruptionGrace: String { String(localized: "pomodoro.interruption_grace") }
        static var reminderInterval: String { String(localized: "pomodoro.reminder_interval") }
        static var showStatusBarWorkTime: String { String(localized: "pomodoro.show_status_bar_work_time") }
        static var workApps: String { String(localized: "pomodoro.work_apps") }
        static var workAppsDescription: String { String(localized: "pomodoro.work_apps.description") }
        static var noKnownApps: String { String(localized: "pomodoro.no_known_apps") }
        static var enabledDescription: String { String(localized: "pomodoro.enabled.description") }
        static var discard: String { String(localized: "pomodoro.action.discard") }

        static func minutesValue(_ minutes: Int) -> String {
            formatted("pomodoro.minutes_value", Int64(minutes))
        }

        static func workAppCount(_ count: Int) -> String {
            formatted("pomodoro.work_app_count", Int64(count))
        }

        static func reminderBody(minutes: Int) -> String {
            formatted("pomodoro.notification.body", Int64(minutes))
        }

        private static func formatted(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
            String(
                format: String(localized: key),
                locale: Locale.autoupdatingCurrent,
                arguments: arguments
            )
        }
    }

    enum UsagePeriod {
        static var day: String { String(localized: "usage_period.day") }
        static var month: String { String(localized: "usage_period.month") }
        static var year: String { String(localized: "usage_period.year") }
    }

    enum Duration {
        static func daysHoursMinutes(days: Int, hours: Int, minutes: Int) -> String {
            formatted("duration.days_hours_minutes", Int64(days), Int64(hours), Int64(minutes))
        }

        static func hoursMinutes(hours: Int, minutes: Int) -> String {
            formatted("duration.hours_minutes", Int64(hours), Int64(minutes))
        }

        static func minutes(_ minutes: Int) -> String {
            formatted("duration.minutes", Int64(minutes))
        }

        private static func formatted(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
            String(
                format: String(localized: key),
                locale: Locale.autoupdatingCurrent,
                arguments: arguments
            )
        }
    }
}
