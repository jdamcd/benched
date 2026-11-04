@testable import Benched
import Foundation
import Testing

struct LoginShellProbeTests {
    @Test func readsBetweenSentinels() {
        let stdout = "Last login: Mon Nov  2 on ttys001\nWelcome!\n__CCP__\n/Users/me/.volta/bin/claude\n__CCP__\nBye\n"
        #expect(LoginShellProbe.parse(stdout) == "/Users/me/.volta/bin/claude")
    }

    @Test func notFound() {
        #expect(LoginShellProbe.parse("__CCP__\n__CCP__\n") == nil)
    }

    @Test func aliasIsNotAPath() {
        #expect(LoginShellProbe.parse("__CCP__\nalias claude='npx claude'\n__CCP__\n") == nil)
    }

    @Test func missingClosingSentinel() {
        #expect(LoginShellProbe.parse("__CCP__\n/Users/me/.local/bin/claude\n") == nil)
    }

    @Test func runsAnInteractiveLoginShell() async throws {
        let runner = FakeRunner([.output(CommandOutput(exitCode: 0, stdout: "__CCP__\n/opt/claude\n__CCP__\n", stderr: ""))])
        let probe = LoginShellProbe(runner: runner, shell: "/bin/zsh", home: "/Users/me", parentEnvironment: ["ANTHROPIC_API_KEY": "x", "USER": "me"])

        #expect(await probe.locate() == "/opt/claude")
        let spec = try #require(runner.calls.first)
        #expect(spec.executable.path == "/bin/zsh")
        #expect(spec.arguments == ["-i", "-l", "-c", "echo __CCP__; command -v claude; echo __CCP__"])
        #expect(spec.environment == ["HOME": "/Users/me", "USER": "me", "SHELL": "/bin/zsh", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"])
        #expect(spec.timeout == .seconds(5))
    }

    @Test func timeoutFindsNothing() async {
        let runner = FakeRunner([.output(CommandOutput(exitCode: 15, stdout: "__CCP__\n", stderr: "", timedOut: true))])
        let probe = LoginShellProbe(runner: runner, shell: "/bin/zsh", home: "/Users/me", parentEnvironment: [:])
        #expect(await probe.locate() == nil)
    }
}
