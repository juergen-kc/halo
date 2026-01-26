import SwiftUI

/// A view displaying trend line graphs for key health metrics.
/// Shows Sleep Score, Readiness Score, HRV, and Resting Heart Rate trends over time.
struct TrendGraphsView: View {
    let sleepHistory: [DailySleep]
    let readinessHistory: [DailyReadiness]
    let hrvHistory: [(day: String, value: Int)]
    let restingHRHistory: [(day: String, value: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend Graphs")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // Sleep Score trend
                TrendLineChartView(
                    dataPoints: sleepDataPoints,
                    lineColor: .blue,
                    unit: "%",
                    title: "Sleep Score",
                    icon: "moon.fill"
                )

                // Readiness Score trend
                TrendLineChartView(
                    dataPoints: readinessDataPoints,
                    lineColor: .green,
                    unit: "%",
                    title: "Readiness Score",
                    icon: "bolt.fill"
                )

                // HRV trend
                TrendLineChartView(
                    dataPoints: hrvDataPoints,
                    lineColor: .purple,
                    unit: " ms",
                    title: "HRV",
                    icon: "waveform.path.ecg"
                )

                // Resting Heart Rate trend
                TrendLineChartView(
                    dataPoints: restingHRDataPoints,
                    lineColor: .red,
                    unit: " bpm",
                    title: "Resting HR",
                    icon: "heart.fill"
                )
            }
        }
    }

    // MARK: - Data Point Conversions

    private var sleepDataPoints: [TrendDataPoint] {
        sleepHistory.compactMap { sleep in
            guard let score = sleep.score else { return nil }
            return TrendDataPoint(date: sleep.day, value: score)
        }
    }

    private var readinessDataPoints: [TrendDataPoint] {
        readinessHistory.compactMap { readiness in
            guard let score = readiness.score else { return nil }
            return TrendDataPoint(date: readiness.day, value: score)
        }
    }

    private var hrvDataPoints: [TrendDataPoint] {
        hrvHistory.map { TrendDataPoint(date: $0.day, value: $0.value) }
    }

    private var restingHRDataPoints: [TrendDataPoint] {
        restingHRHistory.map { TrendDataPoint(date: $0.day, value: $0.value) }
    }
}

// MARK: - Preview

#Preview {
    TrendGraphsView(
        sleepHistory: PreviewData.sleepHistory,
        readinessHistory: PreviewData.readinessHistory,
        hrvHistory: PreviewData.hrvHistory,
        restingHRHistory: PreviewData.restingHRHistory
    )
    .padding()
    .frame(width: 320)
}

// MARK: - Preview Data

private enum PreviewData {
    static let sleepHistory: [DailySleep] = (0..<7).map { index in
        let scores = [75, 82, 78, 85, 88, 82, 90]
        return DailySleep(
            id: "\(index + 1)",
            day: "2024-01-\(20 + index)",
            score: scores[index],
            timestamp: "2024-01-\(20 + index)T00:00:00Z",
            contributors: DailySleep.SleepContributors(
                deepSleep: 80 + index,
                efficiency: 85 + index,
                latency: 90,
                remSleep: 75 + index,
                restfulness: 70 + index,
                timing: 80,
                totalSleep: 78 + index
            )
        )
    }

    static let readinessHistory: [DailyReadiness] = (0..<7).map { index in
        let scores = [72, 78, 75, 82, 85, 80, 88]
        return DailyReadiness(
            id: "\(index + 1)",
            day: "2024-01-\(20 + index)",
            score: scores[index],
            temperatureDeviation: Double(index - 3) * 0.05,
            temperatureTrendDeviation: Double(index - 3) * 0.02,
            timestamp: "2024-01-\(20 + index)T00:00:00Z",
            contributors: DailyReadiness.ReadinessContributors(
                activityBalance: 75 + index * 2,
                bodyTemperature: 80 + index * 2,
                hrvBalance: 70 + index * 3,
                previousDayActivity: 72 + index * 2,
                previousNight: 75 + index * 2,
                recoveryIndex: 78 + index * 2,
                restingHeartRate: 80 + index * 2,
                sleepBalance: 72 + index * 2
            )
        )
    }

    static let hrvHistory: [(day: String, value: Int)] = [
        (day: "2024-01-20", value: 42),
        (day: "2024-01-21", value: 45),
        (day: "2024-01-22", value: 38),
        (day: "2024-01-23", value: 50),
        (day: "2024-01-24", value: 48),
        (day: "2024-01-25", value: 52),
        (day: "2024-01-26", value: 47)
    ]

    static let restingHRHistory: [(day: String, value: Int)] = [
        (day: "2024-01-20", value: 58),
        (day: "2024-01-21", value: 56),
        (day: "2024-01-22", value: 60),
        (day: "2024-01-23", value: 55),
        (day: "2024-01-24", value: 54),
        (day: "2024-01-25", value: 57),
        (day: "2024-01-26", value: 53)
    ]
}
