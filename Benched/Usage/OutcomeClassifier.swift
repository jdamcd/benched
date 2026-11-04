import Foundation

// Logged out, API-key auth and a missing HOME all exit 0 with
// `subtype: "success"`, so neither of those can be trusted to report failure.
enum OutcomeClassifier {
    static func classify(output: CommandOutput, scan: StreamScan, now: Date) -> FetchOutcome {
        if output.timedOut {
            return .problem(.timedOut)
        }
        if output.exitCode != 0 {
            return .problem(.commandFailed(exitCode: output.exitCode, stderrTail: String(output.stderr.suffix(1000))))
        }

        if let report = scan.report {
            switch UsageReportDecoder.decode(report) {
            case .unavailable:
                return .problem(.planUsageUnavailable)
            case .unrecognised:
                return .problem(.reportMissing)
            case let .limits(meters, droppedRows) where meters.isEmpty && droppedRows > 0:
                // Every row failed to decode, so the row format has changed
                return .problem(.reportMissing)
            case let .limits(meters, droppedRows):
                return .ready(UsageSnapshot(meters: meters, observedAt: now, droppedRows: droppedRows))
            }
        }

        let text = scan.text ?? ""
        if text.contains("% used") {
            return .problem(.reportMissing)
        }
        if let source = scan.apiKeySource, source != "none" {
            return .problem(.apiKeyAuth(source: source))
        }
        if text.hasPrefix("Total cost:") {
            return .problem(.noSubscriptionUsage)
        }
        return .problem(.unrecognisedOutput)
    }
}
