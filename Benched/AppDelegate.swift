import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore?
    private var statusItemController: StatusItemController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // NSApplication holds its delegate weakly
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        let options = LaunchOptions.current
        guard !options.isHostingUnitTests else { return }

        let (source, cache, settings) = Self.dependencies(for: options)
        let store = UsageStore(source: source, cache: cache, settings: settings)
        let controller = StatusItemController(store: store)
        self.store = store
        statusItemController = controller
        store.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main,
        ) { _ in
            MainActor.assumeIsolated { store.didWake() }
        }
        if options.showPopover {
            // Shown straight away, before the status item is in the menu bar, the popover doesn't appear
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                controller.showPopover()
            }
        }
    }

    private static func dependencies(for options: LaunchOptions) -> (any UsageSource, any SnapshotCaching, AppSettings) {
        #if DEBUG
            if let fixture = options.fixturePath {
                let suite = "\(AppPaths.bundleID).uitests"
                let defaults = UserDefaults(suiteName: suite)!
                defaults.removePersistentDomain(forName: suite)
                return (FixtureSource(url: URL(fileURLWithPath: fixture)), NoSnapshotCache(), AppSettings(defaults: defaults))
            }
        #endif
        let settings = AppSettings()
        let source = UsageCommandSource(chosenPath: { settings.chosenClaudePath })
        return (source, FileSnapshotCache(), settings)
    }
}
