import Foundation

/// Maps a desktop app and/or browser host patterns into a category.
struct AppMapping: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var bundleIdentifier: String?
    var appName: String
    /// Lowercased host suffixes / exact hosts, e.g. "youtube.com", "twitch.tv"
    var hostPatterns: [String]

    init(
        id: UUID = UUID(),
        bundleIdentifier: String? = nil,
        appName: String,
        hostPatterns: [String] = []
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.hostPatterns = hostPatterns.map { $0.lowercased() }
    }

    func matches(bundleID: String?, appName frontmostName: String?, host: String?) -> Bool {
        if let bundleID, let mapped = bundleIdentifier, !mapped.isEmpty,
           bundleID.caseInsensitiveCompare(mapped) == .orderedSame {
            return true
        }
        if let frontmostName, !appName.isEmpty,
           frontmostName.caseInsensitiveCompare(appName) == .orderedSame {
            return true
        }
        if let host, !hostPatterns.isEmpty {
            let h = host.lowercased()
            for pattern in hostPatterns {
                if h == pattern || h.hasSuffix("." + pattern) {
                    return true
                }
            }
        }
        return false
    }
}
