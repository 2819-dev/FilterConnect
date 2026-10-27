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
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel("Filtr")
    }

    private var iconName: String {
        let anyOver = CategoryID.allCases.contains { store.isOverLimit(for: $0) }
        if anyOver { return "hourglass.bottomhalf.filled" }
        return "hourglass"
    }
}
