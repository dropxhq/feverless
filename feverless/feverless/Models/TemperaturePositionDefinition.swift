import Foundation

struct TemperaturePositionDefinition: Codable, Identifiable {
    var id: UUID
    var canonicalName: String
    var keywords: [String]
    var feverThreshold: Double
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        canonicalName: String,
        keywords: [String] = [],
        feverThreshold: Double = 37.5,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.keywords = keywords
        self.feverThreshold = feverThreshold
        self.isBuiltIn = isBuiltIn
    }
}
