import Foundation
import SwiftData

@Model
final class MedicationUsage {
    var medicationNameRaw: String = ""

    init(medicationNameRaw: String) {
        self.medicationNameRaw = medicationNameRaw
    }
}
