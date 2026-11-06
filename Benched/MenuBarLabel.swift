import Foundation

struct MenuBarLabel: Sendable, Equatable {
    enum Icon: Sendable, Equatable {
        case gauge(percent: Int)
        case problem

        static func gauge(rounding percent: Double) -> Icon {
            .gauge(percent: Int((min(max(percent, 0), 100) / 10).rounded()) * 10)
        }
    }

    var icon: Icon
    var text: String?
    var level: SeverityLevel
    var accessibilityLabel: String

    // Shows the last good number even when it's old or the last fetch failed: the popover says which
    static func make(snapshot: UsageSnapshot?, showing meter: MenuBarMeter, problem: Problem?, now: Date) -> MenuBarLabel {
        if snapshot == nil, problem != nil {
            return MenuBarLabel(icon: .problem, level: .normal, accessibilityLabel: "Claude usage unavailable")
        }
        guard let meter = snapshot?.headline(preferring: meter.kind) else {
            return MenuBarLabel(icon: .gauge(percent: 0), level: .normal, accessibilityLabel: AccessibilityText.menuBar(meter: nil, now: now))
        }
        if meter.hasReset(now: now) {
            return MenuBarLabel(icon: .gauge(percent: 0), text: "—", level: .normal, accessibilityLabel: AccessibilityText.menuBar(meter: meter, now: now))
        }
        return MenuBarLabel(
            icon: .gauge(rounding: meter.percent),
            text: PercentText.make(meter.percent),
            level: meter.level,
            accessibilityLabel: AccessibilityText.menuBar(meter: meter, now: now),
        )
    }
}
