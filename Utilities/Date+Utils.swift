import Foundation

extension Date {
    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func endOfDay(for date: Date) -> Date? {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(for: date))
    }
}

