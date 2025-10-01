import Foundation

/// Floors the given date to the start of its minute using the provided calendar (default: current).
func floorToMinute(_ date: Date, calendar: Calendar = .current) -> Date {
    var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    comps.second = 0
    return calendar.date(from: comps) ?? date
}
