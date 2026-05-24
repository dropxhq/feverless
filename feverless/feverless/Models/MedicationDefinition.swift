import Foundation

struct MedicationDefinition: Codable, Identifiable {
    var id: UUID
    var canonicalName: String
    var keywords: [String]
    var isBuiltIn: Bool
    var hasReminder: Bool
    var minIntervalHours: Double?
    var maxDailyDoses: Int?

    init(
        id: UUID = UUID(),
        canonicalName: String,
        keywords: [String] = [],
        isBuiltIn: Bool = false,
        hasReminder: Bool = false,
        minIntervalHours: Double? = nil,
        maxDailyDoses: Int? = nil
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.keywords = keywords
        self.isBuiltIn = isBuiltIn
        self.hasReminder = hasReminder
        self.minIntervalHours = minIntervalHours
        self.maxDailyDoses = maxDailyDoses
    }
}
