import Foundation

/// Represents heart rate data including HRV (Heart Rate Variability) and resting heart rate.
/// HRV is measured in milliseconds and indicates autonomic nervous system health.
struct HeartRate: Codable, Identifiable, Equatable {
    let id: String
    let day: String
    let timestamp: String
    let bpm: Int
    let source: HeartRateSource

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case timestamp
        case bpm
        case source
    }

    /// Source of the heart rate measurement.
    enum HeartRateSource: String, Codable {
        case awake
        case rest
        case sleep
        case session
        case live
        case workout
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            self = HeartRateSource(rawValue: value) ?? .unknown
        }
    }
}

// MARK: - Computed Display Properties

extension HeartRate {
    /// Heart rate formatted with units (e.g., "62 bpm").
    var bpmDisplay: String {
        "\(bpm) bpm"
    }

    /// Formatted timestamp for display.
    var formattedTimestamp: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = isoFormatter.date(from: timestamp)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: timestamp)
        }

        guard let parsedDate = date else { return timestamp }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: parsedDate)
    }
}

/// Represents Heart Rate Variability data.
/// HRV is a key indicator of recovery and autonomic nervous system health.
struct HRVData: Codable, Identifiable, Equatable {
    let id: String
    let day: String
    let timestamp: String
    let hrv: Int

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case timestamp
        case hrv
    }
}

// MARK: - HRV Computed Display Properties

extension HRVData {
    /// HRV formatted with units (e.g., "45 ms").
    var hrvDisplay: String {
        "\(hrv) ms"
    }

    /// Formatted date string for display.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return day }

        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// HRV quality level for UI styling.
    /// Note: HRV is highly individual, but generally higher is better.
    var hrvQuality: HRVQuality {
        HRVQuality(hrv: hrv)
    }
}

/// Quality levels for HRV values.
/// These ranges are general guidelines; individual baselines vary significantly.
enum HRVQuality: Equatable {
    case excellent  // 50+ ms
    case good       // 30-49 ms
    case fair       // 20-29 ms
    case low        // < 20 ms

    init(hrv: Int) {
        switch hrv {
        case 50...: self = .excellent
        case 30..<50: self = .good
        case 20..<30: self = .fair
        default: self = .low
        }
    }

    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .low: return "Low"
        }
    }
}

/// Represents daily resting heart rate summary.
struct RestingHeartRate: Codable, Identifiable, Equatable {
    let id: String
    let day: String
    let bpm: Int

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case bpm
    }
}

// MARK: - Resting Heart Rate Computed Display Properties

extension RestingHeartRate {
    /// Resting heart rate formatted with units (e.g., "58 bpm").
    var bpmDisplay: String {
        "\(bpm) bpm"
    }

    /// Formatted date string for display.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return day }

        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Resting heart rate quality level.
    /// Lower resting heart rate generally indicates better cardiovascular fitness.
    var restingHRQuality: RestingHRQuality {
        RestingHRQuality(bpm: bpm)
    }
}

/// Quality levels for resting heart rate.
enum RestingHRQuality: Equatable {
    case excellent  // < 60 bpm (athletic)
    case good       // 60-69 bpm
    case average    // 70-79 bpm
    case elevated   // 80+ bpm

    init(bpm: Int) {
        switch bpm {
        case ..<60: self = .excellent
        case 60..<70: self = .good
        case 70..<80: self = .average
        default: self = .elevated
        }
    }

    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .average: return "Average"
        case .elevated: return "Elevated"
        }
    }
}
