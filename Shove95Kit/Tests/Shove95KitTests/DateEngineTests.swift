import Foundation
import Testing
@testable import Shove95Kit

/// Fixed calendar: gregorian, Europe/Berlin — deterministic regardless of the
/// machine running the tests. Reference week: Mon 2026-08-03 … Sun 2026-08-09.
enum Fixed {
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12, _ mm: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hh, minute: mm))!
    }
}

@Suite("Week horizon (Sunday assignment, Sat/Sun rollover)")
struct WeekHorizonTests {
    let cal = Fixed.calendar

    @Test func mondayPointsAtThisSunday() {
        let horizon = DateEngine.weekHorizon(now: Fixed.date(2026, 8, 3), calendar: cal)
        #expect(horizon == Fixed.date(2026, 8, 9, 0, 0))
    }

    @Test func thursdayPointsAtThisSunday() {
        let horizon = DateEngine.weekHorizon(now: Fixed.date(2026, 8, 6), calendar: cal)
        #expect(horizon == Fixed.date(2026, 8, 9, 0, 0))
    }

    @Test func fridayStillPointsAtThisSunday() {
        // Tomorrow is Saturday; Sunday is still after tomorrow → reachable.
        let horizon = DateEngine.weekHorizon(now: Fixed.date(2026, 8, 7), calendar: cal)
        #expect(horizon == Fixed.date(2026, 8, 9, 0, 0))
    }

    @Test func saturdayRollsToNextSunday() {
        // Sunday IS tomorrow → Week means next week (locked Q4-A).
        let horizon = DateEngine.weekHorizon(now: Fixed.date(2026, 8, 8), calendar: cal)
        #expect(horizon == Fixed.date(2026, 8, 16, 0, 0))
    }

    @Test func sundayRollsToNextSunday() {
        let horizon = DateEngine.weekHorizon(now: Fixed.date(2026, 8, 9), calendar: cal)
        #expect(horizon == Fixed.date(2026, 8, 16, 0, 0))
    }
}

@Suite("Bucketing (total mapping, overdue rolls forward)")
struct BucketingTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func nilDateIsGeneral() {
        #expect(DateEngine.bucket(for: nil, now: mondayNoon, calendar: cal) == .general)
    }

    @Test func todayTomorrowWeekBoundaries() {
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 3, 0, 0), now: mondayNoon, calendar: cal) == .today)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 4, 0, 0), now: mondayNoon, calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 5, 0, 0), now: mondayNoon, calendar: cal) == .week)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 9, 0, 0), now: mondayNoon, calendar: cal) == .week)
    }

    @Test func pastDatesFallIntoToday() {
        // The overdue roll-forward IS the filter — no rollover job (PRD FR-001).
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 1, 0, 0), now: mondayNoon, calendar: cal) == .today)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 7, 1, 0, 0), now: mondayNoon, calendar: cal) == .today)
    }

    @Test func fiveDayGapShowsEverythingInToday() {
        let now = Fixed.date(2026, 8, 8) // closed Aug 3–7, reopened Sat Aug 8
        for day in 3...7 {
            #expect(DateEngine.bucket(for: Fixed.date(2026, 8, day, 0, 0), now: now, calendar: cal) == .today)
        }
    }

    @Test func midnightBoundaryFlipsTomorrowIntoToday() {
        let tuesday = Fixed.date(2026, 8, 4, 0, 0)
        #expect(DateEngine.bucket(for: tuesday, now: Fixed.date(2026, 8, 3, 23, 59), calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: tuesday, now: Fixed.date(2026, 8, 4, 0, 0), calendar: cal) == .today)
    }

    @Test func datesBeyondHorizonStayVisibleInWeek() {
        // Total mapping: nothing can ever vanish (safety deviation noted in DateEngine).
        #expect(DateEngine.bucket(for: Fixed.date(2026, 9, 20, 0, 0), now: mondayNoon, calendar: cal) == .week)
    }

    @Test func saturdayTomorrowVsWeekSplit() {
        let saturday = Fixed.date(2026, 8, 8)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 9, 0, 0), now: saturday, calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 10, 0, 0), now: saturday, calendar: cal) == .week)
        #expect(DateEngine.targetDate(for: .week, now: saturday, calendar: cal) == Fixed.date(2026, 8, 16, 0, 0))
    }
}

@Suite("Target dates for moves")
struct TargetDateTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func targets() {
        #expect(DateEngine.targetDate(for: .today, now: mondayNoon, calendar: cal) == Fixed.date(2026, 8, 3, 0, 0))
        #expect(DateEngine.targetDate(for: .tomorrow, now: mondayNoon, calendar: cal) == Fixed.date(2026, 8, 4, 0, 0))
        #expect(DateEngine.targetDate(for: .week, now: mondayNoon, calendar: cal) == Fixed.date(2026, 8, 9, 0, 0))
        #expect(DateEngine.targetDate(for: .general, now: mondayNoon, calendar: cal) == nil)
    }
}

@Suite("Overdue")
struct OverdueTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func pastAndUnfinishedIsOverdue() {
        #expect(DateEngine.isOverdue(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: false, now: mondayNoon, calendar: cal))
    }

    @Test func completedIsNeverOverdue() {
        // The classic first-app bug, pinned (locked Q11).
        #expect(!DateEngine.isOverdue(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: true, now: mondayNoon, calendar: cal))
    }

    @Test func todayAndGeneralAreNotOverdue() {
        #expect(!DateEngine.isOverdue(dueDate: Fixed.date(2026, 8, 3, 0, 0), isCompleted: false, now: mondayNoon, calendar: cal))
        #expect(!DateEngine.isOverdue(dueDate: nil, isCompleted: false, now: mondayNoon, calendar: cal))
    }
}

@Suite("Archive visibility")
struct ArchiveTests {
    let cal = Fixed.calendar

    @Test func datedTaskArchivesAtMidnightAfterCompletion() {
        let completedLateMonday = Fixed.date(2026, 8, 3, 23, 50)
        let due = Fixed.date(2026, 8, 3, 0, 0)
        // Still Monday → visible struck-through.
        #expect(!DateEngine.isArchived(dueDate: due, isCompleted: true, completedAt: completedLateMonday,
                                       now: Fixed.date(2026, 8, 3, 23, 59), calendar: cal))
        // Ten minutes later (Tuesday 00:10) → archived.
        #expect(DateEngine.isArchived(dueDate: due, isCompleted: true, completedAt: completedLateMonday,
                                      now: Fixed.date(2026, 8, 4, 0, 10), calendar: cal))
    }

    @Test func generalTaskArchivesAfter24Hours() {
        let completed = Fixed.date(2026, 8, 3, 10, 0)
        #expect(!DateEngine.isArchived(dueDate: nil, isCompleted: true, completedAt: completed,
                                       now: Fixed.date(2026, 8, 4, 9, 59), calendar: cal))
        #expect(DateEngine.isArchived(dueDate: nil, isCompleted: true, completedAt: completed,
                                      now: Fixed.date(2026, 8, 4, 10, 1), calendar: cal))
    }

    @Test func incompleteIsNeverArchived() {
        #expect(!DateEngine.isArchived(dueDate: nil, isCompleted: false, completedAt: nil,
                                       now: Fixed.date(2026, 8, 4), calendar: cal))
    }

    @Test func completedYesterdayDatedTaskInvisibleInToday() {
        // End-to-end visibility handoff (TASK-054 pre-check): completed-yesterday
        // dated task is archived, so not visible in Today despite matching the filter.
        let due = Fixed.date(2026, 8, 2, 0, 0)
        let completed = Fixed.date(2026, 8, 2, 18, 0)
        let now = Fixed.date(2026, 8, 3)
        #expect(DateEngine.bucket(for: due, now: now, calendar: cal) == .today)
        #expect(!DateEngine.isVisible(in: .today, dueDate: due, isCompleted: true,
                                      completedAt: completed, now: now, calendar: cal))
    }
}

@Suite("Chip labels")
struct ChipFormatTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func oneToSixDaysShowsWeekday() {
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "Sun")   // 1 day
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 7, 28, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "Tue")   // 6 days
    }

    @Test func sevenPlusDaysShowsCount() {
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 7, 27, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "7d")
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 6, 24, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "40d")
    }

    @Test func notOverdueMeansNoChip() {
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 8, 3, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == nil)
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: true,
                                 now: mondayNoon, calendar: cal) == nil)
        #expect(ChipFormat.label(dueDate: nil, isCompleted: false,
                                 now: mondayNoon, calendar: cal) == nil)
    }
}
