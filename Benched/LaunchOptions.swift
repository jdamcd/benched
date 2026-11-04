import Foundation

struct LaunchOptions: Equatable {
    // The app hosts the unit tests, so without this check every test run
    // would put a status item in the menu bar and fetch usage for real.
    var isHostingUnitTests: Bool
    // XCUITest can't click a status item, so UI tests ask for the popover
    // to open on launch instead.
    var showPopover: Bool
    var fixturePath: String?

    init(arguments: [String], environment: [String: String]) {
        isHostingUnitTests = environment["XCTestConfigurationFilePath"] != nil
        showPopover = arguments.contains("--show-popover")
        if let index = arguments.firstIndex(of: "--fixture"), arguments.indices.contains(index + 1) {
            fixturePath = arguments[index + 1]
        }
    }

    static var current: LaunchOptions {
        LaunchOptions(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
        )
    }
}
