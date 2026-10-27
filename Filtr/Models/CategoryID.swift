import Foundation

enum CategoryID: String, CaseIterable, Codable, Identifiable, Hashable {
    case youtube
    case gaming
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .gaming: return "Gaming"
        case .other: return "Other"
        }
    }
}
