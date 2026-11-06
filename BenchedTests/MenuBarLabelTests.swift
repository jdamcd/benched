import AppKit
@testable import Benched
import Testing

struct MenuBarLabelTests {
    private let now = Date(timeIntervalSince1970: 1_793_700_000)
    private let notReported = MeterKind(rawValue: "not_reported")

    @Test func headlineIsTheChosenMeter() {
        let snapshot = UsageSnapshot.sample([
            .sample(.session, percent: 90, isActive: true),
            .sample(.weeklyAll, percent: 4),
        ])
        #expect(snapshot.headline(preferring: .weeklyAll)?.kind == .weeklyAll)
        #expect(snapshot.headline(preferring: .session)?.kind == .session)
    }

    @Test func headlineIsTheActiveRow() {
        let snapshot = UsageSnapshot.sample([
            .sample(.session, percent: 90),
            .sample(.weeklyAll, percent: 4, isActive: true),
        ])
        #expect(snapshot.headline(preferring: notReported)?.kind == .weeklyAll)
    }

    @Test func headlineFallsBackToTheFirstRow() {
        let snapshot = UsageSnapshot.sample([
            .sample(.session, percent: 10),
            .sample(.weeklyAll, percent: 40, severity: .critical),
        ])
        #expect(snapshot.headline(preferring: notReported)?.kind == .session)
    }

    @Test func loading() {
        let label = MenuBarLabel.make(snapshot: nil, showing: .session, problem: nil, now: now)
        #expect(label.icon == .gauge(percent: 0))
        #expect(label.text == nil)
    }

    @Test func problemWithNoData() {
        let label = MenuBarLabel.make(snapshot: nil, showing: .session, problem: .timedOut, now: now)
        #expect(label.icon == .problem)
        #expect(label.text == nil)
    }

    @Test func showsHeadlinePercentAndLevel() {
        let snapshot = UsageSnapshot.sample([.sample(.session, percent: 96, severity: nil, isActive: true)])
        let label = MenuBarLabel.make(snapshot: snapshot, showing: .session, problem: nil, now: now)
        #expect(label.icon == .gauge(percent: 100))
        #expect(label.text == PercentText.make(96))
        #expect(label.level == .critical)
    }

    @Test(arguments: [(0.0, 0), (4, 0), (5, 10), (23, 20), (25, 30), (94.9, 90), (96, 100), (100, 100), (104, 100), (-1, 0)])
    func gaugeRoundsToTheNearest10(percent: Double, expected: Int) {
        #expect(MenuBarLabel.Icon.gauge(rounding: percent) == .gauge(percent: expected))
    }

    @MainActor
    @Test func everyGaugeIsDrawn() {
        for percent in stride(from: 0, through: 100, by: 10) {
            #expect(NSImage(named: StatusItemController.gaugeImageName(percent: percent)) != nil, "\(percent)%")
        }
    }

    @Test func showsTheChosenMeter() {
        let snapshot = UsageSnapshot.sample([
            .sample(.session, percent: 12, isActive: true),
            .sample(.weeklyAll, percent: 41),
        ])
        let weekly = MenuBarLabel.make(snapshot: snapshot, showing: .weekly, problem: nil, now: now)
        #expect(weekly.text == PercentText.make(41))
        #expect(weekly.icon == .gauge(percent: 40))
        #expect(weekly.accessibilityLabel.contains("Weekly"))
        let session = MenuBarLabel.make(snapshot: snapshot, showing: .session, problem: nil, now: now)
        #expect(session.text == PercentText.make(12))
        #expect(session.icon == .gauge(percent: 10))
    }

    @Test func failedRefreshKeepsTheNumber() {
        let snapshot = UsageSnapshot.sample([.sample(.session, percent: 41, isActive: true)])
        let label = MenuBarLabel.make(snapshot: snapshot, showing: .session, problem: .timedOut, now: now)
        #expect(label.icon == .gauge(percent: 40))
        #expect(label.text == PercentText.make(41))
    }

    @Test func noMetersShowsIconOnly() {
        let label = MenuBarLabel.make(snapshot: .sample([]), showing: .session, problem: nil, now: now)
        #expect(label.icon == .gauge(percent: 0))
        #expect(label.text == nil)
    }

    @Test func dashOnceTheHeadlineHasReset() {
        let snapshot = UsageSnapshot.sample([.sample(.session, percent: 96, resetsAt: now.addingTimeInterval(-60), isActive: true)], observedAt: now)
        let label = MenuBarLabel.make(snapshot: snapshot, showing: .session, problem: nil, now: now)
        #expect(label.text == "—")
        #expect(label.icon == .gauge(percent: 0))
        #expect(label.level == .normal)
        #expect(label.accessibilityLabel == "Claude usage: Session, reset")
    }
}
