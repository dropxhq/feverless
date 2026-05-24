import Combine
import Foundation
import SwiftUI

// MARK: - MedicationCatalog

final class MedicationCatalog: ObservableObject {
    static let shared = MedicationCatalog()

    private static let userDefaultsKey = "medication_catalog_v1"

    @Published var all: [MedicationDefinition] = []

    // MARK: Built-in definitions (seeded from MedicationType constants)

    private static let builtins: [MedicationDefinition] = [
        MedicationDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
            canonicalName: "布洛芬",
            keywords: ["布洛芬", "美林", "芬必得", "Advil", "ibuprofen"],
            isBuiltIn: true,
            hasReminder: true,
            minIntervalHours: 6,
            maxDailyDoses: 4
        ),
        MedicationDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            canonicalName: "对乙酰氨基酚",
            keywords: ["对乙酰氨基酚", "对乙", "扑热息痛", "泰诺", "退热净", "acetaminophen"],
            isBuiltIn: true,
            hasReminder: true,
            minIntervalHours: 4,
            maxDailyDoses: 5
        ),
        MedicationDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000003")!,
            canonicalName: "其他",
            keywords: [],
            isBuiltIn: true,
            hasReminder: false,
            minIntervalHours: nil,
            maxDailyDoses: nil
        ),
    ]

    private init() {
        all = Self.builtins
    }

    // MARK: - Query

    func find(byId id: UUID) -> MedicationDefinition? {
        all.first { $0.id == id }
    }

    func findByCanonicalName(_ name: String) -> MedicationDefinition? {
        all.first { $0.canonicalName == name }
    }

    // MARK: - Mutations

    func add(_ definition: MedicationDefinition) {
        all.append(definition)
    }

    func update(_ definition: MedicationDefinition) {
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
        // Persist user-defined meds and built-ins whose keywords have been modified
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
           let saved = try? JSONDecoder().decode([MedicationDefinition].self, from: data) {
            for savedDef in saved {
                if let builtinIndex = result.firstIndex(where: { $0.id == savedDef.id }) {
                    // Restore user-modified keywords on built-ins
                    result[builtinIndex].keywords = savedDef.keywords
                } else {
                    result.append(savedDef)
                }
            }
        }
        all = result
    }

    // MARK: - Display Helpers

    private static let paletteColors: [Color] = [
        .yellow, .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan
    ]
    private static let paletteEmojis: [String] = [
        "🟡", "🔵", "🟢", "🟠", "🟣", "🩷", "🩵", "🫐", "🌿", "💊"
    ]

    func color(for def: MedicationDefinition) -> Color {
        switch def.canonicalName {
        case "布洛芬":     return .yellow
        case "对乙酰氨基酚": return .blue
        default:
            let hash = abs(def.id.hashValue)
            return Self.paletteColors[hash % Self.paletteColors.count]
        }
    }

    func emoji(for def: MedicationDefinition) -> String {
        switch def.canonicalName {
        case "布洛芬":     return "🟡"
        case "对乙酰氨基酚": return "🔵"
        default:
            let hash = abs(def.id.hashValue)
            return Self.paletteEmojis[hash % Self.paletteEmojis.count]
        }
    }

    func iconBackground(for def: MedicationDefinition) -> Color {
        color(for: def).opacity(0.12)
    }

    // Legacy overloads for call sites that only have the name
    func color(for canonicalName: String) -> Color {
        all.first(where: { $0.canonicalName == canonicalName }).map { color(for: $0) } ?? .gray
    }

    func emoji(for canonicalName: String) -> String {
        all.first(where: { $0.canonicalName == canonicalName }).map { emoji(for: $0) } ?? "⚪"
    }

    func iconBackground(for canonicalName: String) -> Color {
        all.first(where: { $0.canonicalName == canonicalName }).map { iconBackground(for: $0) } ?? Color.gray.opacity(0.12)
    }

}
