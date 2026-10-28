import AppKit
import Combine
import Sparkle

/// Sparkle-backed updater against the GitHub Releases appcast.
@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var lastCheckSummary: String =
        "Filtr checks for updates automatically and can install them in place."

    private var updaterController: SPUStandardUpdaterController!

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        lastCheckSummary = "Checking for updates…"
        updaterController.checkForUpdates(nil)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            lastCheckSummary = "If an update is available, Filtr will offer to install it."
        }
    }
}
