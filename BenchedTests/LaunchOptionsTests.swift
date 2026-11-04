@testable import Benched
import Testing

struct LaunchOptionsTests {
    // The guard only works if the test runner really sets this in the host app
    @Test func detectsThisTestRun() {
        #expect(LaunchOptions.current.isHostingUnitTests)
    }

    @Test func normalLaunch() {
        let options = LaunchOptions(arguments: ["Benched"], environment: [:])
        #expect(!options.isHostingUnitTests)
        #expect(!options.showPopover)
    }

    @Test func fixtureArgument() {
        let options = LaunchOptions(arguments: ["Benched", "--show-popover", "--fixture", "/tmp/a.jsonl"], environment: [:])
        #expect(options.fixturePath == "/tmp/a.jsonl")
    }

    @Test func fixtureArgumentWithoutPath() {
        #expect(LaunchOptions(arguments: ["Benched", "--fixture"], environment: [:]).fixturePath == nil)
    }

    @Test func showPopoverArgument() {
        let options = LaunchOptions(arguments: ["Benched", "--show-popover"], environment: [:])
        #expect(options.showPopover)
    }
}
