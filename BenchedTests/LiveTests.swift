@testable import Benched
import Foundation
import Testing

// Runs the real `claude` on this Mac. Off unless asked for, because CI can't
// log in to Claude:
//
//     TEST_RUNNER_BENCHED_LIVE=1 xcodebuild test -project Benched.xcodeproj \
//         -scheme Benched -destination 'platform=macOS' -only-testing:BenchedTests/LiveTests
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BENCHED_LIVE"] == "1"))
struct LiveTests {
    @Test func fetchesRealUsage() async {
        let result = await UsageCommandSource().fetch()
        switch result.outcome {
        case let .ready(snapshot):
            #expect(!snapshot.meters.isEmpty)
            // Unreadable rows mean the format has changed, so it's time for a new fixture
            #expect(snapshot.droppedRows == 0)
        case let .problem(problem):
            // A classified problem means the pipeline works, but say why there's no data
            Issue.record("No usage: \(problem)")
        }
    }

    @Test func loginShellFindsClaude() async throws {
        let path = try #require(await LoginShellProbe().locate())
        #expect(FileManager.default.isExecutableFile(atPath: path))
    }
}
