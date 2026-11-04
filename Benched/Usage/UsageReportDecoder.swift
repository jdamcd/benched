import Foundation

enum DecodedReport: Sendable, Equatable {
    // `rate_limits` or `limits` was null: Claude Code couldn't get plan usage
    case unavailable
    // `limits` can be empty, when the server reports no meters for the plan
    case limits(meters: [Meter], droppedRows: Int)
    case unrecognised
}

// Reads a `usage_report` leniently: every field is optional, and a row that
// can't be read is dropped and counted rather than failing the whole report.
enum UsageReportDecoder {
    static func decode(_ report: JSONValue) -> DecodedReport {
        switch report["rate_limits"] {
        case .null: return .unavailable
        case let .object(rateLimits):
            switch rateLimits["limits"] {
            case .null: return .unavailable
            case let .array(rows):
                let overall = rows.filter { !isScoped($0) }
                let meters = overall.compactMap(meter)
                return .limits(meters: meters, droppedRows: overall.count - meters.count)
            default: return .unrecognised
            }
        default: return .unrecognised
        }
    }

    // Benched shows the overall limits only, not the per-model (Fable) or
    // per-surface breakdowns. They're left out rather than counted as unreadable.
    static func isScoped(_ row: JSONValue) -> Bool {
        if row["kind"]?.stringValue == "weekly_scoped" { return true }
        return row["scope"]?.objectValue?.values.contains { $0 != .null } ?? false
    }

    static func meter(from row: JSONValue) -> Meter? {
        guard let kind = row["kind"]?.stringValue, let percent = row["percent"]?.doubleValue else { return nil }
        return Meter(
            kind: MeterKind(rawValue: kind),
            percent: percent,
            // With or without fractional seconds, and with Z or an offset
            resetsAt: row["resets_at"]?.stringValue.flatMap { try? Date.ISO8601FormatStyle().parse($0) },
            severity: row["severity"]?.stringValue.flatMap(SeverityLevel.init(rawValue:)),
            isActive: row["is_active"]?.boolValue ?? false,
        )
    }
}
