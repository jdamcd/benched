@testable import Benched
import Foundation
import Testing

@Suite(.serialized)
struct AppSettingsTests {
    private let settings = AppSettings.emptyForTesting("settings")

    @Test func defaults() {
        #expect(settings.backgroundRefreshMinutes == 30)
        #expect(settings.menuBarMeter == .weekly)
        #expect(settings.chosenClaudePath == nil)
    }

    @Test func storesValues() {
        settings.backgroundRefreshMinutes = 0
        settings.chosenClaudePath = "/opt/claude"
        settings.menuBarMeter = .session
        #expect(settings.backgroundRefreshMinutes == 0)
        #expect(settings.chosenClaudePath == "/opt/claude")
        #expect(settings.menuBarMeter == .session)
    }

    @Test func unknownMenuBarMeterIsWeekly() {
        settings.defaults.set("monthly", forKey: AppSettings.Key.menuBarMeter.rawValue)
        #expect(settings.menuBarMeter == .weekly)
    }

    @Test(arguments: [(0, nil as Duration?), (15, .seconds(900)), (1, .seconds(300))])
    func interval(minutes: Int, expected: Duration?) {
        #expect(AppSettings.interval(minutes: minutes) == expected)
    }
}
