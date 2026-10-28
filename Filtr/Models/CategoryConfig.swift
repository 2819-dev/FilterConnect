import Foundation

struct CategoryConfig: Identifiable, Codable, Equatable {
    var id: CategoryID
    /// User-visible name (editable).
    var name: String
    var enabled: Bool
    /// Base daily limit in minutes (before today’s extends).
    var dailyLimitMinutes: Int
    var mappings: [AppMapping]

    var displayName: String { name }

    var isBuiltIn: Bool { id.isBuiltIn }
}

enum FiltrDefaults {
    static let youtubeLimitMinutes = 30
    static let gamingLimitMinutes = 60
    static let otherLimitMinutes = 180
    static let dismissReNudgeSeconds: TimeInterval = 5 * 60
    static let pollIntervalSeconds: TimeInterval = 2

    static func starterCategories() -> [CategoryConfig] {
        [
            CategoryConfig(
                id: .youtube,
                name: "YouTube",
                enabled: true,
                dailyLimitMinutes: youtubeLimitMinutes,
                mappings: [
                    AppMapping(
                        bundleIdentifier: nil,
                        appName: "YouTube (browser)",
                        hostPatterns: ["youtube.com", "youtu.be", "m.youtube.com", "www.youtube.com"]
                    ),
                ]
            ),
            CategoryConfig(
                id: .gaming,
                name: "Gaming",
                enabled: true,
                dailyLimitMinutes: gamingLimitMinutes,
                mappings: starterGamingMappings()
            ),
            CategoryConfig(
                id: .other,
                name: "Other",
                enabled: false,
                dailyLimitMinutes: otherLimitMinutes,
                mappings: []
            ),
        ]
    }

    static func starterGamingMappings() -> [AppMapping] {
        [
            AppMapping(bundleIdentifier: "com.valvesoftware.steam", appName: "Steam"),
            AppMapping(bundleIdentifier: "com.epicgames.EpicGamesLauncher", appName: "Epic Games Launcher"),
            AppMapping(bundleIdentifier: "com.blizzard.battle.net", appName: "Battle.net"),
            AppMapping(bundleIdentifier: "net.battle.net.app", appName: "Battle.net"),
            AppMapping(bundleIdentifier: "com.riotgames.RiotClient", appName: "Riot Client"),
            AppMapping(bundleIdentifier: "com.riotgames.LeagueofLegends.LeagueClient", appName: "League of Legends"),
            AppMapping(bundleIdentifier: "org.prismlauncher.PrismLauncher", appName: "Prism Launcher"),
            AppMapping(bundleIdentifier: "com.mojang.minecraftlauncher", appName: "Minecraft"),
            AppMapping(bundleIdentifier: "com.mojang.minecraft", appName: "Minecraft"),
            AppMapping(
                bundleIdentifier: nil,
                appName: "Twitch / game stores",
                hostPatterns: ["twitch.tv", "store.steampowered.com", "epicgames.com"]
            ),
        ]
    }
}
