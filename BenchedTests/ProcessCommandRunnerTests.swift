@testable import Benched
import Foundation
import Testing

struct ProcessCommandRunnerTests {
    private let runner = ProcessCommandRunner(killGrace: 0.5)

    @Test func capturesOutputAndExitCode() async throws {
        let output = try await runner.run(shell("echo out; echo err >&2; exit 3"))
        #expect(output.exitCode == 3)
        #expect(output.stdout == "out\n")
        #expect(output.stderr == "err\n")
        #expect(!output.timedOut)
        #expect(output.duration < .seconds(1))
    }

    @Test func stdinIsClosed() async throws {
        // cat would wait for input until the timeout if stdin were left open
        let output = try await runner.run(spec("/bin/cat", timeout: .seconds(5)))
        #expect(output.exitCode == 0)
        #expect(!output.timedOut)
    }

    @Test func passesOnlyTheGivenEnvironment() async throws {
        let output = try await runner.run(spec("/usr/bin/env", environment: ["FOO": "bar"]))
        #expect(output.stdout == "FOO=bar\n")
    }

    @Test func timesOut() async throws {
        let output = try await runner.run(spec("/bin/sleep", ["30"], timeout: .milliseconds(200)))
        #expect(output.timedOut)
        #expect(output.duration < .seconds(5))
    }

    @Test func killsAProcessThatIgnoresTerminate() async throws {
        // Ignored signals stay ignored across exec, so sleep ignores SIGTERM too
        let output = try await runner.run(shell("trap '' TERM; exec /bin/sleep 30", timeout: .milliseconds(200)))
        #expect(output.timedOut)
        #expect(output.exitCode == SIGKILL)
        #expect(output.duration < .seconds(5))
    }

    @Test func timeoutStopsWhatTheProcessStarted() async throws {
        // Like a version manager's shim that runs claude as a child rather than exec'ing it
        let output = try await runner.run(shell("/bin/sleep 30 & echo $!; wait", timeout: .milliseconds(200)))
        let child = try #require(pid_t(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)))
        let exited = await hasExited(child)
        if !exited {
            kill(child, SIGKILL)
        }
        #expect(output.timedOut)
        #expect(exited)
    }

    @Test func cancellingStopsTheProcess() async throws {
        let task = Task { try await runner.run(spec("/bin/sleep", ["30"])) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func missingExecutable() async {
        await #expect(throws: CommandError.notFound) {
            try await runner.run(spec("/nonexistent/claude"))
        }
    }

    @Test func capsStderrKeepingTheEnd() async throws {
        let output = try await runner.run(shell("head -c 200000 /dev/zero | tr '\\0' x >&2; printf END >&2"))
        #expect(output.stderr.utf8.count == 64 << 10)
        #expect(output.stderr.hasSuffix("xEND"))
    }

    // It can linger briefly as a zombie, so give it up to 2 s to be reaped
    private func hasExited(_ pid: pid_t) async -> Bool {
        for _ in 0 ..< 200 {
            if kill(pid, 0) != 0, errno == ESRCH { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    private func shell(_ script: String, timeout: Duration = .seconds(10)) -> CommandSpec {
        spec("/bin/sh", ["-c", script], timeout: timeout)
    }

    private func spec(
        _ path: String,
        _ arguments: [String] = [],
        environment: [String: String] = [:],
        timeout: Duration = .seconds(10),
    ) -> CommandSpec {
        CommandSpec(
            executable: URL(fileURLWithPath: path),
            arguments: arguments,
            environment: environment,
            currentDirectory: FileManager.default.temporaryDirectory,
            timeout: timeout,
        )
    }
}
