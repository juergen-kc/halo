import SwiftUI

/// A data point for the trend line chart.
struct TrendDataPoint: Identifiable, Equatable {
    let id: String
    let date: String
    let value: Double

    /// Creates a data point from a date string and integer value.
    init(date: String, value: Int) {
        self.id = "\(date)-\(value)"
        self.date = date
        self.value = Double(value)
    }

    /// Creates a data point from a date string and double value.
    init(date: String, value: Double) {
        self.id = "\(date)-\(value)"
        self.date = date
        self.value = value
    }
}

/// A line chart view that displays trend data with smooth curves and interactive data points.
/// Supports hover/tap to show exact values for each data point.
struct TrendLineChartView: View {
    let dataPoints: [TrendDataPoint]
    let lineColor: Color
    let unit: String
    let title: String
    let icon: String

    /// The currently selected data point index (for hover/tap).
    @State private var selectedIndex: Int?

    /// Padding for the chart area.
    private let chartPadding: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerView
            chartView
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if let index = selectedIndex, index < dataPoints.count {
                let point = dataPoints[index]
                Text(formatValue(point.value))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(lineColor)
            } else if let lastPoint = dataPoints.last {
                Text(formatValue(lastPoint.value))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private var chartView: some View {
        if dataPoints.count < 2 {
            noDataView
        } else {
            GeometryReader { geometry in
                let points = calculatePoints(in: geometry.size)

                ZStack {
                    // Grid lines (subtle)
                    gridLines(in: geometry.size)

                    // Smooth curve line
                    smoothCurvePath(points: points)
                        .stroke(
                            lineColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                    // Gradient fill under the curve
                    smoothCurvePath(points: points)
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.3), lineColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(
                            AreaClipShape(points: points, height: geometry.size.height)
                        )

                    // Data points
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(selectedIndex == index ? lineColor : Color.white)
                            .frame(width: selectedIndex == index ? 8 : 5, height: selectedIndex == index ? 8 : 5)
                            .overlay(
                                Circle()
                                    .stroke(lineColor, lineWidth: selectedIndex == index ? 2 : 1.5)
                            )
                            .position(point)
                    }

                    // Tooltip for selected point
                    if let index = selectedIndex, index < points.count, index < dataPoints.count {
                        tooltipView(for: index, at: points[index], in: geometry.size)
                    }

                    // Invisible touch targets for interaction
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 30, height: 30)
                            .position(point)
                            .contentShape(Circle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedIndex = selectedIndex == index ? nil : index
                                }
                            }
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if hovering {
                                        selectedIndex = index
                                    } else if selectedIndex == index {
                                        selectedIndex = nil
                                    }
                                }
                            }
                    }
                }
            }
            .frame(height: 60)
        }
    }

    // MARK: - No Data View

    @ViewBuilder
    private var noDataView: some View {
        Text("Insufficient data")
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Grid Lines

    @ViewBuilder
    private func gridLines(in size: CGSize) -> some View {
        Path { path in
            // Horizontal grid lines (3 lines)
            for i in 0..<3 {
                let y = chartPadding + (size.height - 2 * chartPadding) * CGFloat(i) / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
    }

    // MARK: - Tooltip View

    @ViewBuilder
    private func tooltipView(for index: Int, at point: CGPoint, in size: CGSize) -> some View {
        let dataPoint = dataPoints[index]

        VStack(spacing: 2) {
            Text(formatValue(dataPoint.value))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Text(formatDate(dataPoint.date))
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        .position(
            x: clampX(point.x, in: size),
            y: max(point.y - 28, 20)
        )
    }

    // MARK: - Helpers

    /// Calculates the chart points from data.
    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard !dataPoints.isEmpty else { return [] }

        let values = dataPoints.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let range = max(maxValue - minValue, 1)

        // Add some padding to the range for visual appeal
        let paddedMin = minValue - range * 0.1
        let paddedMax = maxValue + range * 0.1
        let paddedRange = paddedMax - paddedMin

        let chartWidth = size.width - 2 * chartPadding
        let chartHeight = size.height - 2 * chartPadding

        return dataPoints.enumerated().map { index, point in
            let x = chartPadding + chartWidth * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
            let normalizedY = (point.value - paddedMin) / paddedRange
            let y = chartPadding + chartHeight * (1 - CGFloat(normalizedY))
            return CGPoint(x: x, y: y)
        }
    }

    /// Creates a smooth curve path through the given points using Catmull-Rom spline interpolation.
    private func smoothCurvePath(points: [CGPoint]) -> Path {
        Path { path in
            guard points.count >= 2 else { return }

            path.move(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
                return
            }

            // Use Catmull-Rom spline for smoother curves
            for i in 0..<(points.count - 1) {
                let p0 = i > 0 ? points[i - 1] : points[0]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = i < points.count - 2 ? points[i + 2] : points[points.count - 1]

                // Calculate control points for cubic Bezier
                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: p1.y + (p2.y - p0.y) / 6
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: p2.y - (p3.y - p1.y) / 6
                )

                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    /// Formats the value with unit.
    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))\(unit)"
        }
        return String(format: "%.1f\(unit)", value)
    }

    /// Formats the date for display.
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Clamps X position to keep tooltip within bounds.
    private func clampX(_ x: CGFloat, in size: CGSize) -> CGFloat {
        let padding: CGFloat = 30
        return max(padding, min(x, size.width - padding))
    }
}

// MARK: - Area Clip Shape

/// A shape that clips to the area under the curve for gradient fill.
private struct AreaClipShape: Shape {
    let points: [CGPoint]
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            guard points.count >= 2 else { return }

            // Start at bottom-left
            path.move(to: CGPoint(x: points[0].x, y: height))

            // Line up to first point
            path.addLine(to: points[0])

            // Follow the smooth curve
            if points.count == 2 {
                path.addLine(to: points[1])
            } else {
                for i in 0..<(points.count - 1) {
                    let p0 = i > 0 ? points[i - 1] : points[0]
                    let p1 = points[i]
                    let p2 = points[i + 1]
                    let p3 = i < points.count - 2 ? points[i + 2] : points[points.count - 1]

                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )

                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }

            // Line down to bottom-right
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))

            // Close the path
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        TrendLineChartView(
            dataPoints: [
                TrendDataPoint(date: "2024-01-20", value: 75),
                TrendDataPoint(date: "2024-01-21", value: 82),
                TrendDataPoint(date: "2024-01-22", value: 78),
                TrendDataPoint(date: "2024-01-23", value: 85),
                TrendDataPoint(date: "2024-01-24", value: 88),
                TrendDataPoint(date: "2024-01-25", value: 82),
                TrendDataPoint(date: "2024-01-26", value: 90)
            ],
            lineColor: .green,
            unit: "%",
            title: "Sleep Score",
            icon: "moon.fill"
        )

        TrendLineChartView(
            dataPoints: [
                TrendDataPoint(date: "2024-01-20", value: 42),
                TrendDataPoint(date: "2024-01-21", value: 45),
                TrendDataPoint(date: "2024-01-22", value: 38),
                TrendDataPoint(date: "2024-01-23", value: 50),
                TrendDataPoint(date: "2024-01-24", value: 48),
                TrendDataPoint(date: "2024-01-25", value: 52),
                TrendDataPoint(date: "2024-01-26", value: 47)
            ],
            lineColor: .purple,
            unit: " ms",
            title: "HRV",
            icon: "waveform.path.ecg"
        )
    }
    .padding()
    .frame(width: 300)
}
