import Foundation

/// Stable category key. Built-ins keep fixed IDs; custom categories use UUIDs.
struct CategoryID: RawRepresentable, Hashable, Codable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let youtube = CategoryID(rawValue: "youtube")
    static let gaming = CategoryID(rawValue: "gaming")
    static let other = CategoryID(rawValue: "other")

    static func makeCustom() -> CategoryID {
        CategoryID(rawValue: "custom-" + UUID().uuidString)
    }

    var isBuiltIn: Bool {
        self == .youtube || self == .gaming || self == .other
    }
}
