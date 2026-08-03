import Testing
@testable import Shove95Kit

@Suite("Bucket line stepping")
struct BucketSteppingTests {
    @Test func deferSteps() {
        #expect(Bucket.today.steppedOnce(.deferOne) == .tomorrow)
        #expect(Bucket.tomorrow.steppedOnce(.deferOne) == .week)
        #expect(Bucket.week.steppedOnce(.deferOne) == .general)
    }

    @Test func pullSteps() {
        #expect(Bucket.general.steppedOnce(.pullOne) == .week)
        #expect(Bucket.week.steppedOnce(.pullOne) == .tomorrow)
        #expect(Bucket.tomorrow.steppedOnce(.pullOne) == .today)
    }

    @Test func deadEnds() {
        #expect(Bucket.today.steppedOnce(.pullOne) == nil)     // nothing nearer than today
        #expect(Bucket.general.steppedOnce(.deferOne) == nil)  // nothing beyond the parking lot
    }

    @Test func lineOrder() {
        #expect(Bucket.line == [.today, .tomorrow, .week, .general])
    }
}

@Suite("Context-menu destinations (locked PRD §3 table)")
struct BucketMenuTests {
    @Test func todayMenu() {
        #expect(Bucket.today.menuDestinations == [
            .init(label: "> Week", bucket: .week),
            .init(label: ">> General", bucket: .general),
        ])
    }

    @Test func tomorrowMenu() {
        #expect(Bucket.tomorrow.menuDestinations == [
            .init(label: "> General", bucket: .general),
        ])
    }

    @Test func weekMenu() {
        #expect(Bucket.week.menuDestinations == [
            .init(label: "< Today", bucket: .today),
        ])
    }

    @Test func generalMenu() {
        #expect(Bucket.general.menuDestinations == [
            .init(label: "< Tomorrow", bucket: .tomorrow),
            .init(label: "<< Today", bucket: .today),
        ])
    }

    @Test("menus never contain adjacent buckets or self")
    func noAdjacentDestinations() {
        for bucket in Bucket.line {
            let adjacent = [bucket.steppedOnce(.deferOne), bucket.steppedOnce(.pullOne)]
            for dest in bucket.menuDestinations {
                #expect(dest.bucket != bucket)
                #expect(!adjacent.contains(dest.bucket))
            }
        }
    }
}
