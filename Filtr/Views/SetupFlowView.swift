import AppKit
import SwiftUI

enum SetupStep: Int, CaseIterable {
    case welcome
    case limits
    case permissions
    case ready
}

struct SetupFlowView: View {
    @ObservedObject var store: FiltrStore
    var onFinished: () -> Void

    @State private var step: SetupStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.25)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().opacity(0.25)
            footerBar
        }
        .frame(width: 520, height: 420)
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
        case .welcome:
            welcomeStep
        case .limits:
            limitsStep
        case .permissions:
            permissionsStep
        case .ready:
            readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Know your limits.\nBend them when you mean to.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(FiltrTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Filtr lives in your menu bar and gently nudges you when daily time on YouTube, gaming, or other distractions runs out — never a hard lockout.")
                .font(.system(size: 14))
                .foregroundStyle(FiltrTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                setupBullet("Soft extends: +1 min, +15 min, or for today")
                setupBullet("Tracks apps and browser sites (best-effort)")
                setupBullet("Everything stays on this Mac")
            }
            .padding(.top, 6)
        }
        .padding(28)
    }

    private var limitsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set today’s starting limits")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(FiltrTheme.ink)
            Text("You can change these anytime in Settings. Other is off until you assign apps or sites to it.")
                .font(.system(size: 13))
                .foregroundStyle(FiltrTheme.muted)

            ForEach(store.categories) { config in
                SetupLimitRow(store: store, config: config)
            }
        }
        .padding(28)
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browser tracking (optional)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(FiltrTheme.ink)
            Text("App limits work immediately. To count YouTube and other sites in Safari or Chrome, Filtr needs permission to read the active tab URL.")
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
            Text("Filtr is in the menu bar. Click the hourglass anytime to see today’s usage. Updates install in the background when a new version is published.")
                .font(.system(size: 14))
                .foregroundStyle(FiltrTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                setupBullet("Keep Filtr running while you work")
                setupBullet("Soft nudge when a limit is hit — extend or dismiss")
                setupBullet("Check for Updates anytime in Settings")
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
        case .permissions: return "Setup · Permissions"
        case .ready: return "Setup · Ready"
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return "Continue"
        case .limits: return "Continue"
        case .permissions: return "Continue"
        case .ready: return "Start using Filtr"
        }
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
    @State private var minutesText = ""

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { store.category(for: config.id)?.enabled ?? false },
                set: { store.setEnabled($0, for: config.id) }
            )) {
                Text(config.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .toggleStyle(.switch)
            .tint(FiltrTheme.accent)

            Spacer()

            TextField("min", text: $minutesText)
                .frame(width: 52)
                .textFieldStyle(.roundedBorder)
                .onAppear { minutesText = "\(config.dailyLimitMinutes)" }
                .onSubmit { commit() }
            Text("min")
                .font(.system(size: 12))
                .foregroundStyle(FiltrTheme.muted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
        .onDisappear { commit() }
    }

    private func commit() {
        if let value = Int(minutesText.trimmingCharacters(in: .whitespaces)) {
            store.setLimit(minutes: value, for: config.id)
        }
    }
}
