import Foundation

enum AppPaths {
    static let bundleID = "com.jdamcd.benched"

    // Also claude's working directory. A fixed one means no project settings
    // apply, and Claude Code keeps one projects/ entry for it, not one per run.
    static var supportDirectory: URL {
        URL.applicationSupportDirectory.appending(path: bundleID, directoryHint: .isDirectory)
    }
}
