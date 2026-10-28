import AppKit
import Foundation

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleIdentifier ?? url.path }
    var name: String
    var bundleIdentifier: String?
    var url: URL

    @MainActor
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Scans local Applications folders for real, selectable apps.
@MainActor
final class InstalledAppsCatalog: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isLoading = false

    private var didLoad = false

    func loadIfNeeded() {
        guard !didLoad, !isLoading else { return }
        refresh()
    }

    func refresh() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let scanned = Self.scan()
            await MainActor.run {
                self.apps = scanned
                self.isLoading = false
                self.didLoad = true
            }
        }
    }

    nonisolated private static func scan() -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]

        var seen = Set<String>()
        var results: [InstalledApp] = []
        let fm = FileManager.default

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                // Skip nested apps deep inside other apps / bundles
                let depth = url.pathComponents.count - root.pathComponents.count
                if depth > 3 { continue }

                let bundle = Bundle(url: url)
                let bid = bundle?.bundleIdentifier
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent

                // Skip Filtr itself and background helpers without UI names
                if bid == "dev.filtr.app" { continue }
                if name.lowercased().contains("helper"), bid?.contains("steam") == true {
                    // still allow Steam Helper? skip helpers generally for picker clarity
                }
                if name.hasSuffix("Helper") || name.hasSuffix("Agent") { continue }

                let key = bid ?? url.path
                if seen.contains(key) { continue }
                seen.insert(key)

                results.append(
                    InstalledApp(
                        name: name,
                        bundleIdentifier: bid,
                        url: url
                    )
                )
            }
        }

        return results.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
