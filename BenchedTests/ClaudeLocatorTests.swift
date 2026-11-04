@testable import Benched
import Foundation
import Testing

struct ClaudeLocatorTests {
    private let home = "/Users/me"

    @Test func nothingInstalled() {
        #expect(locate(FakeFileSystem()) == nil)
    }

    @Test func prefersNativeInstall() {
        let fileSystem = FakeFileSystem(executables: ["/opt/homebrew/bin/claude", "/Users/me/.local/bin/claude"])
        #expect(locate(fileSystem) == "/Users/me/.local/bin/claude")
    }

    @Test func fallsBackThroughKnownLocations() {
        let fileSystem = FakeFileSystem(executables: ["/Users/me/.bun/bin/claude"])
        #expect(locate(fileSystem) == "/Users/me/.bun/bin/claude")
    }

    @Test func newestNvmVersionFirst() {
        let root = "/Users/me/.nvm/versions/node"
        let fileSystem = FakeFileSystem(
            executables: ["\(root)/v9.11.2/bin/claude", "\(root)/v22.1.0/bin/claude", "\(root)/v20.18.3/bin/claude"],
            directories: [root: ["v9.11.2", "v22.1.0", "v20.18.3"]],
        )
        #expect(locate(fileSystem) == "\(root)/v22.1.0/bin/claude")
    }

    @Test func keepsTheSymlinkPath() {
        let fileSystem = FakeFileSystem(
            executables: ["/Users/me/.local/bin/claude"],
            symlinks: ["/Users/me/.local/bin/claude": "/Users/me/.local/share/claude/versions/2.1.317"],
        )
        #expect(locate(fileSystem) == "/Users/me/.local/bin/claude")
    }

    private func locate(_ fileSystem: FakeFileSystem) -> String? {
        ClaudeLocator(fileSystem: fileSystem, home: home).locate()?.path
    }
}
