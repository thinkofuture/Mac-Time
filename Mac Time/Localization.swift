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
