//
//  DayPicker.swift
//  shove95
//
//  The calendar button's sheet: Today and Tomorrow on top, then the months.
//
//  A MONTH GRID, not a list of days (founder direction 2026-08-17, revising
//  the first build). A list makes you scroll to find the 21st; a grid lets you
//  see it. The two shortcuts stay above it because "today" and "tomorrow" are
//  answers people give without thinking about dates at all.
//
//  Months are STACKED and scrolled rather than paged with arrows. Paging needs
//  two more controls and a sense of where you are; stacking needs neither, and
//  the horizon here is a few months, not a few years.
//
//  There is no "no date" row. A date can be changed — by picking another day,
//  or by swiping the task to Today or Tomorrow — but taking one off entirely
//  is what swiping to Soon already does, and two ways to say the same thing is
//  one too many (founder direction, same day).
//

import Foundation
import Shove95Kit

/// The days a month grid draws, shared by both looks so they cannot drift.
enum DayPickerRange {
    /// How many months the sheet offers, starting with the current one.
    static let months = 4

    /// Weekday headers, Monday first — the founder's reference starts the week
    /// on Monday, and so does most of Europe. Locale-independent like every
    /// other date label in the app.
    static let weekdayHeaders = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private static let monthNames = ["", "January", "February", "March", "April",
                                     "May", "June", "July", "August",
                                     "September", "October", "November", "December"]

    /// The first day of each month the sheet shows.
    static func monthStarts(now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        guard let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
        else { return [] }
        return (0..<months).compactMap {
            calendar.date(byAdding: .month, value: $0, to: thisMonth)
        }
    }

    static func title(for month: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: month)
        return "\(monthNames[parts.month ?? 1]) \(parts.year ?? 0)"
    }

    /// One month as a flat run of cells — see `MonthGrid`, which lives in the
    /// package because the Monday-first shift is the kind of arithmetic that
    /// fails silently and wants a test.
    static func grid(for month: Date, calendar: Calendar) -> [Date?] {
        MonthGrid.cells(for: month, calendar: calendar)
    }
}
