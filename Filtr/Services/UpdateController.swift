import AppKit
import Combine
import Foundation

/// In-app updater against GitHub Releases — downloads Filtr.app.zip and replaces this build.
@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var lastCheckSummary: String =
        "Filtr can install updates from GitHub Releases without a manual re-download."
    @Published private(set) var isBusy = false

    private let apiURL = URL(string: "https://api.github.com/repos/2819-dev/FilterConnect/releases/latest")!
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "User-Agent": "Filtr-Updater",
        ]
        return URLSession(configuration: config)
    }()

    func checkForUpdates(interactive: Bool = true) {
        guard !isBusy else { return }
        isBusy = true
        lastCheckSummary = "Checking for updates…"
        Task {
            defer { isBusy = false }
            do {
                let release = try await fetchLatestRelease()
                let remote = release.normalizedVersion
                let local = Self.localShortVersion
                if Self.isRemote(remote, newerThan: local) {
                    lastCheckSummary = "Update available: \(remote) (you have \(local))"
                    if interactive {
                        await offerInstall(release: release)
                    }
                } else {
                    lastCheckSummary = "You’re on the latest version (\(local))."
                    if interactive {
                        presentAlert(
                            title: "Filtr is up to date",
                            message: "Version \(local) is the latest release."
                        )
                    }
                }
            } catch {
                lastCheckSummary = "Couldn’t check for updates. Try again later."
                if interactive {
                    presentAlert(
                        title: "Update check failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    func checkInBackground() {
        // Quiet launch check — only prompt when something newer exists.
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let release = try await fetchLatestRelease()
                let remote = release.normalizedVersion
                let local = Self.localShortVersion
                if Self.isRemote(remote, newerThan: local) {
                    lastCheckSummary = "Update available: \(remote)"
                    await offerInstall(release: release)
                } else {
                    lastCheckSummary = "You’re on the latest version (\(local))."
                }
            } catch {
                lastCheckSummary = "Automatic update check skipped."
            }
        }
    }

    // MARK: - Network

    private struct GHRelease: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let assets: [GHAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body, assets
        }

        var normalizedVersion: String {
            tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        }

        var zipAsset: GHAsset? {
            assets.first { $0.name == "Filtr.app.zip" }
                ?? assets.first { $0.name.hasSuffix(".app.zip") }
        }
    }

    private struct GHAsset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name, size
            case browserDownloadURL = "browser_download_url"
        }
    }

    private func fetchLatestRelease() async throws -> GHRelease {
        let (data, response) = try await session.data(from: apiURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(GHRelease.self, from: data)
    }

    // MARK: - Install

    private func offerInstall(release: GHRelease) async {
        guard let asset = release.zipAsset else {
            presentAlert(title: "Update unavailable", message: "The latest release has no Filtr.app.zip asset yet.")
            return
        }

        let notes = (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let message: String
        if notes.isEmpty {
            message = "Version \(release.normalizedVersion) is ready. Filtr will download and install it, then relaunch."
        } else {
            message = "Version \(release.normalizedVersion) is ready.\n\n\(notes.prefix(500))"
        }

        let proceed = await confirm(
            title: "Update Filtr?",
            message: message,
            confirmTitle: "Download & Install"
        )
        guard proceed else {
            lastCheckSummary = "Update available: \(release.normalizedVersion)"
            return
        }

        do {
            lastCheckSummary = "Downloading \(release.normalizedVersion)…"
            let zipURL = try await download(asset: asset)
            lastCheckSummary = "Installing…"
            try install(zipAt: zipURL)
        } catch {
            lastCheckSummary = "Update failed."
            presentAlert(title: "Couldn’t install update", message: error.localizedDescription)
        }
    }

    private func download(asset: GHAsset) async throws -> URL {
        let (tempURL, response) = try await session.download(from: asset.browserDownloadURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("FiltrUpdates", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("Filtr.app.zip")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    private func install(zipAt zipURL: URL) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("FiltrUpdate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zipURL.path, work.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else { throw UpdateError.unzipFailed }

        let newApp = work.appendingPathComponent("Filtr.app")
        guard fm.fileExists(atPath: newApp.path) else { throw UpdateError.missingAppInArchive }

        let currentApp = Bundle.main.bundleURL
        // Install script runs after we quit so the bundle isn’t busy.
        let script = """
        #!/bin/bash
        set -euo pipefail
        sleep 1
        DEST=\(shellQuote(currentApp.path))
        SRC=\(shellQuote(newApp.path))
        WORK=\(shellQuote(work.path))
        /bin/rm -rf "$DEST"
        /bin/mv "$SRC" "$DEST"
        /usr/bin/xattr -dr com.apple.quarantine "$DEST" || true
        /usr/bin/open "$DEST"
        /bin/rm -rf "$WORK"
        """
        let scriptURL = work.appendingPathComponent("install.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let installer = Process()
        installer.executableURL = URL(fileURLWithPath: "/bin/bash")
        installer.arguments = [scriptURL.path]
        try installer.run()

        lastCheckSummary = "Installing update and relaunching…"
        NSApp.terminate(nil)
    }

    // MARK: - Version helpers

    private static var localShortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func isRemote(_ remote: String, newerThan local: String) -> Bool {
        compare(remote, local) == .orderedDescending
    }

    private static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let ap = a.split(separator: ".").map { Int($0) ?? 0 }
        let bp = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(ap.count, bp.count)
        for i in 0..<count {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av != bv { return av < bv ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    // MARK: - UI helpers

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func confirm(title: String, message: String, confirmTitle: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: confirmTitle)
            alert.addButton(withTitle: "Later")
            let result = alert.runModal()
            continuation.resume(returning: result == .alertFirstButtonReturn)
        }
    }

    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private enum UpdateError: LocalizedError {
    case httpStatus(Int)
    case unzipFailed
    case missingAppInArchive

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "GitHub returned HTTP \(code)."
        case .unzipFailed: return "Couldn’t unpack the update archive."
        case .missingAppInArchive: return "The update archive didn’t contain Filtr.app."
        }
    }
}
