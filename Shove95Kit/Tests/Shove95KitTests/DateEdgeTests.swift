import Testing
import Foundation
@testable import Shove95Kit

/// TASK-060. The edges where a date-driven app quietly goes wrong: the seam
/// either side of midnight, days that aren't 24 hours long, and timezones
/// far from the one it was written in.
///
/// Every case pins `now` and `calendar` explicitly — the engine takes both, so
/// none of this depends on when or where the suite runs.
@Suite("Date edges (midnight, DST, timezones)")
struct DateEdgeTests {

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.firstWeekday = 2 // Monday; the week horizon is Sunday by rule
        return calendar
    }

    private func date(_ string: String, _ zone: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: zone)!
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }

    // MARK: The midnight seam

    @Test("A task due today is still Today at 23:59, and Today at 00:01")
    func midnightSeam() {
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        let today = date("2026-08-04 00:00", zone)

        let lateTonight = date("2026-08-04 23:59", zone)
        #expect(DateEngine.bucket(for: today, now: lateTonight, calendar: cal) == .today)

        // One minute later it is a NEW day, and yesterday's task is overdue —
        // which the total mapping folds back into Today rather than losing.
        let justAfter = date("2026-08-05 00:01", zone)
        #expect(DateEngine.bucket(for: today, now: justAfter, calendar: cal) == .today)
    }

    @Test("Tomorrow becomes Today the moment the day turns")
    func tomorrowBecomesToday() {
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        let tomorrow = date("2026-08-05 00:00", zone)

        #expect(DateEngine.bucket(for: tomorrow,
                                  now: date("2026-08-04 23:59", zone),
                                  calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: tomorrow,
                                  now: date("2026-08-05 00:01", zone),
                                  calendar: cal) == .today)
    }

    // MARK: Days that aren't 24 hours

    @Test("Spring-forward: the 23-hour day still maps cleanly")
    func springForward() {
        // 29 March 2026, Europe/Berlin: 02:00 → 03:00, a 23-hour day.
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        let dstDay = date("2026-03-29 00:00", zone)
        let duringDST = date("2026-03-29 12:00", zone)

        #expect(DateEngine.bucket(for: dstDay, now: duringDST, calendar: cal) == .today)
        // Adding a day across the gap must land on the next calendar day, not
        // 24 hours later — the difference is exactly the bug this guards.
        let tomorrow = DateEngine.startOfTomorrow(now: duringDST, calendar: cal)
        #expect(cal.component(.day, from: tomorrow) == 30)
    }

    @Test("Autumn fall-back: the 25-hour day still maps cleanly")
    func fallBack() {
        // 25 October 2026, Europe/Berlin: 03:00 → 02:00, a 25-hour day.
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        let dstDay = date("2026-10-25 00:00", zone)
        let duringDST = date("2026-10-25 12:00", zone)

        #expect(DateEngine.bucket(for: dstDay, now: duringDST, calendar: cal) == .today)
        let tomorrow = DateEngine.startOfTomorrow(now: duringDST, calendar: cal)
        #expect(cal.component(.day, from: tomorrow) == 26)
    }

    // MARK: Timezones

    @Test("The same instant buckets by the LOCAL day, not UTC")
    func timezoneLocality() {
        // 23:30 in Berlin on the 4th is already 06:30 on the 5th in Tokyo.
        let instant = date("2026-08-04 23:30", "Europe/Berlin")
        let berlinTask = date("2026-08-04 00:00", "Europe/Berlin")

        #expect(DateEngine.bucket(for: berlinTask, now: instant,
                                  calendar: calendar("Europe/Berlin")) == .today)
        // In Tokyo that same task is yesterday — still Today by the
        // roll-forward rule, never invisible.
        #expect(DateEngine.bucket(for: berlinTask, now: instant,
                                  calendar: calendar("Asia/Tokyo")) == .today)
    }

    @Test("Crossing the date line does not strand a task")
    func dateLine() {
        let instant = date("2026-08-04 12:00", "UTC")
        for zone in ["Pacific/Kiritimati", "Pacific/Midway", "Asia/Kathmandu",
                     "America/Los_Angeles", "Australia/Sydney"] {
            let cal = calendar(zone)
            for offset in [-2, -1, 0, 1, 2, 30] {
                let due = cal.date(byAdding: .day, value: offset,
                                   to: cal.startOfDay(for: instant))!
                // Totality: every date maps to exactly one bucket, everywhere.
                let bucket = DateEngine.bucket(for: due, now: instant, calendar: cal)
                #expect(Bucket.allCases.contains(bucket))
            }
        }
    }

    // MARK: Week horizon

    @Test("Week horizon is always a Sunday, and always after tomorrow")
    func weekHorizonAlwaysFutureSunday() {
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        // Walk a full fortnight so every weekday is covered, including the
        // Sat/Sun rollover the plan calls out.
        for dayOffset in 0..<14 {
            let now = cal.date(byAdding: .day, value: dayOffset,
                               to: date("2026-08-03 09:00", zone))!
            let horizon = DateEngine.weekHorizon(now: now, calendar: cal)
            #expect(cal.component(.weekday, from: horizon) == 1, "horizon must be a Sunday")
            #expect(horizon > DateEngine.startOfTomorrow(now: now, calendar: cal),
                    "horizon must be reachable by the Week tab")
        }
    }

    @Test("A task assigned to Week lands in Week, on every day of the year")
    func weekAssignmentRoundTrips() {
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        var now = date("2026-01-01 09:00", zone)
        for _ in 0..<365 {
            let due = DateEngine.targetDate(for: .week, now: now, calendar: cal)
            #expect(DateEngine.bucket(for: due, now: now, calendar: cal) == .week,
                    "Week assignment must round-trip on \(now)")
            now = cal.date(byAdding: .day, value: 1, to: now)!
        }
    }

    @Test("Every bucket's assigned date round-trips to that same bucket")
    func allBucketsRoundTrip() {
        let zone = "Europe/Berlin"
        let cal = calendar(zone)
        var now = date("2026-01-01 09:00", zone)
        for _ in 0..<365 {
            for bucket in Bucket.allCases {
                let due = DateEngine.targetDate(for: bucket, now: now, calendar: cal)
                #expect(DateEngine.bucket(for: due, now: now, calendar: cal) == bucket,
                        "\(bucket) failed to round-trip on \(now)")
            }
            now = cal.date(byAdding: .day, value: 1, to: now)!
        }
    }
}
