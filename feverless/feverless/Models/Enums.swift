import Foundation
import SwiftUI

enum MeasurementMethod: String, Codable, CaseIterable {
    case axillary = "axillary"
    case ear = "ear"
    case rectal = "rectal"
    case oral = "oral"
    case forehead = "forehead"

    var displayName: String {
        switch self {
        case .axillary: return "腋下"
        case .ear:      return "耳温"
        case .rectal:   return "肛温"
        case .oral:     return "口腔"
        case .forehead: return "额温"
        }
    }

    /// Fever threshold in °C for this measurement method
    var feverThreshold: Double {
        switch self {
        case .axillary, .forehead: return 37.5
        case .ear, .rectal, .oral: return 38.0
        }
    }
}

enum MedicationType: String, Codable, CaseIterable {
    case ibuprofen = "ibuprofen"
    case acetaminophen = "acetaminophen"
    case other = "other"

    var displayName: String {
        switch self {
        case .ibuprofen:     return "布洛芬"
        case .acetaminophen: return "对乙酰氨基酚"
        case .other:         return "其他"
        }
    }

    var emoji: String {
        switch self {
        case .ibuprofen:     return "🟡"
        case .acetaminophen: return "🔵"
        case .other:         return "⚪"
        }
    }

    var color: Color {
        switch self {
        case .ibuprofen:     return .yellow
        case .acetaminophen: return .blue
        case .other:         return .gray
        }
    }

    /// Minimum hours between doses
    var minimumIntervalHours: Double {
        switch self {
        case .ibuprofen:     return 6
        case .acetaminophen: return 4
        case .other:         return 0
        }
    }

    /// Maximum doses per day
    var maxDailyDoses: Int {
        switch self {
        case .ibuprofen:     return 4
        case .acetaminophen: return 5
        case .other:         return Int.max
        }
    }
}
