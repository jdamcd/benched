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
    var isDimmed: Bool
    var accessibilityLabel: String

    static func make(snapshot: UsageSnapshot?, showing meter: MenuBarMeter, problem: Problem?, isFromCache: Bool = false, now: Date) -> MenuBarLabel {
        guard let snapshot else {
            if problem != nil {
                return MenuBarLabel(
                    icon: .problem,
                    level: .normal,
                    isDimmed: false,
                    accessibilityLabel: "Claude usage unavailable",
                )
            }
            return MenuBarLabel(icon: .gauge(percent: 0), level: .normal, isDimmed: false, accessibilityLabel: AccessibilityText.menuBar(meter: nil, now: now))
        }
        let freshness = Freshness.make(observedAt: snapshot.observedAt, problem: problem, isFromCache: isFromCache, now: now)
        guard let meter = snapshot.headline(preferring: meter.kind) else {
            return MenuBarLabel(icon: .gauge(percent: 0), level: .normal, isDimmed: freshness != .fresh, accessibilityLabel: AccessibilityText.menuBar(meter: nil, now: now))
        }
        if meter.hasReset(now: now) {
            return MenuBarLabel(icon: .gauge(percent: 0), text: "—", level: .normal, isDimmed: true, accessibilityLabel: AccessibilityText.menuBar(meter: meter, now: now))
        }
        return MenuBarLabel(
            icon: .gauge(rounding: meter.percent),
            text: PercentText.make(meter.percent),
            level: meter.level,
            isDimmed: freshness != .fresh,
            accessibilityLabel: AccessibilityText.menuBar(meter: meter, now: now),
        )
    }
}
