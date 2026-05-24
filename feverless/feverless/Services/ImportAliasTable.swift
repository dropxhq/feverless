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

    // MARK: - 2.2 Enum value display name / brand name aliases

    private let valueAliases: [String: [String: String]] = [
        "record_type": [
            "体温": "temperature",
            "用药": "medication",
        ],
        "method": [
            "腋下":   MeasurementMethod.axillary.rawValue,
            "腋温":   MeasurementMethod.axillary.rawValue,
            "液温":   MeasurementMethod.axillary.rawValue,
            "耳温":   MeasurementMethod.ear.rawValue,
            "耳朵":   MeasurementMethod.ear.rawValue,
            "肛温":   MeasurementMethod.rectal.rawValue,
            "口腔":   MeasurementMethod.oral.rawValue,
            "口温":   MeasurementMethod.oral.rawValue,
            "额温":   MeasurementMethod.forehead.rawValue,
            "额头":   MeasurementMethod.forehead.rawValue,
        ],
        "medication_type": [
            "布洛芬":     MedicationType.ibuprofen.rawValue,
            "美林":      MedicationType.ibuprofen.rawValue,
            "芬必得":    MedicationType.ibuprofen.rawValue,
            "Advil":    MedicationType.ibuprofen.rawValue,
            "对乙酰氨基酚": MedicationType.acetaminophen.rawValue,
            "扑热息痛":   MedicationType.acetaminophen.rawValue,
            "泰诺":      MedicationType.acetaminophen.rawValue,
            "退热净":    MedicationType.acetaminophen.rawValue,
            "其他":      MedicationType.other.rawValue,
        ],
    ]

    // MARK: - 2.3 Resolve column name (three-layer priority)

    /// Returns the internal field name for a CSV header, or nil if unresolvable.
    /// Priority: rawValue match → built-in Chinese alias → user config simple mapping
    func resolveColumnName(_ header: String, config: ImportMappingConfig) -> String? {
        // Layer 1: exact rawValue match
        if knownInternalFields.contains(header) { return header }

        // Layer 2: built-in Chinese alias
        if let field = columnAliases[header] { return field }

        // Layer 3: user config simple mapping (compound/keyword/ignore are handled separately)
        if let rule = config.columnMappings[header], case .simple(let field) = rule {
            return field
        }

        return nil
    }

    // MARK: - 2.4 Resolve value (three-layer priority)

    /// Returns the internal rawValue for an enum field value, or nil if unresolvable.
    /// Priority: rawValue match → built-in displayName/brand alias → user config valueMapping
    /// For non-enum fields, always returns the value as-is.
    func resolveValue(_ value: String, forField field: String, config: ImportMappingConfig) -> String? {
        // Layer 1: rawValue exact match
        switch field {
        case "record_type":
            if ["temperature", "medication"].contains(value) { return value }
        case "method":
            if MeasurementMethod(rawValue: value) != nil { return value }
        case "medication_type":
            if MedicationType(rawValue: value) != nil { return value }
        default:
            return value  // non-enum fields always resolve
        }

        // Layer 2: built-in alias (displayName / brand name)
        if let resolved = valueAliases[field]?[value] { return resolved }

        // Layer 3: user config valueMappings
        if let resolved = config.valueMappings[field]?[value] { return resolved }

        return nil
    }
}
