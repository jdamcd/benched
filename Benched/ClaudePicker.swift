import AppKit

@MainActor
enum ClaudePicker {
    static func choose() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose claude"
        panel.message = "Choose the claude command that Benched should run."
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // Cocoa counts a symlink as an alias, so otherwise ~/.local/bin/claude
        // comes back as the versions/ binary that the next update deletes
        panel.resolvesAliases = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".local/bin")
        // An LSUIElement app isn't active, so without this the panel opens behind other windows
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            Log.fetch.notice("chosen file isn't executable: \(url.path, privacy: .public)")
            return nil
        }
        return url.path
    }
}
