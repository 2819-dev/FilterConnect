import AppKit
import Combine
import SwiftUI

/// Owns a small floating panel for the soft-limit nudge (in addition to the menu-bar popover).
@MainActor
final class SoftLimitPresenter: ObservableObject {
    private var panel: NSPanel?
    private var hosting: NSHostingView<SoftLimitView>?
    private weak var store: FiltrStore?
    private var cancellable: AnyCancellable?

    func attach(store: FiltrStore) {
        self.store = store
        cancellable = store.$softLimitCategory
            .receive(on: RunLoop.main)
            .sink { [weak self] category in
                self?.sync(category: category)
            }
    }

    private func sync(category: CategoryID?) {
        guard let store else { return }
        guard let category else {
            dismissPanel()
            return
        }
        let view = SoftLimitView(category: category, store: store, onClose: { [weak self] in
            self?.dismissPanel()
        })
        if let hosting {
            hosting.rootView = view
            panel?.orderFrontRegardless()
            return
        }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 360, height: 220)
        hosting = host

        let panel = NSPanel(
            contentRect: host.frame,
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Filtr"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = host
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func dismissPanel() {
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }
}
