import Foundation
import SwiftData

@Model
final class DataRecord {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var timestamp: Date = Date()
    var notes: String = ""

    @Relationship(deleteRule: .cascade)
    var temperatures: [TemperatureReading] = []

    @Relationship(deleteRule: .cascade)
    var medications: [MedicationUsage] = []

    init(
        childId: UUID,
        timestamp: Date = Date(),
        notes: String = "",
        temperatures: [TemperatureReading] = [],
        medications: [MedicationUsage] = []
    ) {
        self.id = UUID()
        self.childId = childId
        self.timestamp = timestamp
        self.notes = notes
        self.temperatures = temperatures
        self.medications = medications
    }
}
