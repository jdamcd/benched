import SwiftUI

struct MeterRow: View {
    let meter: Meter
    let now: Date
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        let hasReset = meter.hasReset(now: now)
        let level = hasReset ? SeverityLevel.normal : meter.level
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(MeterLabel.make(kind: meter.kind))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                // Colour is never the only signal
                if let symbol = level.symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(level.tint)
                        .imageScale(.small)
                }
                // Orange text is hard to read on a light background, so the
                // symbol and bar carry the colour and the number stays primary
                Text(hasReset ? "—" : PercentText.make(meter.percent, locale: locale))
                    .monospacedDigit()
            }
            UsageBar(fraction: hasReset ? 0 : meter.percent / 100, tint: level.tint)
            if let resetsAt = meter.resetsAt {
                Text(resetText(resetsAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityText.meterRow(meter, now: now, locale: locale))
        .accessibilityIdentifier("meter-\(meter.kind.rawValue)")
    }

    private func resetText(_ resetsAt: Date) -> String {
        guard let countdown = Countdown.short(until: resetsAt, now: now) else {
            return "Reset"
        }
        let time = ResetTime.absolute(resetsAt, now: now, locale: locale, timeZone: timeZone)
        return "Resets in \(countdown) · \(time)"
    }
}

struct UsageBar: View {
    var fraction: Double
    var tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: fraction)
    }
}

extension Color {
    // The orange Claude Code uses for itself in the terminal (its theme's `claude` colour)
    static let claude = Color(red: 215 / 255, green: 119 / 255, blue: 87 / 255)
}

extension SeverityLevel {
    // A warning bar stays orange, because the warning symbol already marks it
    var tint: Color {
        switch self {
        case .normal, .warning: .claude
        case .critical: .red
        }
    }

    var symbol: String? {
        switch self {
        case .normal: nil
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }
}
