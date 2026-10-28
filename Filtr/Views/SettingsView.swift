import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    @ObservedObject var updates: UpdateController
    @StateObject private var catalog = InstalledAppsCatalog()
    var onReplaySetup: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var pickerCategory: CategoryID?
    @State private var newCategoryName = ""
    @State private var renamingID: CategoryID?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(FiltrTheme.ink)
                    Text("Filtr \(store.appVersionString)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(FiltrTheme.muted)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sectionLabel("Categories")
                    Text("Rename categories, set daily minutes, and choose exactly which apps or sites count.")
                        .font(.system(size: 12))
                        .foregroundStyle(FiltrTheme.muted)

                    ForEach(store.categories) { config in
                        CategoryEditorCard(
                            store: store,
                            config: config,
                            onManageApps: { pickerCategory = config.id },
                            onBeginRename: {
                                renamingID = config.id
                                renameText = config.name
                            },
                            onDelete: { store.deleteCategory(config.id) }
                        )
                    }

                    HStack(spacing: 8) {
                        TextField("New category name", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addCategory() }
                        Button("Add category") { addCategory() }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    sectionLabel("Updates")
                    VStack(alignment: .leading, spacing: 10) {
                        Text(updates.lastCheckSummary)
                            .font(.system(size: 12))
                            .foregroundStyle(FiltrTheme.muted)
                        Button("Check for Updates…") {
                            updates.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground)

                    sectionLabel("Permissions")
                    Text("Browser site matching needs Accessibility (and sometimes Automation). App tracking works without it.")
                        .font(.system(size: 11))
                        .foregroundStyle(FiltrTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Open Accessibility settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FiltrTheme.accent)
                    .font(.system(size: 12, weight: .medium))

                    Button("Replay setup guide…") {
                        store.resetSetup()
                        onReplaySetup?()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FiltrTheme.muted)
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 620)
        .background(FiltrTheme.wash)
        .sheet(item: $pickerCategory) { id in
            AppPickerSheet(
                store: store,
                tracker: tracker,
                catalog: catalog,
                categoryID: id
            )
        }
        .sheet(isPresented: Binding(
            get: { renamingID != nil },
            set: { if !$0 { renamingID = nil } }
        )) {
            renameSheet
        }
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename category")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            TextField("Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitRename() }
            HStack {
                Spacer()
                Button("Cancel") { renamingID = nil }
                Button("Save") { commitRename() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.55))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FiltrTheme.muted)
            .textCase(.uppercase)
            .tracking(0.4)
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.addCategory(name: name)
        newCategoryName = ""
    }

    private func commitRename() {
        guard let id = renamingID else { return }
        store.renameCategory(id, to: renameText)
        renamingID = nil
    }
}

struct CategoryEditorCard: View {
    @ObservedObject var store: FiltrStore
    let config: CategoryConfig
    var onManageApps: () -> Void
    var onBeginRename: () -> Void
    var onDelete: () -> Void

    var body: some View {
        let live = store.category(for: config.id) ?? config

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Toggle(isOn: Binding(
                    get: { store.category(for: config.id)?.enabled ?? false },
                    set: { store.setEnabled($0, for: config.id) }
                )) {
                    Text(live.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FiltrTheme.ink)
                }
                .toggleStyle(.switch)
                .tint(FiltrTheme.accent)

                Spacer()

                Stepper(value: Binding(
                    get: { store.category(for: config.id)?.dailyLimitMinutes ?? config.dailyLimitMinutes },
                    set: { store.setLimit(minutes: $0, for: config.id) }
                ), in: 5...24 * 60, step: 5) {
                    Text("\(live.dailyLimitMinutes) min / day")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(FiltrTheme.muted)
                        .frame(minWidth: 88, alignment: .trailing)
                }
                .disabled(!(store.category(for: config.id)?.enabled ?? false))
            }

            if live.id == .other {
                Text("Only apps and sites you assign here count — not leftover screen time.")
                    .font(.system(size: 11))
                    .foregroundStyle(FiltrTheme.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                if live.mappings.isEmpty {
                    Text("No apps or sites yet — use Choose apps… to pick them.")
                        .font(.system(size: 12))
                        .foregroundStyle(FiltrTheme.muted)
                        .padding(.vertical, 4)
                } else {
                    ForEach(live.mappings) { mapping in
                        HStack(spacing: 8) {
                            Image(systemName: mapping.hostPatterns.isEmpty ? "app.fill" : "globe")
                                .font(.system(size: 11))
                                .foregroundStyle(FiltrTheme.accent)
                                .frame(width: 16)
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
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(FiltrTheme.muted)
                            }
                            .buttonStyle(.plain)
                            .help("Remove")
                        }
                    }
                }

                HStack(spacing: 14) {
                    Button(action: onManageApps) {
                        Label("Choose apps…", systemImage: "plus.app")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FiltrTheme.accent)

                    Button("Rename", action: onBeginRename)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FiltrTheme.muted)

                    if !live.isBuiltIn {
                        Button("Delete", role: .destructive, action: onDelete)
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FiltrTheme.warn)
                    }
                }
                .padding(.top, 4)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.35))
        )
    }

    private func subtitle(for mapping: AppMapping) -> String {
        var parts: [String] = []
        if let bid = mapping.bundleIdentifier, !bid.isEmpty { parts.append(bid) }
        if !mapping.hostPatterns.isEmpty {
            parts.append(mapping.hostPatterns.joined(separator: ", "))
        }
        return parts.isEmpty ? "Matches app name" : parts.joined(separator: " · ")
    }
}
