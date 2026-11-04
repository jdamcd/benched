@testable import Benched
import Testing

struct StreamScannerTests {
    private static let report = #"{"rate_limits":{"limits":[{"kind":"session","percent":3}]}}"#

    @Test func realCapture() throws {
        let scan = try StreamScanner.scan(Fixture.lines(Fixture.normal))
        #expect(scan.claudeVersion == "2.1.317")
        #expect(scan.apiKeySource == "none")
        #expect(scan.report?["rate_limits"]?["limits"]?.arrayValue?.count == 3)
        #expect(scan.text?.hasPrefix("You are currently using your subscription") == true)
    }

    @Test(arguments: [Fixture.loggedOut, Fixture.apiKey, Fixture.noHome])
    func capturesWithoutReport(name: String) throws {
        let scan = try StreamScanner.scan(Fixture.lines(name))
        #expect(scan.report == nil)
        #expect(scan.text?.hasPrefix("Total cost:") == true)
    }

    @Test func apiKeySource() throws {
        let scan = try StreamScanner.scan(Fixture.lines(Fixture.apiKey))
        #expect(scan.apiKeySource == "ANTHROPIC_API_KEY")
    }

    @Test func skipsNonJSONLines() {
        let scan = StreamScanner.scan([
            "Warning: something on stdout",
            #"{"type":"assistant","usage_report":\#(Self.report)}"#,
        ])
        #expect(scan.report != nil)
    }

    @Test func truncatedLastLine() {
        let scan = StreamScanner.scan([
            #"{"type":"assistant","usage_report":\#(Self.report)}"#,
            #"{"type":"result","result":"Current sess"#,
        ])
        #expect(scan.report != nil)
    }

    @Test(arguments: [
        #"{"type":"result","usage_report":\#(StreamScannerTests.report)}"#,
        #"{"type":"assistant","message":{"usage_report":\#(StreamScannerTests.report)}}"#,
        #"{"type":"assistant","usage_report":null}"#,
    ])
    func readsTheReportOnlyFromTheAssistantMessage(line: String) {
        #expect(StreamScanner.scan([line]).report == nil)
    }

    @Test func emptyStream() {
        let scan = StreamScanner.scan([])
        #expect(scan == StreamScan())
    }

    @Test func prefersResultText() {
        let scan = StreamScanner.scan([
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"from assistant"}]}}"#,
            #"{"type":"result","result":"from result"}"#,
        ])
        #expect(scan.text == "from result")
    }

    @Test func fallsBackToAssistantText() {
        let scan = StreamScanner.scan([
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"from assistant"}]}}"#,
        ])
        #expect(scan.text == "from assistant")
    }
}
