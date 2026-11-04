import os

enum Log {
    static let fetch = Logger(subsystem: AppPaths.bundleID, category: "fetch")
    static let refresh = Logger(subsystem: AppPaths.bundleID, category: "refresh")
}
