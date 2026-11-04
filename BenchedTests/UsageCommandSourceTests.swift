@testable import Benched
import Foundation
import Testing

struct UsageCommandSourceTests {
    private let claudePath = "/Users/me/.local/bin/claude"

    @Test func fetchesAndClassifies() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        let result = await source(runner).fetch()
        guard case let .ready(snapshot) = result.outcome else {
            Issue.record("Expected a snapshot, got \(result.outcome)")
            return
        }
        #expect(snapshot.meters.count == 2)
        #expect(result.claudePath == claudePath)
        #expect(result.claudeVersion == "2.1.317")
    }

    @Test func runsTheRealCommandLine() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        _ = await source(runner).fetch()
        let spec = try #require(runner.calls.first)
        #expect(spec.executable.path == claudePath)
        #expect(spec.arguments == [
            "-p", "/usage", "--output-format", "stream-json", "--verbose",
            "--no-session-persistence", "--safe-mode",
        ])
        #expect(spec.environment["HOME"] == "/Users/me")
        #expect(spec.environment["ANTHROPIC_API_KEY"] == nil)
    }

    @Test func claudeNotFound() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        let probe = FakeProbe(nil)
        let source = source(runner, fileSystem: FakeFileSystem(), probe: probe)

        #expect(await source.fetch().outcome == .problem(.claudeNotFound))
        #expect(await source.fetch().outcome == .problem(.claudeNotFound))
        #expect(runner.calls.isEmpty)
        #expect(probe.callCount == 1)
    }

    @Test func usesTheLoginShellWhenKnownLocationsFail() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        let probe = FakeProbe("/Users/me/custom/bin/claude")
        let source = source(runner, fileSystem: FakeFileSystem(executables: ["/Users/me/custom/bin/claude"]), probe: probe)

        let result = await source.fetch()
        #expect(result.claudePath == "/Users/me/custom/bin/claude")
        _ = await source.fetch()
        #expect(runner.calls.map(\.executable.path) == ["/Users/me/custom/bin/claude", "/Users/me/custom/bin/claude"])
        #expect(probe.callCount == 1)
    }

    @Test func skipsTheLoginShellWhenAKnownLocationWorks() async throws {
        let probe = FakeProbe("/Users/me/custom/bin/claude")
        _ = try await source(FakeRunner(fixture: Fixture.normal), probe: probe).fetch()
        #expect(probe.callCount == 0)
    }

    @Test func ignoresAProbedPathThatIsntExecutable() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        let source = source(runner, fileSystem: FakeFileSystem(), probe: FakeProbe("/Users/me/gone/claude"))
        #expect(await source.fetch().outcome == .problem(.claudeNotFound))
        #expect(runner.calls.isEmpty)
    }

    @Test func chosenPathWins() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        let fileSystem = FakeFileSystem(executables: [claudePath, "/opt/claude"])
        _ = await source(runner, fileSystem: fileSystem, chosenPath: "/opt/claude").fetch()
        #expect(runner.calls.first?.executable.path == "/opt/claude")
    }

    @Test func chosenPathThatsGoneFallsBackToDetection() async throws {
        let runner = try FakeRunner(fixture: Fixture.normal)
        _ = await source(runner, chosenPath: "/opt/gone/claude").fetch()
        #expect(runner.calls.first?.executable.path == claudePath)
    }

    @Test func claudeDisappearsBeforeLaunch() async {
        let runner = FakeRunner([.error(.notFound)])
        #expect(await source(runner).fetch().outcome == .problem(.claudeNotFound))
    }

    @Test func launchFails() async {
        let runner = FakeRunner([.error(.launchFailed("Permission denied"))])
        #expect(await source(runner).fetch().outcome == .problem(.launchFailed("Permission denied")))
    }

    @Test func retriesWithoutRejectedOptionalFlag() async throws {
        let rejected = CommandOutput(exitCode: 1, stdout: "", stderr: "error: unknown option '--safe-mode'\n")
        let stdout = try Fixture.lines(Fixture.normal).joined(separator: "\n")
        let runner = FakeRunner([.output(rejected), .output(CommandOutput(exitCode: 0, stdout: stdout, stderr: ""))])
        let source = source(runner)

        let result = await source.fetch()
        guard case .ready = result.outcome else {
            Issue.record("Expected a snapshot, got \(result.outcome)")
            return
        }
        #expect(runner.calls.count == 2)
        #expect(runner.calls[1].arguments.contains("--safe-mode") == false)
        #expect(runner.calls[1].arguments.contains("--no-session-persistence"))
    }

    @Test func doesNotRetryRequiredFlag() async {
        let rejected = CommandOutput(exitCode: 1, stdout: "", stderr: "error: unknown option '--verbose'\n")
        let runner = FakeRunner([.output(rejected)])
        let result = await source(runner).fetch()
        #expect(result.outcome == .problem(.commandFailed(exitCode: 1, stderrTail: "error: unknown option '--verbose'\n")))
        #expect(runner.calls.count == 1)
    }

    private func source(
        _ runner: FakeRunner,
        fileSystem: FakeFileSystem? = nil,
        probe: FakeProbe = FakeProbe(nil),
        chosenPath: String? = nil,
    ) -> UsageCommandSource {
        UsageCommandSource(
            runner: runner,
            fileSystem: fileSystem ?? FakeFileSystem(executables: [claudePath]),
            probe: probe,
            chosenPath: { chosenPath },
            environment: ["ANTHROPIC_API_KEY": "sk-ant-123"],
            home: "/Users/me",
            workingDirectory: FileManager.default.temporaryDirectory.appending(path: "benched-tests"),
            now: { Date(timeIntervalSince1970: 1_793_700_000) },
        )
    }
}
