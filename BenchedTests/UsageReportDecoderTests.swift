@testable import Benched
import Foundation
import Testing

struct UsageReportDecoderTests {
    @Test func realCapture() throws {
        let scan = try StreamScanner.scan(Fixture.lines(Fixture.normal))
        let report = try #require(scan.report)
        guard case let .limits(meters, dropped) = UsageReportDecoder.decode(report) else {
            Issue.record("Expected limits")
            return
        }
        #expect(dropped == 0)
        #expect(meters.map(\.kind) == [.session, .weeklyAll])
        #expect(meters.map(\.percent) == [3, 4])
        #expect(meters.map(\.isActive) == [false, true])
        #expect(meters.map(\.severity) == [.normal, .normal])
        let resetsAt = try #require(meters[0].resetsAt)
        #expect(abs(resetsAt.timeIntervalSince1970 - 1_793_729_999.623035) < 0.001)
    }

    @Test func rateLimitsNull() {
        #expect(decode(#"{"rate_limits":null}"#) == .unavailable)
    }

    @Test func limitsNull() {
        #expect(decode(#"{"rate_limits":{"limits":null}}"#) == .unavailable)
    }

    @Test func limitsEmpty() {
        #expect(decode(#"{"rate_limits":{"limits":[]}}"#) == .limits(meters: [], droppedRows: 0))
    }

    @Test(arguments: [#"{}"#, #"{"rate_limits":{}}"#, #"{"rate_limits":{"limits":"none"}}"#, #"{"rate_limits":[]}"#])
    func unrecognisedShape(json: String) {
        #expect(decode(json) == .unrecognised)
    }

    @Test func unknownKind() throws {
        let meter = try decodeRow(#"{"kind":"monthly_all","percent":10}"#)
        #expect(meter.kind == MeterKind(rawValue: "monthly_all"))
        #expect(meter.kind.rawValue == "monthly_all")
    }

    @Test func unknownSeverityUsesLocalThresholds() throws {
        let meter = try decodeRow(#"{"kind":"session","percent":85,"severity":"dire"}"#)
        #expect(meter.severity == nil)
        #expect(meter.level == .warning)
    }

    @Test func missingSeverityAndActive() throws {
        let meter = try decodeRow(#"{"kind":"session","percent":96}"#)
        #expect(meter.severity == nil)
        #expect(meter.level == .critical)
        #expect(meter.isActive == false)
    }

    @Test func serverSeverityWins() throws {
        let meter = try decodeRow(#"{"kind":"session","percent":10,"severity":"critical"}"#)
        #expect(meter.level == .critical)
    }

    @Test(arguments: [
        (#""2026-11-03T18:19:59.699481+00:00""#, 1_793_729_999.699481),
        (#""2026-11-03T18:19:59.123Z""#, 1_793_729_999.123),
        (#""2026-11-03T18:19:59+00:00""#, 1_793_729_999),
        (#""2026-11-03T18:19:59Z""#, 1_793_729_999),
        (#""2026-11-03T13:19:59-05:00""#, 1_793_729_999),
    ])
    func resetsAt(json: String, expected: Double) throws {
        let meter = try decodeRow(#"{"kind":"session","percent":1,"resets_at":\#(json)}"#)
        let resetsAt = try #require(meter.resetsAt)
        #expect(abs(resetsAt.timeIntervalSince1970 - expected) < 0.001)
    }

    @Test(arguments: ["null", #""soon""#, "{}", "1793729999"])
    func resetsAtUnreadable(json: String) throws {
        let meter = try decodeRow(#"{"kind":"session","percent":1,"resets_at":\#(json)}"#)
        #expect(meter.resetsAt == nil)
    }

    @Test(arguments: [
        (#""percent":41.5"#, 41.5),
        (#""percent":104"#, 104),
    ])
    func percent(field: String, expected: Double) throws {
        let meter = try decodeRow(#"{"kind":"session",\#(field)}"#)
        #expect(abs(meter.percent - expected) < 0.0001)
    }

    @Test func badRowsAreDroppedAndCounted() {
        let decoded = decode(#"""
        {"rate_limits":{"limits":[
            {"kind":"session","percent":3},
            {"kind":"weekly_all"},
            "not a row",
            {"percent":5},
            {"kind":"weekly_all","percent":7}
        ]}}
        """#)
        guard case let .limits(meters, dropped) = decoded else {
            Issue.record("Expected limits")
            return
        }
        #expect(meters.map(\.kind) == [.session, .weeklyAll])
        #expect(dropped == 3)
    }

    @Test func scopedRowsAreLeftOutWithoutCountingAsDropped() {
        let decoded = decode(#"""
        {"rate_limits":{"limits":[
            {"kind":"session","percent":3,"scope":null},
            {"kind":"weekly_all","percent":4,"scope":{"model":null,"surface":null}},
            {"kind":"weekly_scoped","percent":3,"scope":{"model":{"display_name":"Fable"},"surface":null}},
            {"kind":"weekly_scoped","percent":3,"scope":null},
            {"kind":"monthly_scoped","percent":3,"scope":{"model":null,"surface":{"display_name":"Claude Code"}}}
        ]}}
        """#)
        #expect(decoded == .limits(meters: [
            Meter(kind: .session, percent: 3, resetsAt: nil, severity: nil, isActive: false),
            Meter(kind: .weeklyAll, percent: 4, resetsAt: nil, severity: nil, isActive: false),
        ], droppedRows: 0))
    }

    private func decode(_ json: String) -> DecodedReport {
        guard let report = JSONValue(jsonLine: json) else {
            Issue.record("Invalid test JSON: \(json)")
            return .unrecognised
        }
        return UsageReportDecoder.decode(report)
    }

    private func decodeRow(_ json: String) throws -> Meter {
        let row = try #require(JSONValue(jsonLine: json))
        return try #require(UsageReportDecoder.meter(from: row))
    }
}
