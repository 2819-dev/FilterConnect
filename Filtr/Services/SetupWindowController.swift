import AppKit
import SwiftUI

@MainActor
final class SetupWindowController {
    private var window: NSWindow?

    func present(store: FiltrStore) {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SetupFlowView(store: store) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Filtr"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}
