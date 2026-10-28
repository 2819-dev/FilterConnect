import AppKit
import SwiftUI

enum SetupStep: Int, CaseIterable {
    case welcome
    case limits
    case apps
    case permissions
    case ready
}

struct SetupFlowView: View {
    @ObservedObject var store: FiltrStore
    @ObservedObject var tracker: UsageTracker
    @StateObject private var catalog = InstalledAppsCatalog()
    var onFinished: () -> Void

    @State private var step: SetupStep = .welcome
    @State private var pickerCategory: CategoryID?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.25)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().opacity(0.25)
            footerBar
        }
        .frame(width: 560, height: 480)
        .background(
            LinearGradient(
                colors: [
                    FiltrTheme.wash,
                    Color(red: 0.93, green: 0.94, blue: 0.93),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(item: $pickerCategory) { id in
            AppPickerSheet(
                store: store,
                tracker: tracker,
                catalog: catalog,
                categoryID: id
            )
        }
        .onAppear { catalog.loadIfNeeded() }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(FiltrTheme.accent)
                .padding(8)
                .background(Circle().fill(FiltrTheme.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Filtr")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Text(stepTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(FiltrTheme.muted)
            }
            Spacer()
            stepIndicator
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(SetupStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? FiltrTheme.accent : FiltrTheme.track)
                    .frame(width: s == step ? 18 : 8, height: 6)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .limits: limitsStep
        case .apps: appsStep
        case .permissions: permissionsStep
        case .ready: readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Know your limits.\nBend them when you mean to.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(FiltrTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Filtr lives in your menu bar. You choose the categories, pick the apps and sites that count, and get a soft nudge when time runs out — never a hard lockout.")
                .font(.system(size: 14))
                .foregroundStyle(FiltrTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                setupBullet("Rename categories or add your own")
                setupBullet("Select installed apps and website hosts")
                setupBullet("Everything stays on this Mac")
            }
            .padding(.top, 6)
        }
        .padding(28)
    }

    private var limitsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily limits")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Text("Turn categories on and set minutes. You can rename them anytime in Settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(FiltrTheme.muted)

                ForEach(store.categories) { config in
                    SetupLimitRow(store: store, config: config)
                }
            }
            .padding(28)
        }
    }

    private var appsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose what counts")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                Text("Pick the apps and sites for each category. Only selected items are tracked.")
                    .font(.system(size: 13))
                    .foregroundStyle(FiltrTheme.muted)

                ForEach(store.categories) { config in
                    SetupAppsRow(
                        store: store,
                        config: config,
                        onChoose: { pickerCategory = config.id }
                    )
                }
            }
            .padding(28)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browser tracking (optional)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(FiltrTheme.ink)
            Text("App limits work immediately. To count sites like YouTube in Safari or Chrome, grant Accessibility (and Automation if prompted).")
                .font(.system(size: 13))
                .foregroundStyle(FiltrTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                permissionCard(
                    title: "Accessibility",
                    detail: "System Settings → Privacy & Security → Accessibility → enable Filtr"
                )
                permissionCard(
                    title: "Automation",
                    detail: "Allow Filtr if macOS asks to control Safari or Chrome"
                )
            }

            Button("Open Accessibility settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(FiltrTheme.accent)
            .padding(.top, 4)
        }
        .padding(28)
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You’re set")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(FiltrTheme.ink)
            Text("Filtr is in the menu bar. Open Settings anytime to rename categories, change limits, or pick different apps.")
                .font(.system(size: 14))
                .foregroundStyle(FiltrTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.categories.filter(\.enabled)) { config in
                    setupBullet("\(config.displayName): \(config.dailyLimitMinutes) min · \(config.mappings.count) items")
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
    }

    private var footerBar: some View {
        HStack {
            if step != .welcome {
                Button("Back") {
                    if let prev = SetupStep(rawValue: step.rawValue - 1) {
                        withAnimation(.easeInOut(duration: 0.2)) { step = prev }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(FiltrTheme.muted)
            }
            Spacer()
            Button(primaryTitle) {
                if step == .ready {
                    store.completeSetup()
                    onFinished()
                } else if let next = SetupStep(rawValue: step.rawValue + 1) {
                    withAnimation(.easeInOut(duration: 0.2)) { step = next }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(FiltrTheme.ink)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var stepTitle: String {
        switch step {
        case .welcome: return "Setup · Welcome"
        case .limits: return "Setup · Limits"
        case .apps: return "Setup · Apps & sites"
        case .permissions: return "Setup · Permissions"
        case .ready: return "Setup · Ready"
        }
    }

    private var primaryTitle: String {
        step == .ready ? "Start using Filtr" : "Continue"
    }

    private func setupBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(FiltrTheme.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(FiltrTheme.ink.opacity(0.85))
        }
    }

    private func permissionCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FiltrTheme.ink)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(FiltrTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }
}

struct SetupLimitRow: View {
    @ObservedObject var store: FiltrStore
    let config: CategoryConfig
    @State private var nameText = ""

    var body: some View {
        let live = store.category(for: config.id) ?? config
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { store.category(for: config.id)?.enabled ?? false },
                    set: { store.setEnabled($0, for: config.id) }
                )) {
                    EmptyView()
                }
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(FiltrTheme.accent)

                TextField("Category name", text: $nameText)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { nameText = live.name }
                    .onSubmit { store.renameCategory(config.id, to: nameText) }

                Spacer()

                Stepper(value: Binding(
                    get: { store.category(for: config.id)?.dailyLimitMinutes ?? config.dailyLimitMinutes },
                    set: { store.setLimit(minutes: $0, for: config.id) }
                ), in: 5...24 * 60, step: 5) {
                    Text("\(live.dailyLimitMinutes) min")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(FiltrTheme.muted)
                        .frame(minWidth: 64, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
        .onDisappear { store.renameCategory(config.id, to: nameText) }
    }
}

struct SetupAppsRow: View {
    @ObservedObject var store: FiltrStore
    let config: CategoryConfig
    var onChoose: () -> Void

    var body: some View {
        let live = store.category(for: config.id) ?? config
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(live.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FiltrTheme.ink)
                Spacer()
                Text("\(live.mappings.count) selected")
                    .font(.system(size: 12))
                    .foregroundStyle(FiltrTheme.muted)
            }

            if live.mappings.isEmpty {
                Text(live.id == .other
                       ? "Off until you assign apps or sites."
                       : "No apps yet — choose what should count.")
                    .font(.system(size: 12))
                    .foregroundStyle(FiltrTheme.muted)
            } else {
                Text(live.mappings.prefix(4).map(\.appName).joined(separator: ", ")
                      + (live.mappings.count > 4 ? "…" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(FiltrTheme.muted)
                    .lineLimit(2)
            }

            Button(action: onChoose) {
                Label("Choose apps & sites…", systemImage: "plus.app")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(FiltrTheme.accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }
}
