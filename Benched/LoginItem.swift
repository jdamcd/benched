import ServiceManagement

@MainActor
enum LoginItem {
    // Registers first, because the Login Items list only shows Benched once
    // it's registered
    static func addAndShow() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            Log.refresh.error("launch at login: \(error, privacy: .public)")
        }
        SMAppService.openSystemSettingsLoginItems()
    }
}
