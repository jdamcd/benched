@testable import Benched
import Foundation
import Testing

@Suite(.serialized)
@MainActor
struct UsageStoreTests {
    private let scheduler = FakeScheduler()
    private let clock = FakeClock()
    private let background = Duration.seconds(15 * 60)

    @Test func startFetchesAndSchedulesBackgroundRefresh() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source)

        store.start()
        await store.refresh().value

        #expect(source.fetchCount == 1)
        #expect(store.snapshot == .sample())
        #expect(scheduler.active.map(\.interval) == [background])
    }

    @Test func backgroundTimerFetches() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source)
        store.start()
        await store.refresh().value

        clock.advance(by: background)
        scheduler.fire(background)
        await store.refresh().value

        #expect(source.fetchCount == 2)
    }

    @Test func noBackgroundTimerWhenOff() async {
        let store = makeStore(FakeSource([.ready(.sample())]), backgroundMinutes: 0)
        store.start()
        await store.refresh().value
        #expect(scheduler.active.isEmpty)
    }

    @Test func openingThePopoverFetches() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source)

        store.popoverWillShow()
        await store.refresh().value

        #expect(source.fetchCount == 1)
    }

    @Test func triggerDuringFetchJoinsIt() async {
        let source = FakeSource([.ready(.sample())], delay: .milliseconds(100))
        let store = makeStore(source)

        let first = store.refresh()
        store.popoverWillShow()
        let second = store.refresh()
        #expect(store.isRefreshing)
        await first.value
        await second.value

        #expect(source.fetchCount == 1)
        #expect(!store.isRefreshing)
    }

    @Test func failureKeepsTheLastSnapshot() async {
        let source = FakeSource([.ready(.sample()), .problem(.timedOut)])
        let store = makeStore(source)

        await store.refresh().value
        clock.advance(by: UsageStore.throttleInterval)
        await store.refresh().value

        #expect(store.snapshot == .sample())
        #expect(store.problem == .timedOut)
    }

    @Test func successClearsTheProblem() async {
        let source = FakeSource([.problem(.timedOut), .ready(.sample())])
        let store = makeStore(source)

        await store.refresh().value
        #expect(store.snapshot == nil)
        #expect(store.problem == .timedOut)

        await store.refresh().value
        #expect(store.snapshot == .sample())
        #expect(store.problem == nil)
    }

    @Test func refreshesEveryMinuteOnlyWhileOpen() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source, backgroundMinutes: 0)

        store.popoverWillShow()
        await store.refresh().value
        #expect(scheduler.active.map(\.interval) == [.seconds(60)])

        clock.advance(by: .seconds(60))
        scheduler.fire(.seconds(60))
        await store.refresh().value
        #expect(source.fetchCount == 2)

        store.popoverDidClose()
        #expect(scheduler.active.isEmpty)
        scheduler.fire(.seconds(60))
        #expect(source.fetchCount == 2)
    }

    @Test func reopeningKeepsOneOpenTimer() async {
        let store = makeStore(FakeSource([.ready(.sample())]), backgroundMinutes: 0)
        store.popoverWillShow()
        store.popoverDidClose()
        store.popoverWillShow()
        await store.refresh().value
        #expect(scheduler.active.count == 1)
    }

    @Test func closingLeavesTheBackgroundTimer() async {
        let store = makeStore(FakeSource([.ready(.sample())]))
        store.start()
        store.popoverWillShow()
        store.popoverDidClose()
        await store.refresh().value
        #expect(scheduler.active.map(\.interval) == [background])
    }

    @Test func skipsRefreshWithin30SecondsOfASuccess() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source)
        await store.refresh().value

        clock.advance(by: .seconds(29))
        await store.refresh().value
        #expect(source.fetchCount == 1)

        clock.advance(by: .seconds(1))
        await store.refresh().value
        #expect(source.fetchCount == 2)
    }

    @Test func failureDoesNotHoldBackTheNextRefresh() async {
        let source = FakeSource([.problem(.timedOut)])
        let store = makeStore(source)
        await store.refresh().value
        await store.refresh().value
        #expect(source.fetchCount == 2)
    }

    @Test func openingThePopoverJustAfterAFetchOnlyStartsItsTimer() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source, backgroundMinutes: 0)
        await store.refresh().value

        store.popoverWillShow()
        await store.refresh().value

        #expect(source.fetchCount == 1)
        #expect(scheduler.active.map(\.interval) == [.seconds(60)])
    }

    @Test func wakeFetches() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source)
        store.didWake()
        await store.refresh().value
        #expect(source.fetchCount == 1)
    }

    @Test func firstLaunchShowsTheCache() {
        let cached = UsageSnapshot.sample([.sample(percent: 77)])
        let store = makeStore(FakeSource([.ready(.sample())]), cache: FakeCache(cached))
        #expect(store.snapshot == cached)
        #expect(store.isFromCache)
        #expect(store.popoverState == .usage(cached, problem: nil, isFromCache: true))
    }

    @Test func successReplacesAndSavesTheCache() async {
        let cache = FakeCache(.sample([.sample(percent: 77)]))
        let store = makeStore(FakeSource([.ready(.sample())]), cache: cache)
        await store.refresh().value
        #expect(store.snapshot == .sample())
        #expect(!store.isFromCache)
        #expect(cache.saved == .sample())
    }

    @Test func failureKeepsTheCacheOnScreen() async {
        let cached = UsageSnapshot.sample([.sample(percent: 77)])
        let cache = FakeCache(cached)
        let store = makeStore(FakeSource([.problem(.timedOut)]), cache: cache)
        await store.refresh().value
        #expect(store.popoverState == .usage(cached, problem: .timedOut, isFromCache: true))
        #expect(cache.saveCount == 0)
    }

    @Test func changingBackgroundRefreshReschedules() async {
        let store = makeStore(FakeSource([.ready(.sample())]))
        store.start()
        await store.refresh().value

        store.setBackgroundRefresh(minutes: 60)
        #expect(scheduler.active.map(\.interval) == [.seconds(3600)])
        #expect(settings.backgroundRefreshMinutes == 60)

        store.setBackgroundRefresh(minutes: 0)
        #expect(scheduler.active.isEmpty)
        #expect(store.backgroundRefreshMinutes == 0)
    }

    @Test func backgroundRefreshComesFromSettings() async {
        settings.backgroundRefreshMinutes = 60
        let store = makeStore(FakeSource([.ready(.sample())]), backgroundMinutes: nil)
        store.start()
        await store.refresh().value
        #expect(scheduler.active.map(\.interval) == [.seconds(3600)])
    }

    @Test func choosingTheMenuBarMeterSavesIt() {
        let store = makeStore(FakeSource([]))
        #expect(store.menuBarMeter == .weekly)
        store.setMenuBarMeter(.session)
        #expect(store.menuBarMeter == .session)
        #expect(settings.menuBarMeter == .session)
        #expect(makeStore(FakeSource([])).menuBarMeter == .session)
    }

    @Test func choosingClaudeSavesItAndRefreshes() async {
        let source = FakeSource([.ready(.sample())])
        let store = makeStore(source)

        await store.setChosenClaude(path: "/opt/claude").value
        #expect(settings.chosenClaudePath == "/opt/claude")
        #expect(store.chosenClaudePath == "/opt/claude")
        #expect(source.fetchCount == 1)

        await store.setChosenClaude(path: nil).value
        #expect(settings.chosenClaudePath == nil)
        #expect(store.chosenClaudePath == nil)
        #expect(source.fetchCount == 2)
    }

    @Test func choosingClaudeDuringAFetchFetchesAgain() async {
        let source = FakeSource([.ready(.sample())], delay: .milliseconds(100))
        let store = makeStore(source)

        let running = store.refresh()
        await store.setChosenClaude(path: "/opt/claude").value
        await running.value
        #expect(source.fetchCount == 2)

        clock.advance(by: UsageStore.throttleInterval)
        let next = store.refresh()
        await store.setChosenClaude(path: nil).value
        await next.value
        #expect(source.fetchCount == 4)
    }

    private let settings = AppSettings.emptyForTesting("store")

    private func makeStore(
        _ source: FakeSource,
        cache: FakeCache = FakeCache(),
        backgroundMinutes: Int? = 15,
    ) -> UsageStore {
        if let backgroundMinutes {
            settings.backgroundRefreshMinutes = backgroundMinutes
        }
        return UsageStore(source: source, scheduler: scheduler, cache: cache, settings: settings, now: { [clock] in clock.now })
    }
}
