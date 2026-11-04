import Foundation

protocol UsageSource: Sendable {
    // Never called while a fetch is running: UsageStore joins that one instead
    func fetch() async -> FetchResult
}

actor UsageCommandSource: UsageSource {
    private let runner: any CommandRunner
    private let fileSystem: any FileSystem
    private let probe: any ClaudeProbing
    private let chosenPath: @Sendable () -> String?
    private let parentEnvironment: [String: String]
    private let home: String
    private let workingDirectory: URL
    private let now: @Sendable () -> Date
    // The login shell's answer. It's slow, so it's asked once, and only when
    // the known locations come up empty.
    private var probedPath: String??

    init(
        runner: any CommandRunner = ProcessCommandRunner(),
        fileSystem: any FileSystem = LocalFileSystem(),
        probe: any ClaudeProbing = LoginShellProbe(),
        chosenPath: @escaping @Sendable () -> String? = { nil },
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory(),
        workingDirectory: URL = AppPaths.supportDirectory,
        now: @escaping @Sendable () -> Date = Date.init,
    ) {
        self.runner = runner
        self.fileSystem = fileSystem
        self.probe = probe
        self.chosenPath = chosenPath
        parentEnvironment = environment
        self.home = home
        self.workingDirectory = workingDirectory
        self.now = now
    }

    func fetch() async -> FetchResult {
        guard let claude = await locateClaude() else {
            return finish(.problem(.claudeNotFound), claude: nil)
        }

        let resolved = fileSystem.resolvingSymlinks(claude)
        try? FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        let environment = ChildEnvironment.make(
            parent: parentEnvironment,
            home: home,
            claude: claude,
            resolvedClaude: resolved,
        )

        do {
            let output = try await UsageCommand(runner: runner).run(
                claude: claude,
                environment: environment,
                workingDirectory: workingDirectory,
            )
            let scan = StreamScanner.scan(output.stdoutLines)
            let outcome = OutcomeClassifier.classify(output: output, scan: scan, now: now())
            return finish(outcome, claude: claude, version: scan.claudeVersion, duration: output.duration)
        } catch CommandError.notFound {
            return finish(.problem(.claudeNotFound), claude: claude)
        } catch let CommandError.launchFailed(message) {
            return finish(.problem(.launchFailed(message)), claude: claude)
        } catch {
            return finish(.problem(.launchFailed(String(describing: error))), claude: claude)
        }
    }

    // Checked again on every fetch, so a moved or reinstalled claude is found
    // again. Never the resolved symlink target, which an update deletes.
    private func locateClaude() async -> URL? {
        if let chosen = chosenPath() {
            if fileSystem.isExecutableFile(atPath: chosen) {
                return URL(fileURLWithPath: chosen)
            }
            Log.fetch.notice("chosen claude at \(chosen, privacy: .public) isn't executable, looking elsewhere")
        }
        if let known = ClaudeLocator(fileSystem: fileSystem, home: home).locate() {
            return known
        }
        if probedPath == nil {
            let found = await probe.locate()
            Log.fetch.info("login shell probe found \(found ?? "nothing", privacy: .public)")
            probedPath = .some(found)
        }
        if case let path?? = probedPath, fileSystem.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func finish(_ outcome: FetchOutcome, claude: URL?, version: String? = nil, duration: Duration? = nil) -> FetchResult {
        let versionText = version ?? "unknown version"
        let durationText = duration.map { String(format: "%.2fs", $0 / .seconds(1)) } ?? "-"
        switch outcome {
        case let .ready(snapshot):
            Log.fetch.info("\(versionText, privacy: .public): \(snapshot.meters.count) meters in \(durationText, privacy: .public)")
        case let .problem(problem):
            Log.fetch.error("\(versionText, privacy: .public): \(String(describing: problem), privacy: .public) in \(durationText, privacy: .public)")
        }
        return FetchResult(outcome: outcome, claudePath: claude?.path, claudeVersion: version)
    }
}
