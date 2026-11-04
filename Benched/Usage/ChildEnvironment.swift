import Foundation

// The environment `claude` runs with. It's an allowlist, not a passthrough:
// an inherited `ANTHROPIC_API_KEY` (from `launchctl setenv`, say) silently
// switches Claude Code to API-key auth, and the usage report disappears.
enum ChildEnvironment {
    static let passedThrough: Set<String> = [
        "HOME", "USER", "LOGNAME", "SHELL", "TMPDIR", "LANG", "__CF_USER_TEXT_ENCODING",
        "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "ALL_PROXY",
        "http_proxy", "https_proxy", "no_proxy", "all_proxy",
        "NODE_EXTRA_CA_CERTS", "SSL_CERT_FILE", "SSL_CERT_DIR",
        "CLAUDE_CONFIG_DIR",
    ]

    static func make(parent: [String: String], home: String, claude: URL, resolvedClaude: URL?) -> [String: String] {
        var environment = parent.filter { passedThrough.contains($0.key) || $0.key.hasPrefix("LC_") }
        // Without HOME, claude can't find its login and returns no report
        if environment["HOME"]?.isEmpty ?? true {
            environment["HOME"] = home
        }
        environment["PATH"] = path(home: environment["HOME"] ?? home, claude: claude, resolvedClaude: resolvedClaude)
        // Background refreshes shouldn't download or install Claude Code updates
        environment["DISABLE_AUTOUPDATER"] = "1"
        return environment
    }

    // npm installs are a `#!/usr/bin/env node` script, so node has to be
    // findable. It usually lives next to claude.
    static func path(home: String, claude: URL, resolvedClaude: URL?) -> String {
        let directories = [
            claude.deletingLastPathComponent().path,
            resolvedClaude?.deletingLastPathComponent().path,
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ].compactMap(\.self)
        var seen = Set<String>()
        return directories.filter { seen.insert($0).inserted }.joined(separator: ":")
    }
}
