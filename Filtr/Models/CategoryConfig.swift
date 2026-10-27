import Foundation

struct CategoryConfig: Identifiable, Codable, Equatable {
    var id: CategoryID
    var enabled: Bool
    /// Base daily limit in minutes (before today’s extends).
    var dailyLimitMinutes: Int
    var mappings: [AppMapping]

    var displayName: String { id.displayName }
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
                enabled: true,
                dailyLimitMinutes: youtubeLimitMinutes,
                mappings: [
                    AppMapping(
                        bundleIdentifier: nil,
                        appName: "YouTube",
                        hostPatterns: ["youtube.com", "youtu.be", "m.youtube.com", "www.youtube.com"]
                    ),
                    AppMapping(
                        bundleIdentifier: "com.apple.Safari.WebApp",
                        appName: "YouTube",
                        hostPatterns: ["youtube.com", "youtu.be"]
                    ),
                ]
            ),
            CategoryConfig(
                id: .gaming,
                enabled: true,
                dailyLimitMinutes: gamingLimitMinutes,
                mappings: starterGamingMappings()
            ),
            CategoryConfig(
                id: .other,
                enabled: false,
                dailyLimitMinutes: otherLimitMinutes,
                mappings: []
            ),
        ]
    }

    static func starterGamingMappings() -> [AppMapping] {
        [
            AppMapping(bundleIdentifier: "com.valvesoftware.steam", appName: "Steam"),
            AppMapping(bundleIdentifier: "com.valvesoftware.steam.helper", appName: "Steam Helper"),
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
                appName: "Gaming sites",
                hostPatterns: ["twitch.tv", "store.steampowered.com", "epicgames.com"]
            ),
        ]
    }
}
