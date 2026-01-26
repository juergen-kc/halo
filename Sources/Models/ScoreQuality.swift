import Foundation

/// Represents quality levels for Oura scores (sleep, readiness, activity).
/// Oura uses a 0-100 scale where higher is better.
enum ScoreQuality: Equatable {
    case optimal    // 85-100
    case good       // 70-84
    case fair       // 60-69
    case attention  // < 60
    case unknown

    init(score: Int) {
        switch score {
        case 85...100: self = .optimal
        case 70..<85: self = .good
        case 60..<70: self = .fair
        case 0..<60: self = .attention
        default: self = .unknown
        }
    }

    /// Human-readable description of the quality level.
    var description: String {
        switch self {
        case .optimal: return "Optimal"
        case .good: return "Good"
        case .fair: return "Fair"
        case .attention: return "Pay Attention"
        case .unknown: return "Unknown"
        }
    }

    /// Suggested color name for UI styling.
    /// Maps to SwiftUI's built-in color names.
    var colorName: String {
        switch self {
        case .optimal: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .attention: return "red"
        case .unknown: return "gray"
        }
    }
}
