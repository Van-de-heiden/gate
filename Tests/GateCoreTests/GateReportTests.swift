import XCTest
@testable import GateCore

final class GateReportTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 10))! }

    func testEmptyConsumptionSelectionMustNotRequestAllActivity() {
        XCTAssertFalse(GateReportScope.consumption.canRequest(applicationCount: 0, domainCount: 0))
        XCTAssertTrue(GateReportScope.consumption.canRequest(applicationCount: 1, domainCount: 0))
        XCTAssertTrue(GateReportScope.consumption.canRequest(applicationCount: 0, domainCount: 1))
        XCTAssertTrue(GateReportScope.allApps.canRequest(applicationCount: 0, domainCount: 0))
        XCTAssertNotEqual(GateReportScope.allApps.contextID, GateReportScope.consumption.contextID)
    }

    func testReportedTotalIsNotSummedAgainWithAppAndWebsiteBreakdowns() {
        var total = GateReportTimeline(ending: today, calendar: calendar)
        var selected = GateReportTimeline(ending: today, calendar: calendar)
        let overlapping = [GateReportItem(id: "browser", title: "Browser", isWebsite: false, seconds: 900),
                           GateReportItem(id: "website", title: "Website", isWebsite: true, seconds: 900)]
        total.record(date: today, seconds: 69 * 60, items: overlapping)
        selected.record(date: today, seconds: 22 * 60, items: overlapping)
        XCTAssertEqual(total.days.last?.seconds, 4140)
        XCTAssertEqual(selected.days.last?.seconds, 1320)
        XCTAssertEqual(selected.days.last?.items.count, 2)
    }

    func testNoReportDataIsDifferentFromReportedZero() {
        var timeline = GateReportTimeline(ending: today, calendar: calendar)
        XCTAssertNil(timeline.days.last?.seconds)
        timeline.record(date: today, seconds: 0, items: [])
        XCTAssertEqual(timeline.days.last?.seconds, 0)
        XCTAssertNil(timeline.days.first?.seconds)
    }

    func testInvalidOrOutOfWindowDurationsDoNotPolluteTheReport() {
        var timeline = GateReportTimeline(ending: today, calendar: calendar)
        for seconds in [Double.nan, .infinity, -60] { timeline.record(date: today, seconds: seconds, items: []) }
        timeline.record(date: calendar.date(byAdding: .day, value: -7, to: today)!, seconds: 3000, items: [])
        XCTAssertTrue(timeline.days.allSatisfy { $0.seconds == nil })
        timeline.record(date: today, seconds: 60, items: [])
        timeline.record(date: today, seconds: 90, items: [])
        XCTAssertEqual(timeline.days.last?.seconds, 150)
    }

    func testSevenLocalDaysRemainCorrectAcrossDaylightSavingChange() {
        let spring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
        let timeline = GateReportTimeline(ending: spring, calendar: calendar)
        XCTAssertEqual(timeline.days.count, 7)
        XCTAssertEqual(Set(timeline.days.map(\.id)).count, 7)
        XCTAssertEqual(timeline.interval.duration, 7 * 86400 - 3600, accuracy: 1)
        XCTAssertEqual(calendar.component(.hour, from: timeline.days.last!.id), 0)
        XCTAssertEqual(calendar.component(.day, from: timeline.interval.end), 30)
    }

    func testDurationFormattingDoesNotRoundUpUsageOrLoseHourRemainders() {
        XCTAssertEqual(GateReportDuration.text(59), "< 1 min")
        XCTAssertEqual(GateReportDuration.text(69 * 60 + 59), "1 h 9 min")
        XCTAssertEqual(GateReportDuration.text(330 * 60), "5 h 30 min")
        XCTAssertEqual(GateReportDuration.text(0), "0 h 0 min")
        XCTAssertEqual(GateReportDuration.minutes(.nan), 0)
        XCTAssertEqual(GateReportDuration.minutes(.infinity), 0)
    }
}
