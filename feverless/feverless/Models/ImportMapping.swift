import Foundation

// MARK: - 1.1 ColumnMappingRule

enum ColumnMappingRule: Codable, Equatable {
    /// Map CSV column value to the specified internal field (1:1)
    case simple(field: String)
    /// Map CSV column value to a field and also inject fixed implied field values
    case compound(field: String, impliedValues: [String: String])
    /// Extract medication keywords from this column's text; optionally also map to a field
    case keywordExtract(field: String?, extractsMedications: Bool)
    /// Ignore this column entirely
    case ignore

    private enum CodingKeys: String, CodingKey {
        case type, field, impliedValues, extractsMedications
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .simple(let field):
            try container.encode("simple", forKey: .type)
            try container.encode(field, forKey: .field)
        case .compound(let field, let impliedValues):
            try container.encode("compound", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(impliedValues, forKey: .impliedValues)
        case .keywordExtract(let field, let extractsMedications):
            try container.encode("keywordExtract", forKey: .type)
            try container.encodeIfPresent(field, forKey: .field)
            try container.encode(extractsMedications, forKey: .extractsMedications)
        case .ignore:
            try container.encode("ignore", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "simple":
            let field = try container.decode(String.self, forKey: .field)
            self = .simple(field: field)
        case "compound":
            let field = try container.decode(String.self, forKey: .field)
            let implied = try container.decode([String: String].self, forKey: .impliedValues)
            self = .compound(field: field, impliedValues: implied)
        case "keywordExtract":
            let field = try container.decodeIfPresent(String.self, forKey: .field)
            let extracts = (try? container.decode(Bool.self, forKey: .extractsMedications)) ?? false
            self = .keywordExtract(field: field, extractsMedications: extracts)
        default:
            self = .ignore
        }
    }
}

// MARK: - 1.2 ImportMappingConfig

struct ImportMappingConfig: Codable {
    /// Maps CSV column header string → ColumnMappingRule
    var columnMappings: [String: ColumnMappingRule]
    /// Maps internalFieldName → [originalValue → targetRawValue]
    var valueMappings: [String: [String: String]]

    init() {
        columnMappings = [:]
        valueMappings = [:]
    }
}

// MARK: - 1.3 ImportConfigStore

struct ImportConfigStore {
    private static let key = "csv_import_mapping_config"

    static func load() -> ImportMappingConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(ImportMappingConfig.self, from: data) else {
            return ImportMappingConfig()
        }
        return config
    }

    static func save(_ config: ImportMappingConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 1.4 ImportMappingReport

struct ImportMappingReport {
    /// Maps CSV header → resolved internal field name (for alias-resolved or user-mapped columns)
    var appliedColumnMappings: [String: String]
    /// Per-field value mapping hit counts: fieldName → [originalValue: count]
    var appliedValueCounts: [String: [String: Int]]
    /// Number of medication records generated from keyword extraction
    var keywordExtractionCount: Int

    init() {
        appliedColumnMappings = [:]
        appliedValueCounts = [:]
        keywordExtractionCount = 0
    }

    mutating func recordValueMapping(field: String, originalValue: String) {
        if appliedValueCounts[field] == nil { appliedValueCounts[field] = [:] }
        appliedValueCounts[field]![originalValue, default: 0] += 1
    }
}
