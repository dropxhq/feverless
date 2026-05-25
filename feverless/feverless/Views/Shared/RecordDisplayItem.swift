import Foundation

// MARK: - RecordDisplayItem
// Represents a single displayable row in any record list (HomeView, ChartView).
// One DataRecord = one RecordDisplayItem (combined case for concurrent temp+med records).

enum RecordDisplayItem: Identifiable {
    case temperature(record: DataRecord, reading: TemperatureReading)
    case medication(record: DataRecord, usage: MedicationUsage)
    case combined(record: DataRecord, reading: TemperatureReading, usage: MedicationUsage)

    var id: UUID { record.id }

    var record: DataRecord {
        switch self {
        case .temperature(let r, _):    return r
        case .medication(let r, _):     return r
        case .combined(let r, _, _):    return r
        }
    }

    var date: Date { record.timestamp }
}
