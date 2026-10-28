import SwiftUI

struct SoftLimitView: View {
    let category: CategoryID
    @ObservedObject var store: FiltrStore
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Filtr")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FiltrTheme.accent)
                    .tracking(0.8)

                Text("You’ve reached your limit for today")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(category.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FiltrTheme.muted)
            }

            HStack(spacing: 8) {
                extendButton("+1 min") {
                    store.extend(minutes: 1, category: category)
                    onClose()
                }
                extendButton("+15 min") {
                    store.extend(minutes: 15, category: category)
                    onClose()
                }
                extendButton("For today") {
                    store.unlockForToday(category: category)
                    onClose()
                }
            }

            Button("Dismiss") {
                store.dismissSoftLimit(category: category)
                onClose()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(FiltrTheme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .frame(width: 360)
        .background(
            LinearGradient(
                colors: [FiltrTheme.wash, Color(red: 0.94, green: 0.93, blue: 0.91)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func extendButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(FiltrTheme.ink)
                )
                .foregroundStyle(FiltrTheme.wash)
        }
        .buttonStyle(.plain)
    }
}
