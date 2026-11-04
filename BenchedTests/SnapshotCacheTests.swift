@testable import Benched
import Foundation
import Testing

struct SnapshotCacheTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "benched-cache-\(UUID().uuidString)")

    @Test func roundTrip() throws {
        let cache = FileSnapshotCache(url: directory.appending(path: "last-snapshot.json"))
        let snapshot = UsageSnapshot(
            meters: [.sample(MeterKind(rawValue: "monthly_all"), percent: 41.5, resetsAt: Date(timeIntervalSince1970: 1_793_729_999), severity: .warning, isActive: true)],
            observedAt: Date(timeIntervalSince1970: 1_793_700_000),
            droppedRows: 1,
        )
        cache.save(snapshot)
        #expect(cache.load() == snapshot)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func missingFile() {
        #expect(FileSnapshotCache(url: directory.appending(path: "nothing.json")).load() == nil)
    }

    @Test func unreadableFile() throws {
        let url = directory.appending(path: "last-snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"meters": "not what we wrote"}"#.utf8).write(to: url)
        #expect(FileSnapshotCache(url: url).load() == nil)
        try? FileManager.default.removeItem(at: directory)
    }
}

struct FreshnessTests {
    private let now = Date(timeIntervalSince1970: 1_793_700_000)

    @Test func fresh() {
        #expect(Freshness.make(observedAt: now.addingTimeInterval(-120), problem: nil, isFromCache: false, now: now) == .fresh)
    }

    @Test func fromCache() {
        #expect(Freshness.make(observedAt: now.addingTimeInterval(-120), problem: nil, isFromCache: true, now: now) == .cached)
    }

    @Test func failedRefresh() {
        #expect(Freshness.make(observedAt: now.addingTimeInterval(-120), problem: .timedOut, isFromCache: true, now: now) == .stale)
    }

    @Test func overAnHourOld() {
        #expect(Freshness.make(observedAt: now.addingTimeInterval(-3601), problem: nil, isFromCache: false, now: now) == .stale)
    }

    @Test func hasReset() {
        #expect(Meter.sample(resetsAt: now).hasReset(now: now))
        #expect(!Meter.sample(resetsAt: now.addingTimeInterval(1)).hasReset(now: now))
        #expect(!Meter.sample(resetsAt: nil).hasReset(now: now))
    }
}
