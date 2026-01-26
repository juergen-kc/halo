import SwiftUI

/// A view that displays the menu bar icon with a circular ring and readiness score.
/// The ring color reflects the readiness status: green (85+), yellow (70-84), red (<70).
struct MenuBarIconView: View {
    /// The readiness score to display (0-100), or nil if no data is available.
    let score: Int?

    /// The quality level determining the ring color.
    let quality: ScoreQuality

    /// Whether data is currently being loaded.
    let isLoading: Bool

    /// The size of the icon (menu bar icons are typically 18-22 points).
    private let iconSize: CGFloat = 18

    /// The width of the circular ring stroke.
    private let ringWidth: CGFloat = 2

    var body: some View {
        ZStack {
            // Background ring (gray track)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: ringWidth)

            // Colored progress ring
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Score text or fallback icon
            if isLoading {
                // Show a subtle loading indicator
                Image(systemName: "ellipsis")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            } else if let score {
                Text("\(score)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            } else {
                // Fallback when no data is available
                Image(systemName: "questionmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: iconSize, height: iconSize)
    }

    // MARK: - Computed Properties

    /// The progress value for the ring (0.0 to 1.0).
    private var progressValue: CGFloat {
        guard let score else { return 0 }
        return CGFloat(score) / 100.0
    }

    /// The color of the ring based on the quality level.
    private var ringColor: Color {
        switch quality.menuBarColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Convenience Initializer

extension MenuBarIconView {
    /// Creates a menu bar icon view from an optional readiness data object.
    /// - Parameters:
    ///   - readiness: The daily readiness data, or nil if not available.
    ///   - isLoading: Whether data is currently being loaded.
    init(readiness: DailyReadiness?, isLoading: Bool = false) {
        self.score = readiness?.score
        self.quality = readiness?.scoreQuality ?? .unknown
        self.isLoading = isLoading
    }
}

// MARK: - Previews

#Preview("High Score") {
    HStack(spacing: 20) {
        MenuBarIconView(score: 92, quality: .optimal, isLoading: false)
        MenuBarIconView(score: 78, quality: .good, isLoading: false)
        MenuBarIconView(score: 65, quality: .fair, isLoading: false)
        MenuBarIconView(score: 45, quality: .attention, isLoading: false)
        MenuBarIconView(score: nil, quality: .unknown, isLoading: false)
        MenuBarIconView(score: nil, quality: .unknown, isLoading: true)
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
