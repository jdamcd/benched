@testable import Benched
import Foundation
import Testing

struct OutcomeClassifierTests {
    private let now = Date(timeIntervalSince1970: 1_793_700_000)

    @Test func realCapture() throws {
        let outcome = try classifyFixture(Fixture.normal)
        guard case let .ready(snapshot) = outcome else {
            Issue.record("Expected a snapshot, got \(outcome)")
            return
        }
        #expect(snapshot.meters.count == 2)
        #expect(snapshot.observedAt == now)
        #expect(snapshot.droppedRows == 0)
    }

    @Test func loggedOut() throws {
        #expect(try classifyFixture(Fixture.loggedOut) == .problem(.noSubscriptionUsage))
    }

    @Test func apiKey() throws {
        #expect(try classifyFixture(Fixture.apiKey) == .problem(.apiKeyAuth(source: "ANTHROPIC_API_KEY")))
    }

    @Test func noHome() throws {
        #expect(try classifyFixture(Fixture.noHome) == .problem(.noSubscriptionUsage))
    }

    @Test func textReportWithoutStructuredReport() {
        let outcome = classify([
            #"{"type":"system","subtype":"init","apiKeySource":"none"}"#,
            #"{"type":"result","subtype":"success","result":"Current session: 3% used · resets Nov 3 at 1:19pm"}"#,
        ])
        #expect(outcome == .problem(.reportMissing))
    }

    @Test func rateLimitsNull() {
        let outcome = classify([#"{"type":"assistant","usage_report":{"rate_limits":null}}"#])
        #expect(outcome == .problem(.planUsageUnavailable))
    }

    @Test func emptyLimitsIsReady() {
        let outcome = classify([#"{"type":"assistant","usage_report":{"rate_limits":{"limits":[]}}}"#])
        guard case let .ready(snapshot) = outcome else {
            Issue.record("Expected a snapshot, got \(outcome)")
            return
        }
        #expect(snapshot.meters.isEmpty)
    }

    @Test func everyRowUnreadable() {
        let outcome = classify([#"{"type":"assistant","usage_report":{"rate_limits":{"limits":[{"kind":"session","pct":3}]}}}"#])
        #expect(outcome == .problem(.reportMissing))
    }

    @Test func someRowsUnreadable() {
        let outcome = classify([#"{"type":"assistant","usage_report":{"rate_limits":{"limits":[{"kind":"session","percent":3},{"kind":"weekly_all"}]}}}"#])
        guard case let .ready(snapshot) = outcome else {
            Issue.record("Expected a snapshot, got \(outcome)")
            return
        }
        #expect(snapshot.droppedRows == 1)
    }

    @Test func timedOut() {
        let output = CommandOutput(exitCode: 15, stdout: "", stderr: "", timedOut: true)
        #expect(OutcomeClassifier.classify(output: output, scan: StreamScan(), now: now) == .problem(.timedOut))
    }

    @Test func nonZeroExit() {
        let output = CommandOutput(exitCode: 127, stdout: "", stderr: "env: node: No such file or directory\n")
        let outcome = OutcomeClassifier.classify(output: output, scan: StreamScan(), now: now)
        #expect(outcome == .problem(.commandFailed(exitCode: 127, stderrTail: "env: node: No such file or directory\n")))
    }

    @Test func unrecognisedOutput() {
        let outcome = classify([#"{"type":"result","result":"Something new"}"#])
        #expect(outcome == .problem(.unrecognisedOutput))
    }

    @Test func noJSONAtAll() {
        let output = CommandOutput(exitCode: 0, stdout: "plain text output", stderr: "")
        let scan = StreamScanner.scan(output.stdoutLines)
        let outcome = OutcomeClassifier.classify(output: output, scan: scan, now: now)
        #expect(outcome == .problem(.unrecognisedOutput))
    }

    private func classifyFixture(_ name: String) throws -> FetchOutcome {
        try classify(Fixture.lines(name))
    }

    private func classify(_ lines: [String]) -> FetchOutcome {
        let output = CommandOutput(exitCode: 0, stdout: lines.joined(separator: "\n"), stderr: "")
        return OutcomeClassifier.classify(output: output, scan: StreamScanner.scan(lines), now: now)
    }
}
