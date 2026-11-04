import Foundation

struct UsageSnapshot: Sendable, Codable, Equatable {
    // In the server's order
    var meters: [Meter]
    var observedAt: Date
    var droppedRows = 0
}

extension UsageSnapshot {
    func headline(preferring kind: MeterKind) -> Meter? {
        meters.first { $0.kind == kind } ?? meters.first(where: \.isActive) ?? meters.first
    }
}

enum MenuBarMeter: String, CaseIterable, Sendable {
    case session
    case weekly

    var kind: MeterKind {
        switch self {
        case .session: .session
        case .weekly: .weeklyAll
        }
    }
}

enum Freshness: Sendable, Equatable {
    case fresh
    case cached
    case stale

    static let staleAfter: TimeInterval = 3600

    static func make(observedAt: Date, problem: Problem?, isFromCache: Bool, now: Date) -> Freshness {
        if problem != nil { return .stale }
        if isFromCache { return .cached }
        return now.timeIntervalSince(observedAt) > staleAfter ? .stale : .fresh
    }
}

struct Meter: Sendable, Codable, Equatable {
    var kind: MeterKind
    // 0 to 100, but not clamped: the server can report more than 100
    var percent: Double
    var resetsAt: Date?
    var severity: SeverityLevel?
    var isActive: Bool

    func hasReset(now: Date) -> Bool {
        resetsAt.map { $0 <= now } ?? false
    }

    var level: SeverityLevel {
        severity ?? SeverityLevel(percent: percent)
    }
}

// The server's own string, so a kind added later still shows, with its name humanised
struct MeterKind: RawRepresentable, Sendable, Hashable, Codable {
    let rawValue: String

    static let session = MeterKind(rawValue: "session")
    static let weeklyAll = MeterKind(rawValue: "weekly_all")
}

// The raw values are the server's `severity` strings
enum SeverityLevel: String, Sendable, Codable {
    case normal
    case warning
    case critical

    init(percent: Double) {
        if percent >= 95 {
            self = .critical
        } else if percent >= 80 {
            self = .warning
        } else {
            self = .normal
        }
    }
}

enum Problem: Sendable, Equatable {
    case claudeNotFound
    case launchFailed(String)
    case timedOut
    case commandFailed(exitCode: Int32, stderrTail: String)
    case planUsageUnavailable
    // The output looks like a usage report, but not one we can read
    case reportMissing
    case apiKeyAuth(source: String)
    // Logged out, a `setup-token` token, or usage-based billing
    case noSubscriptionUsage
    // No payload: every problem is logged `.public`, and this output can hold
    // private details. scripts/capture-fixture.sh shows what claude printed.
    case unrecognisedOutput
}

enum FetchOutcome: Sendable, Equatable {
    case ready(UsageSnapshot)
    case problem(Problem)
}

struct FetchResult: Sendable, Equatable {
    var outcome: FetchOutcome
    var claudePath: String?
    var claudeVersion: String?
}
