import AppKit
import SwiftUI

@main
struct FiltrApp: App {
    @StateObject private var store: FiltrStore
    @StateObject private var tracker: UsageTracker
    @StateObject private var softLimit = SoftLimitPresenter()
    @StateObject private var updates = UpdateController()
    @State private var setupController = SetupWindowController()

    init() {
        let store = FiltrStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: UsageTracker(store: store))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(store: store, tracker: tracker, updates: updates)
                .onAppear {
                    tracker.start()
                    softLimit.attach(store: store)
                    store.evaluateSoftLimit()
                    presentSetupIfNeeded()
                    updates.checkInBackground()
                }
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                store: store,
                tracker: tracker,
                updates: updates,
                onReplaySetup: {
                    setupController.present(store: store)
                }
            )
        }
    }

    private func presentSetupIfNeeded() {
        guard !store.hasCompletedSetup else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            setupController.present(store: store)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: FiltrStore

    var body: some View {
        let over = CategoryID.allCases.contains { store.isOverLimit(for: $0) }
        Image("MenuBarIcon")
            .renderingMode(.template)
            .opacity(over ? 1.0 : 0.9)
            .accessibilityLabel("Filtr")
    }
}
