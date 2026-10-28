import AppKit
import SwiftUI

@main
struct FiltrApp: App {
    @StateObject private var store: FiltrStore
    @StateObject private var tracker: UsageTracker
    @StateObject private var softLimit = SoftLimitPresenter()

    init() {
        let store = FiltrStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: UsageTracker(store: store))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(store: store, tracker: tracker)
                .onAppear {
                    tracker.start()
                    softLimit.attach(store: store)
                    store.evaluateSoftLimit()
                }
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store, tracker: tracker)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: FiltrStore

    var body: some View {
        let over = CategoryID.allCases.contains { store.isOverLimit(for: $0) }
        Image("MenuBarIcon")
            .renderingMode(.template)
            .opacity(over ? 1.0 : 0.92)
            .accessibilityLabel("Filtr")
    }
}
