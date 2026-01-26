import Foundation

/// Represents a single sleep period with detailed stage information.
/// A night may contain multiple sleep periods if sleep was interrupted.
struct SleepPeriod: Codable, Identifiable, Equatable {
    let id: String
    let day: String
    let bedtimeStart: String
    let bedtimeEnd: String
    let duration: Int
    let totalSleepDuration: Int?
    let awakeTime: Int?
    let lightSleepDuration: Int?
    let remSleepDuration: Int?
    let deepSleepDuration: Int?
    let restlessPeriods: Int?
    let efficiency: Int?
    let latency: Int?
    let averageHeartRate: Double?
    let lowestHeartRate: Int?
    let averageHrv: Int?
    let type: SleepType

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case bedtimeStart = "bedtime_start"
        case bedtimeEnd = "bedtime_end"
        case duration
        case totalSleepDuration = "total_sleep_duration"
        case awakeTime = "awake_time"
        case lightSleepDuration = "light_sleep_duration"
        case remSleepDuration = "rem_sleep_duration"
        case deepSleepDuration = "deep_sleep_duration"
        case restlessPeriods = "restless_periods"
        case efficiency
        case latency
        case averageHeartRate = "average_heart_rate"
        case lowestHeartRate = "lowest_heart_rate"
        case averageHrv = "average_hrv"
        case type
    }

    /// Type of sleep period.
    enum SleepType: String, Codable {
        case longSleep = "long_sleep"
        case sleep
        case nap
        case rest
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            self = SleepType(rawValue: value) ?? .unknown
        }
    }

    /// Aggregated sleep stage durations for easy access.
    struct SleepStages: Equatable {
        let deep: Int
        let rem: Int
        let light: Int
        let awake: Int

        var total: Int {
            deep + rem + light
        }
    }
}

// MARK: - Computed Display Properties

extension SleepPeriod {
    /// Aggregated sleep stages from individual duration properties.
    var stages: SleepStages {
        SleepStages(
            deep: deepSleepDuration ?? 0,
            rem: remSleepDuration ?? 0,
            light: lightSleepDuration ?? 0,
            awake: awakeTime ?? 0
        )
    }

    /// Total sleep duration formatted as hours and minutes (e.g., "7h 32m").
    var durationDisplay: String {
        formatDuration(seconds: totalSleepDuration ?? duration)
    }

    /// Deep sleep duration formatted (e.g., "1h 15m").
    var deepSleepDisplay: String {
        formatDuration(seconds: deepSleepDuration ?? 0)
    }

    /// REM sleep duration formatted (e.g., "1h 45m").
    var remSleepDisplay: String {
        formatDuration(seconds: remSleepDuration ?? 0)
    }

    /// Light sleep duration formatted (e.g., "4h 20m").
    var lightSleepDisplay: String {
        formatDuration(seconds: lightSleepDuration ?? 0)
    }

    /// Awake time formatted (e.g., "32m").
    var awakeTimeDisplay: String {
        formatDuration(seconds: awakeTime ?? 0)
    }

    /// Sleep efficiency as a percentage string (e.g., "92%").
    var efficiencyDisplay: String {
        guard let efficiency else { return "--" }
        return "\(efficiency)%"
    }

    /// Bedtime formatted for display (e.g., "10:30 PM").
    var bedtimeStartDisplay: String {
        formatTime(from: bedtimeStart)
    }

    /// Wake time formatted for display (e.g., "6:45 AM").
    var bedtimeEndDisplay: String {
        formatTime(from: bedtimeEnd)
    }

    /// Efficiency quality level for UI styling.
    var efficiencyQuality: ScoreQuality {
        guard let efficiency else { return .unknown }
        return ScoreQuality(score: efficiency)
    }

    // MARK: - Private Helpers

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatTime(from isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        var date = isoFormatter.date(from: isoString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }

        guard let parsedDate = date else { return isoString }

        let displayFormatter = DateFormatter()
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: parsedDate)
    }
}
