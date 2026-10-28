import Foundation

/// Persisted usage / extend state for the local calendar day.
struct DayUsage: Codable, Equatable {
    /// YYYY-MM-dd in local timezone
    var dayKey: String
    /// Accrued seconds per category today
    var seconds: [String: TimeInterval]
    /// Extra minutes granted today via +1 / +15
    var extendMinutes: [String: Int]
    /// Categories unlocked for the rest of today
    var unlockedForToday: [String: Bool]
    /// When soft nudge was last dismissed (no extend) per category
    var lastDismissedAt: [String: Date]

    static func empty(for date: Date = Date()) -> DayUsage {
        DayUsage(
            dayKey: Self.dayKey(for: date),
            seconds: [:],
            extendMinutes: [:],
            unlockedForToday: [:],
            lastDismissedAt: [:]
        )
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func seconds(for id: CategoryID) -> TimeInterval {
        seconds[id.rawValue] ?? 0
    }

    func extendMinutes(for id: CategoryID) -> Int {
        extendMinutes[id.rawValue] ?? 0
    }

    func isUnlocked(for id: CategoryID) -> Bool {
        unlockedForToday[id.rawValue] ?? false
    }

    func lastDismissed(for id: CategoryID) -> Date? {
        lastDismissedAt[id.rawValue]
    }

    mutating func add(seconds delta: TimeInterval, to id: CategoryID) {
        guard delta > 0 else { return }
        seconds[id.rawValue, default: 0] += delta
    }

    mutating func addExtend(minutes: Int, to id: CategoryID) {
        extendMinutes[id.rawValue, default: 0] += minutes
        lastDismissedAt[id.rawValue] = nil
    }

    mutating func unlockForToday(_ id: CategoryID) {
        unlockedForToday[id.rawValue] = true
        lastDismissedAt[id.rawValue] = nil
    }

    mutating func markDismissed(_ id: CategoryID, at date: Date = Date()) {
        lastDismissedAt[id.rawValue] = date
    }
}
