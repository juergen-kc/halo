import SwiftUI

/// A view displaying sleep stages as a horizontal stacked bar chart.
/// Shows Deep, REM, Light, and Awake segments with durations and optional percentages.
struct SleepStagesView: View {
    let sleepPeriod: SleepPeriod

    /// Whether to show percentages instead of durations in the legend.
    @State private var showPercentages = false

    /// Individual sleep stage data for rendering.
    private struct StageData: Identifiable {
        let id = UUID()
        let name: String
        let duration: Int // in seconds
        let color: Color
        let icon: String
    }

    /// All sleep stages with their associated colors and icons.
    private var stages: [StageData] {
        [
            StageData(
                name: "Deep",
                duration: sleepPeriod.stages.deep,
                color: .indigo,
                icon: "waveform.path.ecg"
            ),
            StageData(
                name: "REM",
                duration: sleepPeriod.stages.rem,
                color: .purple,
                icon: "brain.head.profile"
            ),
            StageData(
                name: "Light",
                duration: sleepPeriod.stages.light,
                color: .blue,
                icon: "moon.fill"
            ),
            StageData(
                name: "Awake",
                duration: sleepPeriod.stages.awake,
                color: Color.secondary.opacity(0.5),
                icon: "eye.fill"
            )
        ]
    }

    /// Total time in bed (all stages including awake).
    private var totalTimeInBed: Int {
        stages.reduce(0) { $0 + $1.duration }
    }

    /// Total actual sleep time (excluding awake).
    private var totalSleepTime: Int {
        sleepPeriod.stages.total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection

            VStack(spacing: 10) {
                stackedBarChart
                legendGrid
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("Sleep Stages")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPercentages.toggle()
                }
            } label: {
                Text(showPercentages ? "Duration" : "Percent")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help(showPercentages ? "Show durations" : "Show percentages")
        }
    }

    // MARK: - Stacked Bar Chart

    @ViewBuilder
    private var stackedBarChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Total sleep time label
            HStack {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Total: \(formatDuration(seconds: totalSleepTime))")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(sleepPeriod.bedtimeStartDisplay + " – " + sleepPeriod.bedtimeEndDisplay)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Horizontal stacked bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(stages) { stage in
                        let ratio = totalTimeInBed > 0
                            ? CGFloat(stage.duration) / CGFloat(totalTimeInBed)
                            : 0
                        if ratio > 0 {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(stage.color)
                                .frame(width: geometry.size.width * ratio)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 12)
        }
    }

    // MARK: - Legend Grid

    @ViewBuilder
    private var legendGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 6) {
            ForEach(stages) { stage in
                legendItem(stage: stage)
            }
        }
    }

    @ViewBuilder
    private func legendItem(stage: StageData) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stage.color)
                .frame(width: 8, height: 8)

            Image(systemName: stage.icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 12)

            Text(stage.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            if showPercentages {
                let percentage = totalTimeInBed > 0
                    ? (Double(stage.duration) / Double(totalTimeInBed)) * 100
                    : 0
                Text(String(format: "%.0f%%", percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 32, alignment: .trailing)
            } else {
                Text(formatDuration(seconds: stage.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
