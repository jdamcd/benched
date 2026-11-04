#if DEBUG
    import Foundation

    // For UI tests, because neither CI nor a fresh Mac can log in to Claude
    struct FixtureSource: UsageSource {
        let url: URL
        var now: @Sendable () -> Date = Date.init

        func fetch() async -> FetchResult {
            let stdout = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let output = CommandOutput(exitCode: 0, stdout: stdout, stderr: "")
            let lines = output.stdoutLines
            let scan = StreamScanner.scan(lines)
            let now = now()
            var outcome = OutcomeClassifier.classify(output: output, scan: scan, now: now)
            // Otherwise the meters show as reset once the real clock passes
            // their captured reset times, so it replays as if captured just now
            if case var .ready(snapshot) = outcome, let capturedAt = Self.capturedAt(lines) {
                let elapsed = now.timeIntervalSince(capturedAt)
                for index in snapshot.meters.indices {
                    snapshot.meters[index].resetsAt?.addTimeInterval(elapsed)
                }
                outcome = .ready(snapshot)
            }
            return FetchResult(
                outcome: outcome,
                claudePath: "fixture:\(url.lastPathComponent)",
                claudeVersion: scan.claudeVersion,
            )
        }

        private static func capturedAt(_ lines: [String]) -> Date? {
            lines.lazy
                .compactMap { JSONValue(jsonLine: $0) }
                .first { $0["type"]?.stringValue == "assistant" }?["timestamp"]?.stringValue
                .flatMap { try? Date.ISO8601FormatStyle().parse($0) }
        }
    }
#endif
