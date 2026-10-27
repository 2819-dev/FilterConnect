import SwiftUI

struct SoftLimitView: View {
    let category: CategoryID
    @ObservedObject var store: FiltrStore
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Filtr")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FiltrTheme.accent)
                    .tracking(0.6)

                Text("You’ve reached your limit for today")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(FiltrTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(category.displayName)
                    .font(.system(size: 13))
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
            .font(.system(size: 12))
            .foregroundStyle(FiltrTheme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(22)
        .frame(width: 360)
        .background(FiltrTheme.wash)
    }

    private func extendButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(FiltrTheme.ink)
                )
                .foregroundStyle(FiltrTheme.wash)
        }
        .buttonStyle(.plain)
    }
}
