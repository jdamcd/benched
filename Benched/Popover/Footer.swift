import SwiftUI

struct FooterMenuModel: Equatable {
    var claudePath: String?
    var claudeVersion: String?
    var backgroundRefreshMinutes = AppSettings.defaultBackgroundMinutes
    var menuBarMeter = AppSettings.defaultMenuBarMeter
    var hasChosenClaude = false
}

struct PopoverActions {
    var refresh: () -> Void = {}
    var setBackgroundRefresh: (Int) -> Void = { _ in }
    var setMenuBarMeter: (MenuBarMeter) -> Void = { _ in }
    var chooseClaude: () -> Void = {}
    var useDetectedClaude: () -> Void = {}
    var quit: () -> Void = {}
}

struct Footer: View {
    var updatedAt: Date?
    var isStale: Bool
    var isRefreshing: Bool
    var now: Date
    var menu: FooterMenuModel
    var actions: PopoverActions

    var body: some View {
        HStack(spacing: 12) {
            if let updatedAt {
                HStack(spacing: 4) {
                    // A symbol rather than orange text, which is hard to read on a light background
                    if isStale {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                    Text(UpdatedText.make(since: updatedAt, now: now))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .accessibilityElement(children: .combine)
                .accessibilityValue(isStale ? Text("May be out of date") : Text(""))
                .accessibilityIdentifier("updatedText")
            }
            Spacer()
            Button(action: actions.refresh) {
                // Both stay in the layout, so the footer doesn't shift when the spinner appears
                ZStack {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(isRefreshing ? 1 : 0)
                    Image(systemName: "arrow.clockwise")
                        .opacity(isRefreshing ? 0 : 1)
                }
            }
            .buttonStyle(.borderless)
            .disabled(isRefreshing)
            .help("Refresh")
            .accessibilityLabel("Refresh")
            .accessibilityIdentifier("refreshButton")
            FooterMenu(model: menu, actions: actions)
        }
    }
}

struct FooterMenu: View {
    var model: FooterMenuModel
    var actions: PopoverActions

    var body: some View {
        Menu {
            Text(claudeDescription)
            Divider()
            Picker("Menu bar shows", selection: Binding(
                get: { model.menuBarMeter },
                set: { actions.setMenuBarMeter($0) },
            )) {
                ForEach(MenuBarMeter.allCases, id: \.self) { meter in
                    Text(MeterLabel.make(kind: meter.kind)).tag(meter)
                }
            }
            Picker("Background refresh", selection: Binding(
                get: { model.backgroundRefreshMinutes },
                set: { actions.setBackgroundRefresh($0) },
            )) {
                ForEach(AppSettings.backgroundChoices, id: \.self) { minutes in
                    Text("Every \(minutes) min").tag(minutes)
                }
                Text("Off").tag(0)
            }
            Divider()
            Button("Launch at login…", action: LoginItem.addAndShow)
            Button("Choose claude…", action: actions.chooseClaude)
            if model.hasChosenClaude {
                Button("Use detected claude", action: actions.useDetectedClaude)
            }
            Divider()
            Button("Quit", action: actions.quit)
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More")
        .accessibilityIdentifier("moreMenu")
    }

    private var claudeDescription: String {
        guard let path = model.claudePath else { return "claude not found" }
        let display = (path as NSString).abbreviatingWithTildeInPath
        guard let version = model.claudeVersion else { return display }
        return "\(display) (\(version))"
    }
}
