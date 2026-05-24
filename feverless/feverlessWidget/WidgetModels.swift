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
final class DataRecord {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var timestamp: Date = Date()
    var notes: String = ""
    @Relationship(deleteRule: .cascade) var temperatures: [TemperatureReading] = []
    @Relationship(deleteRule: .cascade) var medications: [MedicationUsage] = []

    init(childId: UUID, timestamp: Date = Date(), notes: String = "") {
        self.id = UUID()
        self.childId = childId
        self.timestamp = timestamp
        self.notes = notes
        self.temperatures = []
        self.medications = []
    }
}

@Model
final class TemperatureReading {
    var positionRaw: String = ""
    var value: Double = 0.0

    init(positionRaw: String, value: Double) {
        self.positionRaw = positionRaw
        self.value = value
    }

    /// Default fever check using a common threshold (37.5°C).
    /// Widget cannot access TemperaturePositionCatalog — uses conservative default.
    func isFever() -> Bool { value >= 37.5 }
}

@Model
final class MedicationUsage {
    var medicationNameRaw: String = ""

    init(medicationNameRaw: String) {
        self.medicationNameRaw = medicationNameRaw
    }
}
