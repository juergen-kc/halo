import SwiftUI

/// A circular progress ring indicator displaying a score with label.
/// Used to visualize Sleep and Readiness scores in the dashboard.
struct CircularProgressView: View {
    /// The score to display (0-100), or nil if no data is available.
    let score: Int?

    /// The quality level determining the ring color.
    let quality: ScoreQuality

    /// The label displayed beneath the ring.
    let label: String

    /// The size of the circular indicator.
    private let ringSize: CGFloat = 80

    /// The width of the progress ring stroke.
    private let ringWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring (gray track)
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: ringWidth)

                // Colored progress ring
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progressValue)

                // Score text in center
                if let score {
                    Text("\(score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(ringColor)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Label beneath the ring
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed Properties

    /// The progress value for the ring (0.0 to 1.0).
    private var progressValue: CGFloat {
        guard let score else { return 0 }
        return CGFloat(score) / 100.0
    }

    /// The color of the ring based on the quality level.
    /// Uses the menu bar color scheme: green (85+), yellow (70-84), red (<70).
    private var ringColor: Color {
        switch quality.menuBarColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Previews

#Preview("All States") {
    HStack(spacing: 24) {
        CircularProgressView(score: 92, quality: .optimal, label: "Sleep")
        CircularProgressView(score: 78, quality: .good, label: "Readiness")
        CircularProgressView(score: 55, quality: .attention, label: "Activity")
        CircularProgressView(score: nil, quality: .unknown, label: "No Data")
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Dashboard Layout") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Today's Scores")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)

        HStack(spacing: 24) {
            CircularProgressView(score: 85, quality: .optimal, label: "Readiness")
            CircularProgressView(score: 72, quality: .good, label: "Sleep")
        }
        .frame(maxWidth: .infinity)
    }
    .padding(16)
    .background(Color(nsColor: .windowBackgroundColor))
}
