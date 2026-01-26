import SwiftUI

/// A view displaying 7-day trend data with sparklines.
struct TrendsView: View {
    let readinessAverage: Int?
    let sleepAverage: Int?
    let readinessHistory: [Int]
    let sleepHistory: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Trends")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                trendCard(title: "Readiness", average: readinessAverage, history: readinessHistory, icon: "bolt.fill")
                trendCard(title: "Sleep", average: sleepAverage, history: sleepHistory, icon: "moon.fill")
            }
        }
    }

    @ViewBuilder
    private func trendCard(title: String, average: Int?, history: [Int], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let avg = average {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(avg)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("avg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            if !history.isEmpty {
                SparklineView(values: history)
                    .frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// A simple sparkline chart view.
struct SparklineView: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geometry in
            let maxVal = Double(values.max() ?? 100)
            let minVal = Double(values.min() ?? 0)
            let range = max(maxVal - minVal, 1)

            Path { path in
                guard values.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(values.count - 1)
                let height = geometry.size.height

                for (index, value) in values.enumerated() {
                    let xPosition = CGFloat(index) * stepX
                    let normalizedY = (Double(value) - minVal) / range
                    let yPosition = height - (CGFloat(normalizedY) * height)

                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
