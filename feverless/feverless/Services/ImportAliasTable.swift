import Foundation

// MARK: - ImportAliasTable

struct ImportAliasTable {

    // MARK: - 2.1 Built-in column name aliases (Chinese display names → internal field names)

    private let columnAliases: [String: String] = [
        "时间":   "timestamp",
        "记录类型": "record_type",
        "数值":   "value",
        "测量方式": "method",
        "药物类型": "medication_type",
        "同步体温": "concurrent_temperature",
        "备注":   "notes",
    ]

    private let knownInternalFields: Set<String> = [
        "timestamp", "record_type", "value", "method",
        "medication_type", "concurrent_temperature", "notes",
    ]

    // MARK: - 2.2 Enum value display name aliases

    private let valueAliases: [String: [String: String]] = [
        "record_type": [
            "体温": "temperature",
            "用药": "medication",
        ],
        // method values are now resolved dynamically via TemperaturePositionCatalog
        // medication_type aliases are now built dynamically from MedicationCatalog
    ]

    // MARK: - 2.3 Resolve column name (three-layer priority)

    /// Returns the internal field name for a CSV header, or nil if unresolvable.
    /// Priority: rawValue match → built-in Chinese alias → user config simple mapping → position keyword
    func resolveColumnName(_ header: String, config: ImportMappingConfig) -> String? {
        if let rule = resolveColumnRule(header, config: config) {
            switch rule {
            case .simple(let f):       return f
            case .compound(let f, _):  return f
            default:                   return nil
            }
        }
        return nil
    }

    /// Returns the full ColumnMappingRule for a CSV header, or nil if unresolvable.
    /// Adds a 4th layer: position keyword match → compound rule (value + implied method).
    func resolveColumnRule(_ header: String, config: ImportMappingConfig) -> ColumnMappingRule? {
        // Layer 1: exact rawValue match (internal field name used as header)
        if knownInternalFields.contains(header) { return .simple(field: header) }

        // Layer 2: built-in Chinese alias
        if let field = columnAliases[header] { return .simple(field: field) }

        // Layer 3: user config simple mapping
        if let rule = config.columnMappings[header], case .simple(let field) = rule {
            return .simple(field: field)
        }

        // Layer 4: column header matches a temperature position keyword
        // e.g. "腋温" → compound(field: "value", impliedValues: ["method": "腋下", "record_type": "temperature"])
        if let position = TemperaturePositionCatalog.shared.findByKeyword(header) {
            return .compound(
                field: "value",
                impliedValues: [
                    "method": position.canonicalName,
                    "record_type": "temperature",
                ]
            )
        }

        return nil
    }

    // MARK: - 2.4 Resolve value (three-layer priority)

    /// Returns the internal canonical value for an enum field, or nil if unresolvable.
    /// For "method" field, returns canonicalName from TemperaturePositionCatalog.
    /// For non-enum fields, always returns the value as-is.
    func resolveValue(_ value: String, forField field: String, config: ImportMappingConfig) -> String? {
        // Layer 1: exact match check
        switch field {
        case "record_type":
            if ["temperature", "medication"].contains(value) { return value }
        case "method":
            // Exact canonical name match in catalog
            if TemperaturePositionCatalog.shared.find(value) != nil { return value }
        case "medication_type":
            // Exact canonical name match in catalog
            if MedicationCatalog.shared.findByCanonicalName(value) != nil { return value }
        default:
            return value  // non-enum fields always resolve
        }

        // Layer 2: built-in alias (record_type only)
        if let resolved = valueAliases[field]?[value] { return resolved }

        // For method: look up keyword → canonical name from TemperaturePositionCatalog
        if field == "method" {
            if let def = TemperaturePositionCatalog.shared.findByKeyword(value) {
                return def.canonicalName
            }
        }

        // For medication_type: dynamically look up keyword → canonical name from catalog
        if field == "medication_type" {
            for def in MedicationCatalog.shared.all {
                if def.keywords.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                    return def.canonicalName
                }
            }
        }

        // Layer 3: user config valueMappings
        if let resolved = config.valueMappings[field]?[value] { return resolved }

        return nil
    }
}

