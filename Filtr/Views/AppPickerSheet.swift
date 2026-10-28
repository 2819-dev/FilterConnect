import AppKit
import SwiftUI

/// Fully functional installed-app + website picker for a category.
struct AppPickerSheet: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    @ObservedObject var catalog: InstalledAppsCatalog
    let categoryID: CategoryID

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedBundleIDs: Set<String> = []
    @State private var selectedNames: Set<String> = []
    @State private var websiteText = ""
    @State private var didSeed = false

    private var category: CategoryConfig? { store.category(for: categoryID) }

    private var filteredApps: [InstalledApp] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalog.apps }
        return catalog.apps.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            searchBar
            Divider().opacity(0.2)
            appList
            Divider().opacity(0.3)
            websiteRow
            Divider().opacity(0.3)
            frontmostRow
            Divider().opacity(0.3)
            footer
        }
        .frame(width: 520, height: 560)
        .background(FiltrTheme.wash)
        .onAppear {
            catalog.loadIfNeeded()
            seedSelection()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose apps & sites")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Text(category?.displayName ?? "Category")
                    .font(.system(size: 12))
                    .foregroundStyle(FiltrTheme.muted)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(18)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FiltrTheme.muted)
            TextField("Search installed apps", text: $query)
                .textFieldStyle(.plain)
            if catalog.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.55))
    }

    private var appList: some View {
        Group {
            if filteredApps.isEmpty && !catalog.isLoading {
                VStack(spacing: 8) {
                    Text("No apps found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FiltrTheme.ink)
                    Text("Try another search, or add the frontmost app / a website below.")
                        .font(.system(size: 12))
                        .foregroundStyle(FiltrTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredApps) { app in
                        Button {
                            toggle(app)
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(FiltrTheme.ink)
                                    if let bid = app.bundleIdentifier {
                                        Text(bid)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(FiltrTheme.muted)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: isSelected(app) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected(app) ? FiltrTheme.accent : FiltrTheme.muted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var websiteRow: some View {
        HStack(spacing: 8) {
            TextField("Website host (e.g. reddit.com)", text: $websiteText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addWebsite() }
            Button("Add site") { addWebsite() }
                .disabled(normalizedHost(websiteText) == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var frontmostRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Frontmost now")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FiltrTheme.muted)
                if BrowserURLResolver.isBrowser(bundleID: tracker.frontmostBundleID),
                   let host = tracker.activeHost {
                    Text(host)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FiltrTheme.ink)
                } else if !tracker.frontmostAppName.isEmpty {
                    Text(tracker.frontmostAppName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FiltrTheme.ink)
                } else {
                    Text("Switch to an app, then add it here")
                        .font(.system(size: 12))
                        .foregroundStyle(FiltrTheme.muted)
                }
            }
            Spacer()
            Button("Add frontmost") {
                addFrontmost()
            }
            .disabled(tracker.frontmostAppName.isEmpty && tracker.activeHost == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Text("\(selectedCount) selected")
                .font(.system(size: 12))
                .foregroundStyle(FiltrTheme.muted)
            Spacer()
            Button("Save") {
                applySelection()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(FiltrTheme.ink)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var selectedCount: Int {
        selectedBundleIDs.count + selectedNames.count
    }

    private func seedSelection() {
        guard !didSeed, let category else { return }
        didSeed = true
        for mapping in category.mappings {
            if let bid = mapping.bundleIdentifier, !bid.isEmpty {
                selectedBundleIDs.insert(bid)
            } else {
                selectedNames.insert(mapping.appName)
            }
        }
    }

    private func isSelected(_ app: InstalledApp) -> Bool {
        if let bid = app.bundleIdentifier {
            return selectedBundleIDs.contains(bid)
        }
        return selectedNames.contains(app.name)
    }

    private func toggle(_ app: InstalledApp) {
        if let bid = app.bundleIdentifier {
            if selectedBundleIDs.contains(bid) {
                selectedBundleIDs.remove(bid)
            } else {
                selectedBundleIDs.insert(bid)
            }
        } else if selectedNames.contains(app.name) {
            selectedNames.remove(app.name)
        } else {
            selectedNames.insert(app.name)
        }
    }

    private func applySelection() {
        guard var config = category else { return }
        // Keep website-only mappings; replace app mappings from selection.
        let websiteMappings = config.mappings.filter { !$0.hostPatterns.isEmpty && $0.bundleIdentifier == nil }
        var next: [AppMapping] = websiteMappings

        for app in catalog.apps {
            if let bid = app.bundleIdentifier, selectedBundleIDs.contains(bid) {
                next.append(AppMapping(bundleIdentifier: bid, appName: app.name))
            } else if app.bundleIdentifier == nil, selectedNames.contains(app.name) {
                next.append(AppMapping(bundleIdentifier: nil, appName: app.name))
            }
        }

        // Preserve selected apps that aren't in catalog scan (rare)
        for mapping in config.mappings {
            if let bid = mapping.bundleIdentifier, selectedBundleIDs.contains(bid),
               !next.contains(where: { $0.bundleIdentifier == bid }) {
                next.append(mapping)
            }
        }

        config.mappings = next
        store.updateCategory(config)
    }

    private func addWebsite() {
        guard let host = normalizedHost(websiteText) else { return }
        store.addMapping(
            AppMapping(bundleIdentifier: nil, appName: host, hostPatterns: [host]),
            to: categoryID
        )
        websiteText = ""
        // Re-seed website list into current category view by refreshing seed flag
        didSeed = false
        seedSelection()
    }

    private func addFrontmost() {
        if BrowserURLResolver.isBrowser(bundleID: tracker.frontmostBundleID),
           let host = tracker.activeHost {
            store.addMapping(
                AppMapping(bundleIdentifier: nil, appName: host, hostPatterns: [host]),
                to: categoryID
            )
            return
        }
        guard !tracker.frontmostAppName.isEmpty else { return }
        if let bid = tracker.frontmostBundleID {
            selectedBundleIDs.insert(bid)
            store.addMapping(
                AppMapping(bundleIdentifier: bid, appName: tracker.frontmostAppName),
                to: categoryID
            )
        } else {
            store.addMapping(
                AppMapping(bundleIdentifier: nil, appName: tracker.frontmostAppName),
                to: categoryID
            )
        }
    }

    private func normalizedHost(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), let host = url.host, !host.isEmpty {
            value = host
        } else if value.contains("://"), let url = URL(string: value), let host = url.host {
            value = host
        } else {
            value = value
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            if let slash = value.firstIndex(of: "/") {
                value = String(value[..<slash])
            }
        }
        value = value.hasPrefix("www.") ? String(value.dropFirst(4)) : value
        guard value.contains("."), !value.contains(" ") else { return nil }
        return value
    }
}
