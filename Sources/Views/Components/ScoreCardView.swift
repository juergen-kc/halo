import SwiftUI

/// A card view displaying a health score with quality indicator.
struct ScoreCardView: View {
    let title: String
    let score: Int?
    let quality: ScoreQuality
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(scoreColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let score {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    Text("%")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(scoreColor.opacity(0.7))
                } else {
                    Text("--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(scoreColor)
                    .frame(width: 6, height: 6)
                Text(quality.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var scoreColor: Color {
        switch quality.menuBarColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}
