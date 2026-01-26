import Foundation

/// Represents daily readiness data from the Oura API.
/// Readiness indicates how prepared the body is for the day ahead.
struct DailyReadiness: Codable, Identifiable, Equatable {
    let id: String
    let day: String
    let score: Int?
    let temperatureDeviation: Double?
    let temperatureTrendDeviation: Double?
    let timestamp: String
    let contributors: ReadinessContributors

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case score
        case temperatureDeviation = "temperature_deviation"
        case temperatureTrendDeviation = "temperature_trend_deviation"
        case timestamp
        case contributors
    }

    /// Individual factors that contribute to the overall readiness score.
    struct ReadinessContributors: Codable, Equatable {
        let activityBalance: Int?
        let bodyTemperature: Int?
        let hrvBalance: Int?
        let previousDayActivity: Int?
        let previousNight: Int?
        let recoveryIndex: Int?
        let restingHeartRate: Int?
        let sleepBalance: Int?

        enum CodingKeys: String, CodingKey {
            case activityBalance = "activity_balance"
            case bodyTemperature = "body_temperature"
            case hrvBalance = "hrv_balance"
            case previousDayActivity = "previous_day_activity"
            case previousNight = "previous_night"
            case recoveryIndex = "recovery_index"
            case restingHeartRate = "resting_heart_rate"
            case sleepBalance = "sleep_balance"
        }
    }
}

// MARK: - Computed Display Properties

extension DailyReadiness {
    /// Formatted date string for display (e.g., "Jan 26, 2026").
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return day }

        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Score as a percentage string (e.g., "85%").
    var scoreDisplay: String {
        guard let score else { return "--" }
        return "\(score)%"
    }

    /// Temperature deviation formatted for display (e.g., "+0.5°C" or "-0.3°C").
    var temperatureDeviationDisplay: String {
        guard let deviation = temperatureDeviation else { return "--" }
        let sign = deviation >= 0 ? "+" : ""
        return String(format: "%@%.1f°C", sign, deviation)
    }

    /// Score quality level for UI styling.
    var scoreQuality: ScoreQuality {
        guard let score else { return .unknown }
        return ScoreQuality(score: score)
    }
}
