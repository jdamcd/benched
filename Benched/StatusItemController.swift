import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let store: UsageStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(store: UsageStore) {
        self.store = store
        super.init()

        let content = NSHostingController(rootView: PopoverView(
            store: store,
            chooseClaude: { [weak self] in self?.chooseClaude() },
            quit: { NSApp.terminate(nil) },
        ))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        popover.delegate = self

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.setAccessibilityIdentifier("statusItem")
        }

        observeStore()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Clicking a status item doesn't activate an LSUIElement app, so the popover won't become key on its own
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverWillShow(_: Notification) {
        store.popoverWillShow()
    }

    func popoverDidClose(_: Notification) {
        store.popoverDidClose()
    }

    private func chooseClaude() {
        // The panel takes focus, which would close the transient popover anyway
        popover.performClose(nil)
        if let path = ClaudePicker.choose() {
            store.setChosenClaude(path: path)
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    // Observations would be neater, but Swift 6.2.1 crashes compiling it here:
    // https://github.com/swiftlang/swift/issues/91702
    private func observeStore() {
        let label = withObservationTracking {
            MenuBarLabel.make(
                snapshot: store.snapshot,
                showing: store.menuBarMeter,
                problem: store.problem,
                isFromCache: store.isFromCache,
                now: .now,
            )
        } onChange: { [weak self] in
            // Called once, before the change lands, so re-render on the next turn and track again
            Task { @MainActor in self?.observeStore() }
        }
        render(label)
    }

    private func render(_ label: MenuBarLabel) {
        guard let button = statusItem.button else { return }
        Self.apply(label, to: button)
    }

    // Static so snapshot tests can render the label onto a plain button
    static func apply(_ label: MenuBarLabel, to button: NSButton) {
        button.image = switch label.icon {
        // Benched's own drawing, the same as the app icon's. SF Symbols aren't
        // allowed in app icons, so the icon couldn't have matched a symbol.
        case let .gauge(percent): NSImage(named: gaugeImageName(percent: percent))
        case .problem: NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        }
        button.imagePosition = .imageLeading

        if let text = label.text {
            // So the item doesn't change width as the number changes
            var attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular),
            ]
            if let color = textColor(for: label) {
                attributes[.foregroundColor] = color
            }
            // No leading space: the button already leaves 4pt between the image and the title
            button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
        } else {
            button.attributedTitle = NSAttributedString()
        }
        button.setAccessibilityLabel(label.accessibilityLabel)
    }

    // scripts/draw-gauge.py draws one for every 10%
    static func gaugeImageName(percent: Int) -> String {
        "MenuBarGauge-\(percent)"
    }

    // nil for normal, so the text follows the menu bar's own appearance
    private static func textColor(for label: MenuBarLabel) -> NSColor? {
        if label.isDimmed { return .secondaryLabelColor }
        return switch label.level {
        case .normal: nil
        case .warning: .systemOrange
        case .critical: .systemRed
        }
    }
}
