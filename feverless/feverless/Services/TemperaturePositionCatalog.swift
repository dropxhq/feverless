import Combine
import Foundation

// MARK: - TemperaturePositionCatalog

final class TemperaturePositionCatalog: ObservableObject {
    static let shared = TemperaturePositionCatalog()

    private static let userDefaultsKey = "temperature_position_catalog_v1"

    @Published var all: [TemperaturePositionDefinition] = []

    // MARK: Built-in definitions (migrated from MeasurementMethod)

    private static let builtins: [TemperaturePositionDefinition] = [
        TemperaturePositionDefinition(
            id: UUID(uuidString: "10000000-0000-0000-0001-000000000001")!,
            canonicalName: "腋下",
            keywords: ["腋下", "腋温", "液温"],
            feverThreshold: 37.5,
            isBuiltIn: true
        ),
        TemperaturePositionDefinition(
            id: UUID(uuidString: "10000000-0000-0000-0001-000000000002")!,
            canonicalName: "耳温",
            keywords: ["耳温", "耳朵"],
            feverThreshold: 38.0,
            isBuiltIn: true
        ),
        TemperaturePositionDefinition(
            id: UUID(uuidString: "10000000-0000-0000-0001-000000000003")!,
            canonicalName: "肛温",
            keywords: ["肛温"],
            feverThreshold: 38.0,
            isBuiltIn: true
        ),
        TemperaturePositionDefinition(
            id: UUID(uuidString: "10000000-0000-0000-0001-000000000004")!,
            canonicalName: "口腔",
            keywords: ["口腔", "口温"],
            feverThreshold: 38.0,
            isBuiltIn: true
        ),
        TemperaturePositionDefinition(
            id: UUID(uuidString: "10000000-0000-0000-0001-000000000005")!,
            canonicalName: "额温",
            keywords: ["额温", "额头"],
            feverThreshold: 37.5,
            isBuiltIn: true
        ),
    ]

    private init() {
        all = Self.builtins
    }

    // MARK: - Query

    func find(_ canonicalName: String) -> TemperaturePositionDefinition? {
        all.first { $0.canonicalName == canonicalName }
    }

    func findByKeyword(_ keyword: String) -> TemperaturePositionDefinition? {
        all.first { def in
            def.keywords.contains { $0.caseInsensitiveCompare(keyword) == .orderedSame }
        }
    }

    // MARK: - Mutations

    func add(_ definition: TemperaturePositionDefinition) {
        all.append(definition)
    }

    func update(_ definition: TemperaturePositionDefinition) {
        guard let index = all.firstIndex(where: { $0.id == definition.id }) else { return }
        all[index] = definition
    }

    func remove(id: UUID) {
        all.removeAll { $0.id == id && !$0.isBuiltIn }
    }

    func addKeyword(_ keyword: String, to defId: UUID) {
        guard let index = all.firstIndex(where: { $0.id == defId }) else { return }
        guard !all[index].keywords.contains(keyword) else { return }
        all[index].keywords.append(keyword)
    }

    func removeKeyword(_ keyword: String, from defId: UUID) {
        guard let index = all.firstIndex(where: { $0.id == defId }) else { return }
        all[index].keywords.removeAll { $0 == keyword }
    }

    // MARK: - Persistence

    func save() {
        // Persist user-defined positions and built-ins whose keywords have been modified
        let toSave = all.filter { def in
            if !def.isBuiltIn { return true }
            guard let orig = Self.builtins.first(where: { $0.id == def.id }) else { return false }
            return def.keywords != orig.keywords
        }
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    func load() {
        var result = Self.builtins
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let saved = try? JSONDecoder().decode([TemperaturePositionDefinition].self, from: data) {
            for savedDef in saved {
                if let builtinIndex = result.firstIndex(where: { $0.id == savedDef.id }) {
                    result[builtinIndex].keywords = savedDef.keywords
                } else {
                    result.append(savedDef)
                }
            }
        }
        all = result
    }
}
