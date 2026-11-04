import AppKit
@testable import Benched
import SwiftUI
import XCTest

final class PopoverSnapshotTests: SnapshotTestCase {
    func testNormal() {
        assertSnapshots(of: popover(.usage(PreviewData.normal, problem: nil)))
    }

    func testWarningAndCritical() {
        assertSnapshots(of: popover(.usage(PreviewData.warningAndCritical, problem: nil)))
    }

    func testOverLimit() {
        assertSnapshots(of: popover(.usage(PreviewData.overLimit, problem: nil)))
    }

    func testManyRowsAndLongLabels() {
        assertSnapshots(of: popover(.usage(PreviewData.manyRows, problem: nil)))
    }

    func testEmptyLimits() {
        assertSnapshots(of: popover(.usage(PreviewData.empty, problem: nil)))
    }

    func testRowsDropped() {
        assertSnapshots(of: popover(.usage(PreviewData.rowsDropped, problem: nil)))
    }

    func testLoading() {
        assertSnapshots(of: popover(.loading))
    }

    func testFromCache() {
        assertSnapshots(of: popover(.usage(PreviewData.normal, isFromCache: true)))
    }

    func testOverAnHourOld() {
        assertSnapshots(of: popover(.usage(PreviewData.snapshot(PreviewData.normal.meters, observedAt: PreviewData.now.addingTimeInterval(-3 * 3600)))))
    }

    func testMeterPastItsReset() {
        let meters = [
            PreviewData.meter(.session, percent: 96, resetsIn: -120, severity: .critical, isActive: true),
            PreviewData.meter(.weeklyAll, percent: 41, resetsIn: 2 * 86400),
        ]
        assertSnapshots(of: popover(.usage(PreviewData.snapshot(meters))))
    }

    func testMenuBarLabels() {
        let labels: [(String, MenuBarLabel)] = [
            ("normal", MenuBarLabel.make(snapshot: PreviewData.normal, showing: .session, problem: nil, now: PreviewData.now)),
            ("critical", MenuBarLabel.make(snapshot: PreviewData.warningAndCritical, showing: .session, problem: nil, now: PreviewData.now)),
            ("warning", MenuBarLabel(icon: .gauge(percent: 80), text: "83%", level: .warning, isDimmed: false, accessibilityLabel: "")),
            ("dimmed", MenuBarLabel.make(snapshot: PreviewData.normal, showing: .session, problem: .timedOut, now: PreviewData.now)),
            ("loading", MenuBarLabel.make(snapshot: nil, showing: .session, problem: nil, now: PreviewData.now)),
        ]
        for (name, label) in labels {
            assertSnapshots(of: {
                let button = NSButton(title: "", target: nil, action: nil)
                button.isBordered = false
                StatusItemController.apply(label, to: button)
                button.sizeToFit()
                return button
            }, testName: "testMenuBarLabel_\(name)")
        }
    }

    private func popover(_ state: PopoverState, isRefreshing: Bool = false) -> some View {
        PopoverContent(state: state, isRefreshing: isRefreshing, now: PreviewData.now)
    }
}

final class ProblemSnapshotTests: SnapshotTestCase {
    func testClaudeNotFound() {
        assertSnapshots(of: problem(.claudeNotFound))
    }

    func testLaunchFailed() {
        assertSnapshots(of: problem(.launchFailed("The file “claude” couldn’t be opened because you don’t have permission to view it.")))
    }

    func testTimedOut() {
        assertSnapshots(of: problem(.timedOut))
    }

    func testCommandFailed() {
        assertSnapshots(of: problem(.commandFailed(exitCode: 127, stderrTail: "env: node: No such file or directory\n")))
    }

    func testPlanUsageUnavailable() {
        assertSnapshots(of: problem(.planUsageUnavailable))
    }

    func testReportMissing() {
        assertSnapshots(of: problem(.reportMissing))
    }

    func testApiKeyAuth() {
        assertSnapshots(of: problem(.apiKeyAuth(source: "ANTHROPIC_API_KEY")))
    }

    func testNoSubscriptionUsage() {
        assertSnapshots(of: problem(.noSubscriptionUsage))
    }

    func testUnrecognisedOutput() {
        assertSnapshots(of: problem(.unrecognisedOutput))
    }

    func testBannerOverCachedData() {
        assertSnapshots(of: PopoverContent(state: .usage(PreviewData.normal, problem: .timedOut), isRefreshing: false, now: PreviewData.now))
    }

    func testBannerWithCommand() {
        assertSnapshots(of: PopoverContent(state: .usage(PreviewData.normal, problem: .noSubscriptionUsage), isRefreshing: false, now: PreviewData.now))
    }

    private func problem(_ problem: Problem) -> some View {
        PopoverContent(state: .problem(problem), isRefreshing: false, now: PreviewData.now)
    }
}
