import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    @ObservedObject var updates: UpdateController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.28)
            usageList
            Divider().opacity(0.28)
            footer
        }
        .frame(width: 312)
        .background(
            LinearGradient(
                colors: [FiltrTheme.wash, Color(red: 0.94, green: 0.93, blue: 0.91)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(FiltrTheme.accent)
                .padding(8)
                .background(Circle().fill(FiltrTheme.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Filtr")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Text("Today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FiltrTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let host = tracker.activeHost {
                    Text(host)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(FiltrTheme.muted)
                        .lineLimit(1)
                } else if !tracker.frontmostAppName.isEmpty {
                    Text(tracker.frontmostAppName)
                        .font(.system(size: 10))
                        .foregroundStyle(FiltrTheme.muted)
                        .lineLimit(1)
                }
                Text("v\(store.appVersionString)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(FiltrTheme.muted.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var usageList: some View {
        VStack(spacing: 14) {
            ForEach(store.categories) { config in
                CategoryUsageRow(store: store, config: config)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Settings…") {
                openSettings()
            }
            .buttonStyle(.plain)
            .foregroundStyle(FiltrTheme.accent)
            .font(.system(size: 13, weight: .semibold))

            Button("Check for Updates") {
                updates.checkForUpdates()
            }
            .buttonStyle(.plain)
            .foregroundStyle(FiltrTheme.muted)
            .font(.system(size: 12, weight: .medium))

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(FiltrTheme.muted)
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct CategoryUsageRow: View {
    @ObservedObject var store: FiltrStore
    let config: CategoryConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(config.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(config.enabled ? FiltrTheme.ink : FiltrTheme.muted)
                Spacer()
                Text(statusText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FiltrTheme.track)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(store.progress(for: config.id))))
                }
            }
            .frame(height: 6)
            .opacity(config.enabled ? 1 : 0.4)
        }
    }

    private var statusText: String {
        guard config.enabled else { return "Off" }
        let used = store.usedMinutes(for: config.id)
        let limit = store.effectiveLimitMinutes(for: config.id)
        if store.dayUsage.isUnlocked(for: config.id) {
            return String(format: "%.0f m · open today", used)
        }
        return String(format: "%.0f / %d min", used, limit)
    }

    private var statusColor: Color {
        guard config.enabled else { return FiltrTheme.muted }
        if store.isOverLimit(for: config.id) || store.progress(for: config.id) >= 1 {
            return FiltrTheme.warn
        }
        return FiltrTheme.muted
    }

    private var barColor: Color {
        if store.progress(for: config.id) >= 1 { return FiltrTheme.warn }
        return FiltrTheme.accent
    }
}
