import Foundation

enum PercentText {
    static func make(_ percent: Double, locale: Locale = .current) -> String {
        (percent / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

enum MeterLabel {
    static func make(kind: MeterKind) -> String {
        switch kind {
        case .session: "Session"
        case .weeklyAll: "Weekly"
        default: humanised(kind.rawValue)
        }
    }

    static func humanised(_ raw: String) -> String {
        let words = raw.replacing("_", with: " ").trimmingCharacters(in: .whitespaces)
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

enum Countdown {
    static func short(until date: Date, now: Date) -> String? {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return nil }
        let days = seconds / 86400
        let hours = seconds % 86400 / 3600
        let minutes = seconds % 3600 / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "under a minute"
    }

    // For VoiceOver: "5 days, 21 hours"
    static func spoken(until date: Date, now: Date, locale: Locale = .current) -> String? {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        guard seconds >= 60 else { return "less than a minute" }
        // Truncated to the smallest unit shown, to match the short form
        let unit: TimeInterval = seconds >= 86400 ? 3600 : 60
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds >= 86400 ? [.day, .hour] : [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: (seconds / unit).rounded(.down) * unit)
    }
}

enum AccessibilityText {
    static func menuBar(meter: Meter?, now: Date) -> String {
        guard let meter else { return "Claude usage" }
        let label = MeterLabel.make(kind: meter.kind)
        if meter.hasReset(now: now) {
            return "Claude usage: \(label), reset"
        }
        let percent = PercentText.make(meter.percent)
        if let countdown = meter.resetsAt.flatMap({ Countdown.spoken(until: $0, now: now) }) {
            return "Claude usage: \(label), \(percent), resets in \(countdown)"
        }
        return "Claude usage: \(label), \(percent)"
    }

    static func meterRow(_ meter: Meter, now: Date, locale: Locale = .current) -> String {
        let label = MeterLabel.make(kind: meter.kind)
        let percent = PercentText.make(meter.percent, locale: locale)
        let level = switch meter.level {
        case .normal: ""
        case .warning: ", nearing the limit"
        case .critical: ", at or near the limit"
        }
        guard let resetsAt = meter.resetsAt else {
            return "\(label): \(percent) used\(level)"
        }
        guard let countdown = Countdown.spoken(until: resetsAt, now: now, locale: locale) else {
            return "\(label): reset"
        }
        return "\(label): \(percent) used\(level), resets in \(countdown)"
    }
}

enum ResetTime {
    static func absolute(_ date: Date, now: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        var style = Date.FormatStyle(locale: locale, timeZone: timeZone).hour().minute()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if !calendar.isDate(date, inSameDayAs: now) {
            style = style.weekday(.abbreviated)
        }
        return date.formatted(style)
    }
}

enum UpdatedText {
    static func make(since date: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "Updated \(hours) hr ago" }
        return "Updated \(hours / 24) d ago"
    }
}

struct ProblemText: Equatable {
    struct Link: Equatable {
        var title: String
        var url: URL
    }

    var title: String
    var detail: String
    var command: String?
    var link: Link?

    static func make(_ problem: Problem) -> ProblemText {
        switch problem {
        case .claudeNotFound:
            ProblemText(
                title: "Couldn't find Claude Code",
                detail: "Benched reads your usage from Claude Code. Install it and log in, then refresh.",
                link: Link(title: "Install Claude Code", url: URL(string: "https://code.claude.com/docs/en/setup")!),
            )
        case let .launchFailed(message):
            ProblemText(
                title: "Couldn't start Claude Code",
                detail: message,
            )
        case .timedOut:
            ProblemText(
                title: "Claude Code didn't respond",
                detail: "It took longer than \(UsageCommand.timeout.components.seconds) seconds. Benched will try again.",
            )
        case let .commandFailed(exitCode, stderrTail):
            ProblemText(
                title: "Claude Code exited with an error",
                detail: lastLine(of: stderrTail) ?? "Exit code \(exitCode)",
            )
        case .planUsageUnavailable:
            ProblemText(
                title: "Claude couldn't fetch plan usage right now",
                detail: "Claude Code is logged in, but the server didn't return usage. Benched will try again.",
            )
        case .reportMissing:
            ProblemText(
                title: "Claude Code changed how it reports usage",
                detail: "Check for an update to Benched.",
            )
        case .apiKeyAuth:
            ProblemText(
                title: "Claude Code is using an API key",
                detail: "Benched only shows Claude subscription limits, so it can't show usage for an API key.",
            )
        case .noSubscriptionUsage:
            ProblemText(
                title: "Claude Code didn't return plan usage",
                detail: "Log in to Claude Code with your Claude subscription. Tokens from claude setup-token and usage-based billing don't report limits.",
                command: loginCommand,
            )
        case .unrecognisedOutput:
            ProblemText(
                title: "Claude Code's output wasn't recognised",
                detail: "Check for an update to Benched.",
            )
        }
    }

    static let loginCommand = "claude auth login --claudeai"

    private static func lastLine(of text: String) -> String? {
        text.split(whereSeparator: \.isNewline).last.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
