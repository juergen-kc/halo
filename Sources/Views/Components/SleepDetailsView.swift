import SwiftUI

/// A view displaying detailed sleep contributor scores.
struct SleepDetailsView: View {
    let sleep: DailySleep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Details")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                contributorRow(label: "Total Sleep", value: sleep.contributors.totalSleep, icon: "clock.fill")
                contributorRow(label: "Deep Sleep", value: sleep.contributors.deepSleep, icon: "waveform.path.ecg")
                contributorRow(label: "REM Sleep", value: sleep.contributors.remSleep, icon: "brain.head.profile")
                contributorRow(label: "Efficiency", value: sleep.contributors.efficiency, icon: "chart.bar.fill")
                contributorRow(label: "Restfulness", value: sleep.contributors.restfulness, icon: "heart.fill")
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func contributorRow(label: String, value: Int?, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            if let value {
                contributorBar(value: value)
                Text("\(value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .trailing)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func contributorBar(value: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(scoreColor(for: ScoreQuality(score: value)))
                    .frame(width: geometry.size.width * CGFloat(value) / 100, height: 4)
            }
        }
        .frame(width: 60, height: 4)
    }

    private func scoreColor(for quality: ScoreQuality) -> Color {
        switch quality.menuBarColorName {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}
