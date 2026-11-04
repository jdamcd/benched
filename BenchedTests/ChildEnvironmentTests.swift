@testable import Benched
import Foundation
import Testing

struct ChildEnvironmentTests {
    private let claude = URL(fileURLWithPath: "/Users/me/.local/bin/claude")
    private let resolved = URL(fileURLWithPath: "/Users/me/.local/share/claude/versions/2.1.317")

    @Test func fillsHomeWhenMissing() {
        let environment = make(parent: ["USER": "me"])
        #expect(environment["HOME"] == "/Users/me")
    }

    @Test func fillsHomeWhenEmpty() {
        let environment = make(parent: ["HOME": ""])
        #expect(environment["HOME"] == "/Users/me")
    }

    @Test func keepsInheritedHome() {
        let environment = make(parent: ["HOME": "/Users/other"])
        #expect(environment["HOME"] == "/Users/other")
    }

    @Test func dropsUnlistedVariables() {
        let environment = make(parent: [
            "ANTHROPIC_API_KEY": "sk-ant-123",
            "CLAUDE_CODE_OAUTH_TOKEN": "token",
            "NODE_OPTIONS": "--inspect",
            "PATH": "/somewhere/else",
        ])
        #expect(environment["ANTHROPIC_API_KEY"] == nil)
        #expect(environment["CLAUDE_CODE_OAUTH_TOKEN"] == nil)
        #expect(environment["NODE_OPTIONS"] == nil)
        #expect(environment["PATH"]?.contains("/somewhere/else") == false)
    }

    @Test func passesThroughProxiesLocaleAndConfig() {
        let parent = [
            "HTTPS_PROXY": "http://proxy:8080",
            "https_proxy": "http://proxy:8080",
            "NO_PROXY": "localhost",
            "NODE_EXTRA_CA_CERTS": "/etc/ca.pem",
            "LANG": "en_GB.UTF-8",
            "LC_ALL": "en_GB.UTF-8",
            "CLAUDE_CONFIG_DIR": "/Users/me/.claude-work",
        ]
        let environment = make(parent: parent)
        for (key, value) in parent {
            #expect(environment[key] == value)
        }
    }

    @Test func disablesAutoUpdates() {
        #expect(make(parent: [:])["DISABLE_AUTOUPDATER"] == "1")
    }

    @Test func pathPutsClaudeFirstWithoutDuplicates() {
        let path = make(parent: [:])["PATH"]
        #expect(path == [
            "/Users/me/.local/bin",
            "/Users/me/.local/share/claude/versions",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ].joined(separator: ":"))
    }

    @Test func pathIncludesNodeNextToNpmInstall() {
        let npm = URL(fileURLWithPath: "/Users/me/.nvm/versions/node/v22.1.0/bin/claude")
        let path = ChildEnvironment.path(home: "/Users/me", claude: npm, resolvedClaude: nil)
        #expect(path.hasPrefix("/Users/me/.nvm/versions/node/v22.1.0/bin:"))
    }

    private func make(parent: [String: String]) -> [String: String] {
        ChildEnvironment.make(parent: parent, home: "/Users/me", claude: claude, resolvedClaude: resolved)
    }
}
