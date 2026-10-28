import Foundation

struct PersistedState: Codable {
    var categories: [CategoryConfig]
    var dayUsage: DayUsage
}

/// Legacy shape before editable category names.
private struct LegacyCategoryConfig: Codable {
    var id: CategoryID
    var enabled: Bool
    var dailyLimitMinutes: Int
    var mappings: [AppMapping]
    var name: String?
}

private struct LegacyPersistedState: Codable {
    var categories: [LegacyCategoryConfig]
    var dayUsage: DayUsage
}

final class PersistenceService {
    private let defaults: UserDefaults
    private let key = "filtr.v1.state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PersistedState {
        guard let data = defaults.data(forKey: key) else {
            return PersistedState(
                categories: FiltrDefaults.starterCategories(),
                dayUsage: .empty()
            )
        }

        if let decoded = try? JSONDecoder().decode(PersistedState.self, from: data),
           decoded.categories.allSatisfy({ !$0.name.isEmpty }) {
            return decoded
        }

        if let legacy = try? JSONDecoder().decode(LegacyPersistedState.self, from: data) {
            let categories = legacy.categories.map { item -> CategoryConfig in
                let fallback: String
                switch item.id {
                case .youtube: fallback = "YouTube"
                case .gaming: fallback = "Gaming"
                case .other: fallback = "Other"
                default: fallback = "Category"
                }
                return CategoryConfig(
                    id: item.id,
                    name: (item.name?.isEmpty == false ? item.name! : fallback),
                    enabled: item.enabled,
                    dailyLimitMinutes: item.dailyLimitMinutes,
                    mappings: item.mappings
                )
            }
            let state = PersistedState(categories: categories, dayUsage: legacy.dayUsage)
            save(categories: state.categories, dayUsage: state.dayUsage)
            return state
        }

        return PersistedState(
            categories: FiltrDefaults.starterCategories(),
            dayUsage: .empty()
        )
    }

    func save(categories: [CategoryConfig], dayUsage: DayUsage) {
        let state = PersistedState(categories: categories, dayUsage: dayUsage)
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
        } catch {
            // Local-only; swallow encode failures quietly.
        }
    }
}
