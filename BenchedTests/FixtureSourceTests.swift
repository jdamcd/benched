@testable import Benched
import Foundation
import Testing

struct FixtureSourceTests {
    @Test func replaysTheNormalCapture() async throws {
        let result = try await FixtureSource(url: Fixture.url(Fixture.normal)).fetch()
        guard case let .ready(snapshot) = result.outcome else {
            Issue.record("Expected a snapshot, got \(result.outcome)")
            return
        }
        #expect(snapshot.meters.count == 2)
        #expect(result.claudePath == "fixture:2.1.317-normal.jsonl")
    }

    @Test func movesResetTimesToNow() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = try await FixtureSource(url: Fixture.url(Fixture.normal), now: { now }).fetch()
        guard case let .ready(snapshot) = result.outcome else {
            Issue.record("Expected a snapshot, got \(result.outcome)")
            return
        }
        let resetsAt = try #require(snapshot.meters.first?.resetsAt)
        // Captured at 14:03:48.731, with the session resetting at 18:19:59.623035
        #expect(abs(resetsAt.timeIntervalSince(now) - 15370.892035) < 0.001)
        #expect(snapshot.observedAt == now)
    }

    @Test func replaysAProblem() async throws {
        let result = try await FixtureSource(url: Fixture.url(Fixture.loggedOut)).fetch()
        #expect(result.outcome == .problem(.noSubscriptionUsage))
    }
}
