@testable import Benched
import Foundation
import Testing

struct FormattingTests {
    private let now = Date(timeIntervalSince1970: 1_793_700_000)
    private let english = Locale(identifier: "en_US")

    @Test(arguments: [
        (0.0, "0%"),
        (41.0, "41%"),
        (41.6, "42%"),
        (104.0, "104%"),
    ])
    func percent(value: Double, expected: String) {
        #expect(PercentText.make(value, locale: english) == expected)
    }

    @Test(arguments: [
        (MeterKind.session, "Session"),
        (.weeklyAll, "Weekly"),
        (MeterKind(rawValue: "monthly_all"), "Monthly all"),
        (MeterKind(rawValue: "daily"), "Daily"),
    ])
    func meterLabel(kind: MeterKind, expected: String) {
        #expect(MeterLabel.make(kind: kind) == expected)
    }

    private static let minute: Double = 60
    private static let hour: Double = 3600
    private static let day: Double = 86400

    static let countdowns: [(Double, String?)] = [
        (-5, nil),
        (0, nil),
        (59, "under a minute"),
        (minute, "1m"),
        (59 * minute + 59, "59m"),
        (hour, "1h 0m"),
        (2 * hour + 14 * minute + 30, "2h 14m"),
        (24 * hour - 1, "23h 59m"),
        (24 * hour, "1d 0h"),
        (5 * day + 21 * hour + 59 * minute, "5d 21h"),
        (7 * day, "7d 0h"),
    ]

    @Test(arguments: countdowns)
    func countdown(seconds: Double, expected: String?) {
        #expect(Countdown.short(until: now.addingTimeInterval(seconds), now: now) == expected)
    }

    static let spokenCountdowns: [(Double, String?)] = [
        (-5, nil),
        (30, "less than a minute"),
        (minute, "1 minute"),
        (2 * hour + 14 * minute + 30, "2 hours, 14 minutes"),
        (hour, "1 hour"),
        (5 * day + 3 * hour + 59 * minute, "5 days, 3 hours"),
        (day, "1 day"),
    ]

    @Test(arguments: spokenCountdowns)
    func spokenCountdown(seconds: Double, expected: String?) {
        #expect(Countdown.spoken(until: now.addingTimeInterval(seconds), now: now, locale: english) == expected)
    }

    @Test func menuBarAccessibility() {
        let meter = Meter.sample(.weeklyAll, percent: 41, resetsAt: now.addingTimeInterval(5 * 86400 + 600))
        #expect(AccessibilityText.menuBar(meter: meter, now: now) == "Claude usage: Weekly, 41%, resets in 5 days")
    }

    @Test func menuBarAccessibilityWithoutReset() {
        let meter = Meter.sample(.session, percent: 3)
        #expect(AccessibilityText.menuBar(meter: meter, now: now) == "Claude usage: Session, 3%")
    }

    @Test func meterRowAccessibility() {
        let meter = Meter.sample(.weeklyAll, percent: 41, resetsAt: now.addingTimeInterval(5 * 86400 + 3 * 3600 + 120))
        #expect(AccessibilityText.meterRow(meter, now: now, locale: english) == "Weekly: 41% used, resets in 5 days, 3 hours")
    }

    @Test func meterRowAccessibilityNamesTheLevel() {
        let meter = Meter.sample(.session, percent: 96, resetsAt: now.addingTimeInterval(600), severity: .critical)
        #expect(AccessibilityText.meterRow(meter, now: now, locale: english) == "Session: 96% used, at or near the limit, resets in 10 minutes")
    }

    @Test func meterRowAccessibilityAfterReset() {
        let meter = Meter.sample(.session, percent: 96, resetsAt: now.addingTimeInterval(-60))
        #expect(AccessibilityText.meterRow(meter, now: now, locale: english) == "Session: reset")
    }

    @Test func resetTimeToday() {
        let date = now.addingTimeInterval(7 * 3600)
        #expect(ResetTime.absolute(date, now: now, locale: Locale(identifier: "en_GB"), timeZone: .gmt) == "17:00")
    }

    @Test func resetTimeTomorrowWithinADay() {
        let date = now.addingTimeInterval(15 * 3600)
        #expect(ResetTime.absolute(date, now: now, locale: Locale(identifier: "en_GB"), timeZone: .gmt) == "Wed 01:00")
    }

    @Test func resetTimeLaterInTheWeek() {
        let date = now.addingTimeInterval(4 * 86400 + 16 * 3600)
        #expect(ResetTime.absolute(date, now: now, locale: Locale(identifier: "en_GB"), timeZone: .gmt) == "Sun 02:00")
    }

    @Test func resetTimeFollowsTwelveHourLocale() {
        let date = now.addingTimeInterval(7 * 3600)
        #expect(ResetTime.absolute(date, now: now, locale: english, timeZone: .gmt) == "5:00\u{202F}PM")
    }

    static let updates: [(Double, String)] = [
        (0, "Updated just now"),
        (59, "Updated just now"),
        (minute, "Updated 1 min ago"),
        (23 * minute, "Updated 23 min ago"),
        (3 * hour + minute, "Updated 3 hr ago"),
        (2 * day, "Updated 2 d ago"),
        (-30, "Updated just now"),
    ]

    @Test(arguments: updates)
    func updated(secondsAgo: Double, expected: String) {
        #expect(UpdatedText.make(since: now.addingTimeInterval(-secondsAgo), now: now) == expected)
    }
}

struct ProblemTextTests {
    @Test func commandFailedShowsTheLastStderrLine() {
        let text = ProblemText.make(.commandFailed(exitCode: 1, stderrTail: "warning: something\nerror: unknown option '--verbose'\n"))
        #expect(text.detail == "error: unknown option '--verbose'")
    }

    @Test func commandFailedWithoutStderr() {
        #expect(ProblemText.make(.commandFailed(exitCode: 127, stderrTail: "")).detail == "Exit code 127")
    }

    @Test func noSubscriptionUsageOffersTheLoginCommand() {
        #expect(ProblemText.make(.noSubscriptionUsage).command == "claude auth login --claudeai")
    }

    @Test(arguments: [Problem.timedOut, .reportMissing, .planUsageUnavailable, .claudeNotFound, .apiKeyAuth(source: "ANTHROPIC_API_KEY")])
    func otherProblemsHaveNoCommand(problem: Problem) {
        #expect(ProblemText.make(problem).command == nil)
    }
}
