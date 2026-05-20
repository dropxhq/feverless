import Foundation
import SwiftData

@Model
final class MedicationRecord {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var typeRaw: String = MedicationType.other.rawValue
    var timestamp: Date = Date()
    var concurrentTemperature: Double?
    var notes: String = ""

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
