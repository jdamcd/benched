import Foundation

struct AppSettings: @unchecked Sendable {
    // @unchecked: UserDefaults is documented as thread-safe

    enum Key: String, CaseIterable {
        case backgroundRefreshMinutes
        case chosenClaudePath
        case menuBarMeter
    }

    static let backgroundChoices = [15, 30, 60]
    static let defaultBackgroundMinutes = 30
    static let defaultMenuBarMeter = MenuBarMeter.weekly

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // 0 means off
    var backgroundRefreshMinutes: Int {
        get {
            defaults.object(forKey: Key.backgroundRefreshMinutes.rawValue) as? Int ?? Self.defaultBackgroundMinutes
        }
        nonmutating set {
            defaults.set(newValue, forKey: Key.backgroundRefreshMinutes.rawValue)
        }
    }

    var menuBarMeter: MenuBarMeter {
        get {
            defaults.string(forKey: Key.menuBarMeter.rawValue).flatMap(MenuBarMeter.init(rawValue:)) ?? Self.defaultMenuBarMeter
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Key.menuBarMeter.rawValue)
        }
    }

    var chosenClaudePath: String? {
        get {
            defaults.string(forKey: Key.chosenClaudePath.rawValue)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Key.chosenClaudePath.rawValue)
        }
    }

    static func interval(minutes: Int) -> Duration? {
        // Each fetch is still a server request, so never more often than every 5 minutes
        minutes > 0 ? .seconds(max(minutes, 5) * 60) : nil
    }
}
