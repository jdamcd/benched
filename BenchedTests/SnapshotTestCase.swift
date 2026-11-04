import AppKit
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
class SnapshotTestCase: XCTestCase {
    private var windows: [NSWindow] = []
    private let strategy: Snapshotting<NSView, NSImage> = .image(precision: 0.8, perceptualPrecision: 0.9)
    private let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]

    override func invokeTest() {
        withSnapshotTesting(record: .missing) {
            super.invokeTest()
        }
    }

    func assertSnapshots(of view: some View, file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        let view = view
            .environment(\.locale, Locale(identifier: "en_GB"))
            .environment(\.timeZone, TimeZone(identifier: "UTC")!)
        for (name, appearance) in appearances {
            verify(host(view, appearance: appearance), named: name, file: file, testName: testName, line: line)
        }
    }

    func assertSnapshots(of makeView: () -> NSView, file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        for (name, appearance) in appearances {
            let view = makeView()
            view.appearance = NSAppearance(named: appearance)
            let container = NSView(frame: view.frame.insetBy(dx: -8, dy: -4).offsetBy(dx: 8, dy: 4))
            container.appearance = NSAppearance(named: appearance)
            container.wantsLayer = true
            container.addSubview(view)
            view.frame.origin = NSPoint(x: 8, y: 4)
            let window = ScaledWindow(contentRect: container.frame)
            window.contentView = container
            // Dynamic colours resolve against the current drawing appearance, not the view's
            NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
                container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            windows.append(window)
            verify(container, named: name, file: file, testName: testName, line: line)
        }
    }

    private func verify(_ view: NSView, named name: String, file: StaticString, testName: String, line: UInt) {
        let failure = verifySnapshot(
            of: view,
            as: strategy,
            named: name,
            snapshotDirectory: snapshotDirectory(for: file),
            file: file,
            testName: testName,
            line: line,
        )
        if let failure {
            XCTFail(failure, file: file, line: line)
        }
    }

    private func host(_ view: some View, appearance: NSAppearance.Name) -> NSView {
        let controller = NSHostingController(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        let window = ScaledWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 1000))
        window.contentViewController = controller
        controller.view.appearance = NSAppearance(named: appearance)
        controller.view.layoutSubtreeIfNeeded()
        controller.view.frame = NSRect(origin: .zero, size: controller.view.fittingSize)
        windows.append(window)
        return controller.view
    }

    // Outside BenchedTests/, because that folder is synchronized and every PNG
    // in it would be copied into the test bundle
    private func snapshotDirectory(for file: StaticString) -> String {
        let testFile = URL(fileURLWithPath: "\(file)")
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Snapshots")
            .appending(path: testFile.deletingPathExtension().lastPathComponent)
            .path
    }
}

// Forces 1x, so a Retina Mac and a CI runner produce the same pixels
private final class ScaledWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [], backing: .buffered, defer: false)
    }

    override var backingScaleFactor: CGFloat {
        1
    }
}
