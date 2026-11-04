import Foundation

@MainActor
protocol RefreshTimer: AnyObject {
    func cancel()
}

@MainActor
protocol RefreshScheduling {
    func every(_ interval: Duration, _ action: @escaping @MainActor @Sendable () -> Void) -> any RefreshTimer
}

struct TimerScheduler: RefreshScheduling {
    func every(_ interval: Duration, _ action: @escaping @MainActor @Sendable () -> Void) -> any RefreshTimer {
        let seconds = interval / .seconds(1)
        let timer = Timer(timeInterval: seconds, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        timer.tolerance = seconds / 10
        // .common keeps it firing while a menu is open
        RunLoop.main.add(timer, forMode: .common)
        return FoundationTimer(timer)
    }
}

private final class FoundationTimer: RefreshTimer {
    private let timer: Timer

    init(_ timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}
