@testable import Benched
import Foundation
import Synchronization

final class FakeRunner: CommandRunner {
    enum Response: Sendable {
        case output(CommandOutput)
        case error(CommandError)
    }

    private let responses: Mutex<[Response]>
    private let recorded = Mutex<[CommandSpec]>([])

    init(_ responses: [Response]) {
        self.responses = Mutex(responses)
    }

    convenience init(fixture name: String) throws {
        let stdout = try Fixture.lines(name).joined(separator: "\n")
        self.init([.output(CommandOutput(exitCode: 0, stdout: stdout, stderr: ""))])
    }

    var calls: [CommandSpec] {
        recorded.withLock { $0 }
    }

    func run(_ command: CommandSpec) async throws -> CommandOutput {
        recorded.withLock { $0.append(command) }
        let response = responses.withLock { queue in
            queue.count > 1 ? queue.removeFirst() : queue[0]
        }
        switch response {
        case let .output(output): return output
        case let .error(error): throw error
        }
    }
}

struct FakeFileSystem: FileSystem {
    var executables: Set<String> = []
    var directories: [String: [String]] = [:]
    var symlinks: [String: String] = [:]

    func isExecutableFile(atPath path: String) -> Bool {
        executables.contains(path)
    }

    func contentsOfDirectory(atPath path: String) -> [String] {
        directories[path] ?? []
    }

    func resolvingSymlinks(_ url: URL) -> URL {
        symlinks[url.path].map { URL(fileURLWithPath: $0) } ?? url
    }
}

final class FakeSource: UsageSource {
    private let results: Mutex<[FetchResult]>
    private let count = Mutex(0)
    private let delay: Duration

    init(_ outcomes: [FetchOutcome], delay: Duration = .zero) {
        results = Mutex(outcomes.map { FetchResult(outcome: $0) })
        self.delay = delay
    }

    var fetchCount: Int {
        count.withLock { $0 }
    }

    func fetch() async -> FetchResult {
        count.withLock { $0 += 1 }
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return results.withLock { queue in
            queue.count > 1 ? queue.removeFirst() : queue[0]
        }
    }
}

@MainActor
final class FakeScheduler: RefreshScheduling {
    final class FakeTimer: RefreshTimer {
        let interval: Duration
        let action: @MainActor @Sendable () -> Void
        private(set) var isCancelled = false

        init(interval: Duration, action: @escaping @MainActor @Sendable () -> Void) {
            self.interval = interval
            self.action = action
        }

        func cancel() {
            isCancelled = true
        }
    }

    private(set) var timers: [FakeTimer] = []

    var active: [FakeTimer] {
        timers.filter { !$0.isCancelled }
    }

    func every(_ interval: Duration, _ action: @escaping @MainActor @Sendable () -> Void) -> any RefreshTimer {
        let timer = FakeTimer(interval: interval, action: action)
        timers.append(timer)
        return timer
    }

    func fire(_ interval: Duration) {
        for timer in active where timer.interval == interval {
            timer.action()
        }
    }
}

extension Meter {
    static func sample(
        _ kind: MeterKind = .session,
        percent: Double = 23,
        resetsAt: Date? = nil,
        severity: SeverityLevel? = .normal,
        isActive: Bool = false,
    ) -> Meter {
        Meter(kind: kind, percent: percent, resetsAt: resetsAt, severity: severity, isActive: isActive)
    }
}

extension UsageSnapshot {
    static func sample(_ meters: [Meter] = [.sample()], observedAt: Date = Date(timeIntervalSince1970: 1_793_700_000)) -> UsageSnapshot {
        UsageSnapshot(meters: meters, observedAt: observedAt)
    }
}

extension AppSettings {
    // A fixed suite per test suite, emptied for each test, so suites using
    // this need `.serialized`. A new name per test would leave a plist behind
    // every time: removing a domain empties its file but doesn't delete it.
    static func emptyForTesting(_ name: String) -> AppSettings {
        let suite = "\(AppPaths.bundleID).tests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppSettings(defaults: defaults)
    }
}

final class FakeCache: SnapshotCaching {
    private let stored: Mutex<UsageSnapshot?>
    private let saves = Mutex(0)

    init(_ snapshot: UsageSnapshot? = nil) {
        stored = Mutex(snapshot)
    }

    var saved: UsageSnapshot? {
        stored.withLock { $0 }
    }

    var saveCount: Int {
        saves.withLock { $0 }
    }

    func load() -> UsageSnapshot? {
        stored.withLock { $0 }
    }

    func save(_ snapshot: UsageSnapshot) {
        stored.withLock { $0 = snapshot }
        saves.withLock { $0 += 1 }
    }
}

final class FakeProbe: ClaudeProbing {
    private let path: String?
    private let count = Mutex(0)

    init(_ path: String?) {
        self.path = path
    }

    var callCount: Int {
        count.withLock { $0 }
    }

    func locate() async -> String? {
        count.withLock { $0 += 1 }
        return path
    }
}
