import Foundation
import Combine

@MainActor
final class FiltrStore: ObservableObject {
    @Published private(set) var categories: [CategoryConfig]
    @Published private(set) var dayUsage: DayUsage
    @Published var softLimitCategory: CategoryID?
    @Published private(set) var hasCompletedSetup: Bool

    private let persistence: PersistenceService
    private let setupKey = "filtr.v1.hasCompletedSetup"

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence
        let saved = persistence.load()
        self.categories = Self.normalize(saved.categories)
        self.dayUsage = saved.dayUsage
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: setupKey)
        ensureToday()
    }

    /// Migrate older payloads that may lack `name`.
    private static func normalize(_ list: [CategoryConfig]) -> [CategoryConfig] {
        if list.isEmpty { return FiltrDefaults.starterCategories() }
        return list.map { config in
            var c = config
            if c.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch c.id {
                case .youtube: c.name = "YouTube"
                case .gaming: c.name = "Gaming"
                case .other: c.name = "Other"
                default: c.name = "Category"
                }
            }
            return c
        }
    }

    func completeSetup() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: setupKey)
    }

    func resetSetup() {
        hasCompletedSetup = false
        UserDefaults.standard.set(false, forKey: setupKey)
    }

    var appVersionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    func category(for id: CategoryID) -> CategoryConfig? {
        categories.first { $0.id == id }
    }

    func displayName(for id: CategoryID) -> String {
        category(for: id)?.displayName ?? id.rawValue
    }

    func effectiveLimitMinutes(for id: CategoryID) -> Int {
        guard let config = category(for: id), config.enabled else { return 0 }
        return max(0, config.dailyLimitMinutes + dayUsage.extendMinutes(for: id))
    }

    func usedMinutes(for id: CategoryID) -> Double {
        dayUsage.seconds(for: id) / 60.0
    }

    func remainingMinutes(for id: CategoryID) -> Double {
        Double(effectiveLimitMinutes(for: id)) - usedMinutes(for: id)
    }

    func isOverLimit(for id: CategoryID) -> Bool {
        guard let config = category(for: id), config.enabled else { return false }
        if dayUsage.isUnlocked(for: id) { return false }
        return remainingMinutes(for: id) <= 0
    }

    func progress(for id: CategoryID) -> Double {
        let limit = Double(effectiveLimitMinutes(for: id))
        guard limit > 0 else { return 0 }
        return min(1, usedMinutes(for: id) / limit)
    }

    func ensureToday(now: Date = Date()) {
        let key = DayUsage.dayKey(for: now)
        if dayUsage.dayKey != key {
            dayUsage = .empty(for: now)
            persist()
        }
    }

    func updateCategory(_ config: CategoryConfig) {
        if let idx = categories.firstIndex(where: { $0.id == config.id }) {
            categories[idx] = config
            persist()
        }
    }

    func setLimit(minutes: Int, for id: CategoryID) {
        guard var config = category(for: id) else { return }
        config.dailyLimitMinutes = max(1, min(24 * 60, minutes))
        updateCategory(config)
    }

    func setEnabled(_ enabled: Bool, for id: CategoryID) {
        guard var config = category(for: id) else { return }
        config.enabled = enabled
        updateCategory(config)
    }

    func renameCategory(_ id: CategoryID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var config = category(for: id) else { return }
        config.name = trimmed
        updateCategory(config)
    }

    func addCategory(name: String, limitMinutes: Int = 60) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let config = CategoryConfig(
            id: .makeCustom(),
            name: trimmed,
            enabled: true,
            dailyLimitMinutes: max(1, limitMinutes),
            mappings: []
        )
        categories.append(config)
        persist()
    }

    func deleteCategory(_ id: CategoryID) {
        // Built-ins can be disabled, but not deleted — keeps defaults stable.
        guard !id.isBuiltIn else { return }
        categories.removeAll { $0.id == id }
        if softLimitCategory == id { softLimitCategory = nil }
        persist()
    }

    func addMapping(_ mapping: AppMapping, to id: CategoryID) {
        guard var config = category(for: id) else { return }
        let duplicate = config.mappings.contains { existing in
            if let bid = mapping.bundleIdentifier, !bid.isEmpty,
               existing.bundleIdentifier == bid {
                return true
            }
            if !mapping.hostPatterns.isEmpty,
               Set(existing.hostPatterns) == Set(mapping.hostPatterns),
               existing.bundleIdentifier == nil {
                return true
            }
            return existing.appName.caseInsensitiveCompare(mapping.appName) == .orderedSame
                && existing.bundleIdentifier == mapping.bundleIdentifier
                && existing.hostPatterns == mapping.hostPatterns
        }
        if duplicate { return }
        config.mappings.append(mapping)
        updateCategory(config)
    }

    func addMappings(_ mappings: [AppMapping], to id: CategoryID) {
        for mapping in mappings {
            addMapping(mapping, to: id)
        }
    }

    func removeMapping(id mappingID: UUID, from categoryID: CategoryID) {
        guard var config = category(for: categoryID) else { return }
        config.mappings.removeAll { $0.id == mappingID }
        updateCategory(config)
    }

    func replaceMappings(_ mappings: [AppMapping], for id: CategoryID) {
        guard var config = category(for: id) else { return }
        config.mappings = mappings
        updateCategory(config)
    }

    func accrue(seconds: TimeInterval, to id: CategoryID) {
        ensureToday()
        dayUsage.add(seconds: seconds, to: id)
        persist()
        evaluateSoftLimit()
    }

    func extend(minutes: Int, category id: CategoryID) {
        ensureToday()
        dayUsage.addExtend(minutes: minutes, to: id)
        if softLimitCategory == id { softLimitCategory = nil }
        persist()
    }

    func unlockForToday(category id: CategoryID) {
        ensureToday()
        dayUsage.unlockForToday(id)
        if softLimitCategory == id { softLimitCategory = nil }
        persist()
    }

    func dismissSoftLimit(category id: CategoryID) {
        ensureToday()
        dayUsage.markDismissed(id)
        if softLimitCategory == id { softLimitCategory = nil }
        persist()
    }

    func evaluateSoftLimit(now: Date = Date()) {
        ensureToday(now: now)
        for config in categories where config.enabled {
            let id = config.id
            guard isOverLimit(for: id) else { continue }
            if let dismissed = dayUsage.lastDismissed(for: id) {
                if now.timeIntervalSince(dismissed) < FiltrDefaults.dismissReNudgeSeconds {
                    continue
                }
            }
            softLimitCategory = id
            return
        }
        if let current = softLimitCategory, !isOverLimit(for: current) {
            softLimitCategory = nil
        }
    }

    func resolveCategory(bundleID: String?, appName: String?, host: String?) -> CategoryID? {
        for config in categories where config.enabled {
            for mapping in config.mappings {
                if mapping.matches(bundleID: bundleID, appName: appName, host: host) {
                    return config.id
                }
            }
        }
        return nil
    }

    private func persist() {
        persistence.save(categories: categories, dayUsage: dayUsage)
    }
}
