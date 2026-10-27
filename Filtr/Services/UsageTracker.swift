import AppKit
import Combine
import Foundation

/// Polls the frontmost app; when it is a browser, best-effort resolves host and maps to a category.
@MainActor
final class UsageTracker: ObservableObject {
    @Published private(set) var frontmostAppName: String = ""
    @Published private(set) var frontmostBundleID: String?
    @Published private(set) var activeHost: String?
    @Published private(set) var activeCategory: CategoryID?

    private let store: FiltrStore
    private var timer: Timer?
    private var lastTick: Date?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var screenLocked = false

    init(store: FiltrStore) {
        self.store = store
    }

    func start() {
        stop()
        lastTick = Date()
        sampleFrontmost()
        timer = Timer.scheduledTimer(withTimeInterval: FiltrDefaults.pollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        let center = NSWorkspace.shared.notificationCenter
        let activate = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sampleFrontmost()
            }
        }
        let sleepObs = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lastTick = nil }
        }
        let wakeObs = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lastTick = Date() }
        }
        workspaceObservers = [activate, sleepObs, wakeObs]

        let dnc = DistributedNotificationCenter.default()
        let locked = dnc.addObserver(
            forName: .init("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.screenLocked = true
                self?.lastTick = nil
            }
        }
        let unlocked = dnc.addObserver(
            forName: .init("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.screenLocked = false
                self?.lastTick = Date()
            }
        }
        distributedObservers = [locked, unlocked]
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        for observer in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        distributedObservers.removeAll()
        lastTick = nil
    }

    private func tick() {
        store.ensureToday()
        let now = Date()
        defer { lastTick = now }

        sampleFrontmost()

        guard !screenLocked else { return }
        guard let category = activeCategory else { return }
        guard let lastTick else { return }

        let delta = now.timeIntervalSince(lastTick)
        // Cap a single tick to avoid huge jumps after sleep
        let clamped = min(max(0, delta), FiltrDefaults.pollIntervalSeconds * 3)
        if clamped > 0 {
            store.accrue(seconds: clamped, to: category)
        }
        store.evaluateSoftLimit(now: now)
    }

    private func sampleFrontmost() {
        let app = NSWorkspace.shared.frontmostApplication
        // Ignore Filtr itself
        if app?.bundleIdentifier == Bundle.main.bundleIdentifier {
            activeCategory = nil
            return
        }

        frontmostBundleID = app?.bundleIdentifier
        frontmostAppName = app?.localizedName ?? ""

        var host: String?
        if BrowserURLResolver.isBrowser(bundleID: frontmostBundleID) {
            host = BrowserURLResolver.activeHost(for: frontmostBundleID)
        }
        activeHost = host

        activeCategory = store.resolveCategory(
            bundleID: frontmostBundleID,
            appName: frontmostAppName,
            host: host
        )
    }
}
