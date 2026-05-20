//
//  WidgetModels.swift
//  feverlessWidget
//
//  Duplicate model definitions so the widget target can read
//  from the shared App Group SwiftData store.
//  Class names must match exactly to share the same schema.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Data Models

@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date?
    var avatarEmoji: String = "🧒"
    var createdAt: Date = Date()

    init(name: String, birthDate: Date? = nil, avatarEmoji: String = "🧒") {
        self.id = UUID()
        self.name = name
        self.birthDate = birthDate
        self.avatarEmoji = avatarEmoji
        self.createdAt = Date()
    }
}

@Model
final class TemperatureRecord {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var value: Double = 0.0
    var methodRaw: String = "axillary"
    var timestamp: Date = Date()
    var notes: String = ""

    var method: MeasurementMethod {
        get { MeasurementMethod(rawValue: methodRaw) ?? .axillary }
        set { methodRaw = newValue.rawValue }
    }

    var isFever: Bool { value >= method.feverThreshold }

    init(childId: UUID, value: Double, method: MeasurementMethod, timestamp: Date = Date(), notes: String = "") {
        self.id = UUID(); self.childId = childId; self.value = value
        self.methodRaw = method.rawValue; self.timestamp = timestamp; self.notes = notes
    }
}

@Model
final class MedicationRecord {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var typeRaw: String = "other"
    var timestamp: Date = Date()
    var concurrentTemperature: Double?
    var notes: String = ""

    var type: MedicationType {
        get { MedicationType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(childId: UUID, type: MedicationType, timestamp: Date = Date(), concurrentTemperature: Double? = nil, notes: String = "") {
        self.id = UUID(); self.childId = childId; self.typeRaw = type.rawValue
        self.timestamp = timestamp; self.concurrentTemperature = concurrentTemperature; self.notes = notes
    }
}

// MARK: - Enums

enum MeasurementMethod: String, Codable, CaseIterable {
    case axillary = "axillary"
    case ear      = "ear"
    case rectal   = "rectal"
    case oral     = "oral"
    case forehead = "forehead"

    var feverThreshold: Double {
        switch self {
        case .axillary, .forehead: return 37.5
        case .ear, .rectal, .oral: return 38.0
        }
    }
}

enum MedicationType: String, Codable, CaseIterable {
    case ibuprofen     = "ibuprofen"
    case acetaminophen = "acetaminophen"
    case other         = "other"

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

    var minimumIntervalHours: Double {
        switch self {
        case .ibuprofen:     return 6
        case .acetaminophen: return 4
        case .other:         return 0
        }
    }

    var maxDailyDoses: Int {
        switch self {
        case .ibuprofen:     return 4
        case .acetaminophen: return 5
        case .other:         return Int.max
        }
    }
}
