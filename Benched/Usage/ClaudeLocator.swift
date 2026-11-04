import Foundation

protocol FileSystem: Sendable {
    func isExecutableFile(atPath path: String) -> Bool
    func contentsOfDirectory(atPath path: String) -> [String]
    func resolvingSymlinks(_ url: URL) -> URL
}

struct LocalFileSystem: FileSystem {
    func isExecutableFile(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: path)
    }

    func contentsOfDirectory(atPath path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    func resolvingSymlinks(_ url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }
}

// Finds `claude` without relying on PATH, which a Finder-launched app doesn't
// inherit from the user's shell.
struct ClaudeLocator: Sendable {
    let fileSystem: any FileSystem
    let home: String

    // The symlink path, never its resolved target: native installs keep the
    // binary in a versions/ folder that's deleted on a later update.
    func locate() -> URL? {
        candidates()
            .first { fileSystem.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    func candidates() -> [String] {
        [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "\(home)/.bun/bin/claude",
            "\(home)/.volta/bin/claude",
        ]
            + nvmCandidates()
            + [
                "\(home)/.local/share/mise/shims/claude",
                "\(home)/.asdf/shims/claude",
            ]
    }

    private func nvmCandidates() -> [String] {
        let root = "\(home)/.nvm/versions/node"
        return fileSystem.contentsOfDirectory(atPath: root)
            .sorted { Self.versionNumbers($0).lexicographicallyPrecedes(Self.versionNumbers($1)) }
            .reversed()
            .map { "\(root)/\($0)/bin/claude" }
    }

    private static func versionNumbers(_ name: String) -> [Int] {
        name.trimmingPrefix("v").split(separator: ".").map { Int($0) ?? 0 }
    }
}

protocol ClaudeProbing: Sendable {
    func locate() async -> String?
}

// For installs the known locations miss: a version manager, a custom npm prefix
struct LoginShellProbe: ClaudeProbing {
    // Interactive shells can print banners, so the answer is read between these
    static let sentinel = "__CCP__"

    var runner: any CommandRunner = ProcessCommandRunner()
    var shell = LoginShellProbe.userShell()
    var home = NSHomeDirectory()
    var parentEnvironment = ProcessInfo.processInfo.environment

    func locate() async -> String? {
        var environment = parentEnvironment.filter { ["USER", "LOGNAME", "TMPDIR", "LANG"].contains($0.key) || $0.key.hasPrefix("LC_") }
        environment["HOME"] = home
        environment["SHELL"] = shell
        // The login profile builds the real PATH from this
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        let sentinel = Self.sentinel
        let spec = CommandSpec(
            executable: URL(fileURLWithPath: shell),
            // Separate flags and `command -v`, which zsh, bash and fish all accept
            arguments: ["-i", "-l", "-c", "echo \(sentinel); command -v claude; echo \(sentinel)"],
            environment: environment,
            currentDirectory: URL(fileURLWithPath: home),
            timeout: .seconds(5),
        )
        guard let output = try? await runner.run(spec), !output.timedOut else { return nil }
        return Self.parse(output.stdout)
    }

    // An alias or a shell function prints something other than a path, and
    // isn't something we can run
    static func parse(_ stdout: String) -> String? {
        let parts = stdout.components(separatedBy: sentinel)
        guard parts.count >= 3 else { return nil }
        return parts[1]
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.hasPrefix("/") }
    }

    // From the user database, because a Finder-launched app may not have SHELL
    static func userShell() -> String {
        if let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell {
            let path = String(cString: shell)
            if !path.isEmpty { return path }
        }
        return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }
}
