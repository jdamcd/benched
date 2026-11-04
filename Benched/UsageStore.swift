import Foundation
import Observation

@Observable
@MainActor
final class UsageStore {
    // A failed fetch leaves it in place
    private(set) var snapshot: UsageSnapshot?
    private(set) var problem: Problem?
    private(set) var isRefreshing = false
    private(set) var isFromCache = false
    private(set) var claudePath: String?
    private(set) var claudeVersion: String?
    private(set) var backgroundRefreshMinutes: Int
    private(set) var menuBarMeter: MenuBarMeter
    private(set) var chosenClaudePath: String?

    private let source: any UsageSource
    private let scheduler: any RefreshScheduling
    private let cache: any SnapshotCaching
    private let settings: AppSettings
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var backgroundTimer: (any RefreshTimer)?
    @ObservationIgnored private var openTimer: (any RefreshTimer)?
    // Usage moves slowly (a few percent an hour), so once a minute is plenty while someone's looking
    static let openInterval = Duration.seconds(60)

    init(
        source: any UsageSource,
        scheduler: any RefreshScheduling = TimerScheduler(),
        cache: any SnapshotCaching = NoSnapshotCache(),
        settings: AppSettings = AppSettings(),
    ) {
        self.source = source
        self.scheduler = scheduler
        self.cache = cache
        self.settings = settings
        backgroundRefreshMinutes = settings.backgroundRefreshMinutes
        menuBarMeter = settings.menuBarMeter
        chosenClaudePath = settings.chosenClaudePath
        if let cached = cache.load() {
            snapshot = cached
            isFromCache = true
        }
    }

    func start() {
        scheduleBackgroundRefresh()
        refresh()
    }

    func setBackgroundRefresh(minutes: Int) {
        settings.backgroundRefreshMinutes = minutes
        backgroundRefreshMinutes = minutes
        scheduleBackgroundRefresh()
    }

    func setMenuBarMeter(_ meter: MenuBarMeter) {
        settings.menuBarMeter = meter
        menuBarMeter = meter
    }

    // nil goes back to finding claude on its own
    @discardableResult
    func setChosenClaude(path: String?) -> Task<Void, Never> {
        settings.chosenClaudePath = path
        chosenClaudePath = path
        // A fetch that's already running uses the claude from before the
        // change, so joining it would show the old claude's result
        let running = inFlight
        return Task {
            await running?.value
            await refresh().value
        }
    }

    private func scheduleBackgroundRefresh() {
        backgroundTimer?.cancel()
        backgroundTimer = nil
        guard let interval = AppSettings.interval(minutes: backgroundRefreshMinutes) else { return }
        backgroundTimer = scheduler.every(interval) { [weak self] in
            Log.refresh.info("background refresh")
            self?.refresh()
        }
    }

    func popoverWillShow() {
        refresh()
        openTimer?.cancel()
        openTimer = scheduler.every(Self.openInterval) { [weak self] in
            self?.refresh()
        }
    }

    func popoverDidClose() {
        openTimer?.cancel()
        openTimer = nil
    }

    func didWake() {
        Log.refresh.info("refresh after wake")
        refresh()
    }

    // A trigger during a fetch joins it rather than starting another, so a
    // slow stale result can never overwrite a newer one
    @discardableResult
    func refresh() -> Task<Void, Never> {
        if let inFlight {
            return inFlight
        }
        isRefreshing = true
        let task = Task {
            let result = await source.fetch()
            apply(result)
            isRefreshing = false
            inFlight = nil
        }
        inFlight = task
        return task
    }

    private func apply(_ result: FetchResult) {
        claudePath = result.claudePath
        claudeVersion = result.claudeVersion
        switch result.outcome {
        case let .ready(snapshot):
            self.snapshot = snapshot
            problem = nil
            isFromCache = false
            cache.save(snapshot)
        case let .problem(problem):
            self.problem = problem
        }
    }
}

enum PopoverState: Equatable {
    case loading
    case usage(UsageSnapshot, problem: Problem? = nil, isFromCache: Bool = false)
    case problem(Problem)
}

extension UsageStore {
    var popoverState: PopoverState {
        if let snapshot { return .usage(snapshot, problem: problem, isFromCache: isFromCache) }
        if let problem { return .problem(problem) }
        return .loading
    }
}
