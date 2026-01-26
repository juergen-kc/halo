import Foundation

/// Represents daily sleep summary data from the Oura API.
/// Contains overall sleep score and contributing factors.
struct DailySleep: Codable, Identifiable, Equatable {
    let id: String
    let day: String
    let score: Int?
    let timestamp: String
    let contributors: SleepContributors

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case score
        case timestamp
        case contributors
    }

    /// Individual factors that contribute to the overall sleep score.
    struct SleepContributors: Codable, Equatable {
        let deepSleep: Int?
        let efficiency: Int?
        let latency: Int?
        let remSleep: Int?
        let restfulness: Int?
        let timing: Int?
        let totalSleep: Int?

        enum CodingKeys: String, CodingKey {
            case deepSleep = "deep_sleep"
            case efficiency
            case latency
            case remSleep = "rem_sleep"
            case restfulness
            case timing
            case totalSleep = "total_sleep"
        }
    }
}

// MARK: - Computed Display Properties

extension DailySleep {
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

    /// Score quality level for UI styling.
    var scoreQuality: ScoreQuality {
        guard let score else { return .unknown }
        return ScoreQuality(score: score)
    }
}
