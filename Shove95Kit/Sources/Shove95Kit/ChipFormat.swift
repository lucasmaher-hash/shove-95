import Foundation

/// Overdue date-chip labels (PRD §3, design.md §5).
/// 1–6 days overdue → English weekday abbreviation of the due date ("Mon");
/// 7+ days → day count ("12d"). Locale-independent by design — the chip is a
/// factual marker, always the same three-ish characters wide.
public enum ChipFormat {
    private static let weekdayAbbreviations = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Label for an overdue task's chip, or nil when the task isn't overdue.
    public static func label(dueDate: Date?, isCompleted: Bool, now: Date, calendar: Calendar) -> String? {
        guard DateEngine.isOverdue(dueDate: dueDate, isCompleted: isCompleted, now: now, calendar: calendar),
              let dueDate else { return nil }
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = DateEngine.startOfToday(now: now, calendar: calendar)
        let days = calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0
        if days >= 7 {
            return "\(days)d"
        }
        let weekday = calendar.component(.weekday, from: dueDay) // 1 = Sunday … 7 = Saturday
        return weekdayAbbreviations[weekday]
    }
}

/// Day headings for the Soon tab: "Fri 14 Apr".
///
/// The weekday says how far away it FEELS and the date says exactly when —
/// the founder asked for both (2026-08-17). Locale-independent like the
/// chips, and for the same reason: these are factual markers, and a heading
/// that changes width with the system language would reflow the whole list.
public enum DayHeading {
    private static let weekdays = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public static func label(for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.weekday, .day, .month], from: day)
        let weekday = weekdays[parts.weekday ?? 1]
        let month = months[parts.month ?? 1]
        return "\(weekday) \(parts.day ?? 1) \(month)"
    }
}
