import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.35)
            usageList
            Divider().opacity(0.35)
            footer
        }
        .frame(width: 300)
        .background(FiltrTheme.wash)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Filtr")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Text("Today’s limits")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(FiltrTheme.muted)
            }
            Spacer()
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var usageList: some View {
        VStack(spacing: 12) {
            ForEach(store.categories) { config in
                CategoryUsageRow(store: store, config: config)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            Button("Settings…") {
                openSettings()
            }
            .buttonStyle(.plain)
            .foregroundStyle(FiltrTheme.accent)
            .font(.system(size: 13, weight: .medium))

            Spacer()

            Button("Quit Filtr") {
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
        VStack(alignment: .leading, spacing: 6) {
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
