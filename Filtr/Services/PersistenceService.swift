import Foundation

struct PersistedState: Codable {
    var categories: [CategoryConfig]
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
        do {
            let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
            return decoded
        } catch {
            return PersistedState(
                categories: FiltrDefaults.starterCategories(),
                dayUsage: .empty()
            )
        }
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
