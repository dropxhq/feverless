import Foundation
import SwiftData

@Model
final class TemperatureRecord {
    var id: UUID = UUID()
    var childId: UUID = UUID()
    var value: Double = 0.0
    var methodRaw: String = MeasurementMethod.axillary.rawValue
    var timestamp: Date = Date()
    var notes: String = ""

    var method: MeasurementMethod {
        get { MeasurementMethod(rawValue: methodRaw) ?? .axillary }
        set { methodRaw = newValue.rawValue }
    }

    var isFever: Bool {
        value >= method.feverThreshold
    }

    init(childId: UUID, value: Double, method: MeasurementMethod, timestamp: Date = Date(), notes: String = "") {
        self.id = UUID()
        self.childId = childId
        self.value = value
        self.methodRaw = method.rawValue
        self.timestamp = timestamp
        self.notes = notes
    }
}
