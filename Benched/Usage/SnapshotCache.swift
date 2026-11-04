import Foundation

protocol SnapshotCaching: Sendable {
    func load() -> UsageSnapshot?
    func save(_ snapshot: UsageSnapshot)
}

// The last good snapshot, so the popover isn't empty for the first second
// after launch and a failed fetch still has numbers to show
struct FileSnapshotCache: SnapshotCaching {
    var url = AppPaths.supportDirectory.appending(path: "last-snapshot.json")

    func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(UsageSnapshot.self, from: data)
        } catch {
            // Written by an older or newer build. The next fetch replaces it.
            Log.refresh.notice("ignoring unreadable snapshot cache: \(error, privacy: .public)")
            return nil
        }
    }

    func save(_ snapshot: UsageSnapshot) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            Log.refresh.error("couldn't save snapshot cache: \(error, privacy: .public)")
        }
    }
}

struct NoSnapshotCache: SnapshotCaching {
    func load() -> UsageSnapshot? {
        nil
    }

    func save(_: UsageSnapshot) {}
}
