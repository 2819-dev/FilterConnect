import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Daily limits")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FiltrTheme.muted)
                        .textCase(.uppercase)

                    ForEach(store.categories) { config in
                        CategorySettingsCard(
                            store: store,
                            tracker: tracker,
                            config: config
                        )
                    }

                    Text("Browser tracking is best-effort for Safari and Chrome. Grant Accessibility (and Automation if prompted) in System Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(FiltrTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 520)
        .background(FiltrTheme.wash)
    }
}

struct CategorySettingsCard: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    let config: CategoryConfig

    @State private var minutesText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: Binding(
                    get: { store.category(for: config.id)?.enabled ?? false },
                    set: { store.setEnabled($0, for: config.id) }
                )) {
                    Text(config.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FiltrTheme.ink)
                }
                .toggleStyle(.switch)
                .tint(FiltrTheme.accent)

                Spacer()

                HStack(spacing: 4) {
                    TextField("min", text: $minutesText)
                        .frame(width: 52)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            minutesText = "\(config.dailyLimitMinutes)"
                        }
                        .onSubmit { commitMinutes() }
                    Text("min / day")
                        .font(.system(size: 12))
                        .foregroundStyle(FiltrTheme.muted)
                }
                .disabled(!(store.category(for: config.id)?.enabled ?? false))
            }

            if config.id == .other {
                Text("Only apps and sites you assign here count — not leftover screen time.")
                    .font(.system(size: 11))
                    .foregroundStyle(FiltrTheme.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.category(for: config.id)?.mappings ?? []) { mapping in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(mapping.appName)
                                .font(.system(size: 12, weight: .medium))
                            Text(subtitle(for: mapping))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(FiltrTheme.muted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            store.removeMapping(id: mapping.id, from: config.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(FiltrTheme.muted)
                        }
                        .buttonStyle(.plain)
                        .help("Remove")
                    }
                }

                if config.id == .gaming || config.id == .other || config.id == .youtube {
                    Button {
                        addFrontmost()
                        commitMinutes()
                    } label: {
                        Label("Add frontmost app", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FiltrTheme.accent)
                    .disabled(tracker.frontmostAppName.isEmpty)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
        }
        .onDisappear { commitMinutes() }
    }

    private func subtitle(for mapping: AppMapping) -> String {
        var parts: [String] = []
        if let bid = mapping.bundleIdentifier, !bid.isEmpty { parts.append(bid) }
        if !mapping.hostPatterns.isEmpty {
            parts.append(mapping.hostPatterns.joined(separator: ", "))
        }
        return parts.isEmpty ? "App name only" : parts.joined(separator: " · ")
    }

    private func commitMinutes() {
        if let value = Int(minutesText.trimmingCharacters(in: .whitespaces)) {
            store.setLimit(minutes: value, for: config.id)
        } else {
            minutesText = "\(store.category(for: config.id)?.dailyLimitMinutes ?? 0)"
        }
    }

    private func addFrontmost() {
        let name = tracker.frontmostAppName
        guard !name.isEmpty else { return }
        // Don’t map Filtr or browsers as “apps” without host — browsers use host patterns
        if BrowserURLResolver.isBrowser(bundleID: tracker.frontmostBundleID) {
            if let host = tracker.activeHost {
                store.addMapping(
                    AppMapping(
                        bundleIdentifier: nil,
                        appName: host,
                        hostPatterns: [host]
                    ),
                    to: config.id
                )
            }
            return
        }
        store.addMapping(
            AppMapping(
                bundleIdentifier: tracker.frontmostBundleID,
                appName: name,
                hostPatterns: []
            ),
            to: config.id
        )
    }
}
