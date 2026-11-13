import XCTest
@testable import EmberBarCore

final class UsageHistoryTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func usage(_ five: Double, _ week: Double) -> Usage {
        Usage(fiveHour: UsageWindow(percent: five, resetsAt: nil), week: UsageWindow(percent: week, resetsAt: nil))
    }

    func testRecordKeepsDailyPeak() {
        var h = UsageHistory()
        h.record(usage(10, 5), now: date(2026, 11, 13, 9), calendar: cal)
        h.record(usage(60, 7), now: date(2026, 11, 13, 15), calendar: cal)
        h.record(usage(30, 9), now: date(2026, 11, 13, 18), calendar: cal)
        XCTAssertEqual(h.days, [DayUsage(day: "2026-11-13", peak5: 60, peakWeek: 9)])
    }

    func testOldDaysArePruned() {
        var h = UsageHistory(days: [DayUsage(day: "2026-01-01", peak5: 1, peakWeek: 1),
                                    DayUsage(day: "2026-10-01", peak5: 2, peakWeek: 2)])
        h.record(usage(5, 5), now: date(2026, 11, 13), calendar: cal)
        XCTAssertEqual(h.days.map(\.day), ["2026-10-01", "2026-11-13"])
    }

    func testMonthlyAggregates() {
        let h = UsageHistory(days: [
            DayUsage(day: "2026-11-01", peak5: 40, peakWeek: 10),
            DayUsage(day: "2026-11-02", peak5: 80, peakWeek: 30),
            DayUsage(day: "2026-09-15", peak5: 50, peakWeek: 20),
        ])
        let m = h.monthly(3, now: date(2026, 11, 13), calendar: cal)
        XCTAssertEqual(m.count, 3)
        XCTAssertEqual(m[0].days, 1)          // Sep
        XCTAssertEqual(m[1].days, 0)          // Oct (empty)
        XCTAssertNil(m[1].avg5)
        XCTAssertEqual(m[2].days, 2)          // Nov
        XCTAssertEqual(m[2].avg5, 60)
        XCTAssertEqual(m[2].maxWeek, 30)
    }

    func testMonthlyCrossesYearBoundary() {
        let m = UsageHistory().monthly(3, now: date(2026, 1, 10), calendar: cal)
        XCTAssertEqual(m.map { cal.component(.month, from: $0.month) }, [11, 12, 1])
    }

    func testRoundTrip() {
        var h = UsageHistory()
        h.record(usage(12, 34), now: date(2026, 11, 13), calendar: cal)
        XCTAssertEqual(UsageHistory(decoding: h.encoded()), h)
    }

    // MARK: hostile / corrupted files

    func testGarbageFileGivesEmptyHistory() {
        XCTAssertEqual(UsageHistory(decoding: Data("not json".utf8)).days, [])
        XCTAssertEqual(UsageHistory(decoding: Data("{}".utf8)).days, [])
        XCTAssertEqual(UsageHistory(decoding: Data()).days, [])
    }

    func testInvalidEntriesAreDropped() {
        let json = """
        [{"day":"2026-11-13","peak5":10,"peakWeek":20},
         {"day":"../../etc/passwd","peak5":1,"peakWeek":1},
         {"day":"2026-13-01","peak5":1,"peakWeek":1},
         {"day":"2026-11-13","peak5":-5,"peakWeek":1},
         {"day":"2026-11-14","peak5":1e300,"peakWeek":1},
         {"day":"26-11-15","peak5":1,"peakWeek":1}]
        """
        XCTAssertEqual(UsageHistory(decoding: Data(json.utf8)).days, [DayUsage(day: "2026-11-13", peak5: 10, peakWeek: 20)])
    }

    func testDuplicatesAreMergedAndSorted() {
        let json = """
        [{"day":"2026-11-14","peak5":5,"peakWeek":5},
         {"day":"2026-11-13","peak5":10,"peakWeek":2},
         {"day":"2026-11-13","peak5":3,"peakWeek":9}]
        """
        XCTAssertEqual(UsageHistory(decoding: Data(json.utf8)).days, [
            DayUsage(day: "2026-11-13", peak5: 10, peakWeek: 9),
            DayUsage(day: "2026-11-14", peak5: 5, peakWeek: 5),
        ])
    }

    func testEntryCountIsCapped() {
        var items: [String] = []
        for y in 2000...2020 { for m in 1...12 { for d in 1...3 {
            items.append(String(format: #"{"day":"%04d-%02d-%02d","peak5":1,"peakWeek":1}"#, y, m, d))
        } } }
        let h = UsageHistory(decoding: Data("[\(items.joined(separator: ","))]".utf8))
        XCTAssertEqual(h.days.count, UsageHistory.maxEntries)
        XCTAssertEqual(h.days.last?.day, "2020-12-03") // keeps the newest
    }

    func testOversizedFileIsIgnored() {
        let big = Data(repeating: 0x20, count: UsageHistory.maxFileBytes + 1)
        XCTAssertEqual(UsageHistory(decoding: big).days, [])
    }
}

final class AlertTrackerTests: XCTestCase {
    func testFirstReadingOnlySetsBaseline() {
        var t = AlertTracker()
        XCTAssertNil(t.update(window: 0, percent: 85))
    }

    func testAlertsWhenLevelRises() {
        var t = AlertTracker()
        XCTAssertNil(t.update(window: 0, percent: 10))
        XCTAssertNil(t.update(window: 0, percent: 69.4))
        XCTAssertEqual(t.update(window: 0, percent: 70), 70)
        XCTAssertNil(t.update(window: 0, percent: 75))
        XCTAssertEqual(t.update(window: 0, percent: 91), 90)
        XCTAssertEqual(t.update(window: 0, percent: 100), 100)
        XCTAssertNil(t.update(window: 0, percent: 100))
    }

    func testResetLetsItAlertAgain() {
        var t = AlertTracker()
        _ = t.update(window: 0, percent: 95)
        XCTAssertNil(t.update(window: 0, percent: 5))          // new window
        XCTAssertEqual(t.update(window: 0, percent: 72), 70)
    }

    func testWindowsAreIndependent() {
        var t = AlertTracker()
        _ = t.update(window: 0, percent: 10)
        _ = t.update(window: 1, percent: 10)
        XCTAssertEqual(t.update(window: 1, percent: 90), 90)
        XCTAssertNil(t.update(window: 0, percent: 10))
    }

    func testBadInputIsIgnored() {
        var t = AlertTracker()
        XCTAssertNil(t.update(window: 5, percent: 90))
        XCTAssertNil(t.update(window: 0, percent: .nan))
    }
}
