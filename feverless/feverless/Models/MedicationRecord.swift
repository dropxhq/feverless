import Foundation
import SwiftData

@Model
final class MedicationRecord {
    var id: UUID
    var childId: UUID
    var typeRaw: String
    var timestamp: Date
    var concurrentTemperature: Double?
    var notes: String

    var type: MedicationType {
        get { MedicationType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(childId: UUID, type: MedicationType, timestamp: Date = Date(), concurrentTemperature: Double? = nil, notes: String = "") {
        self.id = UUID()
        self.childId = childId
        self.typeRaw = type.rawValue
        self.timestamp = timestamp
        self.concurrentTemperature = concurrentTemperature
        self.notes = notes
    }
}
