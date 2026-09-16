import SwiftUI
import VibePMCore

enum VibeTheme {
    static let accent = Color(red: 0.36, green: 0.35, blue: 0.92)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let elevatedSurface = Color(nsColor: .controlBackgroundColor)
    static let subtleBorder = Color.primary.opacity(0.08)
    static let secondaryText = Color.secondary

    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.48, green: 0.42, blue: 0.98),
            Color(red: 0.24, green: 0.56, blue: 0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension ProjectAccent {
    var color: Color {
        switch self {
        case .indigo: Color(red: 0.36, green: 0.35, blue: 0.92)
        case .blue: Color(red: 0.18, green: 0.52, blue: 0.92)
        case .mint: Color(red: 0.12, green: 0.68, blue: 0.56)
        case .orange: Color(red: 0.95, green: 0.51, blue: 0.18)
        case .rose: Color(red: 0.92, green: 0.30, blue: 0.48)
        case .purple: Color(red: 0.65, green: 0.32, blue: 0.88)
        }
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }
}

private struct VibeCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VibeTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(VibeTheme.subtleBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 6, y: 2)
    }
}

extension View {
    func vibeCard() -> some View {
        modifier(VibeCardModifier())
    }
}

struct CountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count.formatted())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.07), in: Capsule())
                .accessibilityLabel("\(count) Tasks")
        }
    }
}

