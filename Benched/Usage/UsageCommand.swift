import Foundation

struct UsageCommand: Sendable {
    static let requiredArguments = ["-p", "/usage", "--output-format", "stream-json", "--verbose"]
    // No session transcript left behind by every refresh, and no hooks or MCP
    // servers started
    static let optionalFlags = ["--no-session-persistence", "--safe-mode"]
    static let timeout = Duration.seconds(20)

    let runner: any CommandRunner

    func run(claude: URL, environment: [String: String], workingDirectory: URL) async throws -> CommandOutput {
        var dropped: Set<String> = []
        while true {
            let spec = CommandSpec(
                executable: claude,
                arguments: Self.requiredArguments + Self.optionalFlags.filter { !dropped.contains($0) },
                environment: environment,
                currentDirectory: workingDirectory,
                timeout: Self.timeout,
            )
            let output = try await runner.run(spec)
            guard output.exitCode != 0, !output.timedOut,
                  let flag = Self.rejectedFlag(in: output.stderr),
                  Self.optionalFlags.contains(flag), !dropped.contains(flag)
            else {
                return output
            }
            Log.fetch.notice("claude rejected \(flag, privacy: .public), retrying without it")
            dropped.insert(flag)
        }
    }

    static func rejectedFlag(in stderr: String) -> String? {
        stderr.firstMatch(of: /unknown option '(--[\w-]+)'/).map { String($0.1) }
    }
}
