import SwiftUI

// MARK: - ColumnMappingSheet

/// Displays all CSV headers with their resolution status and lets the user configure
/// mappings for unrecognized columns.
struct ColumnMappingSheet: View {
    let allHeaders: [String]
    let config: ImportMappingConfig
    let onDone: (ImportMappingConfig) -> Void

    @State private var entries: [MappingEntry] = []
    @Environment(\.dismiss) private var dismiss

    private let aliasTable = ImportAliasTable()

    // MARK: - Per-column state

    struct MappingEntry: Identifiable {
        /// CSV column header
        let id: String
        /// Non-nil when the column can be auto-resolved (read-only in UI)
        let autoResolvedField: String?
        /// User-selected target internal field; nil = ignore
        var targetField: String?
        /// Compound: implied MeasurementMethod rawValue (when targetField == "value")
        var impliedMethod: String
        /// Compound: implied record type (when targetField == "value")
        var impliedRecordType: String
        /// Whether to extract medication keywords from this column
        var extractsMedications: Bool

        init(header: String, autoResolvedField: String?, existingRule: ColumnMappingRule?) {
            self.id = header
            self.autoResolvedField = autoResolvedField
            self.impliedMethod = MeasurementMethod.axillary.rawValue
            self.impliedRecordType = "temperature"
            self.extractsMedications = false
            self.targetField = autoResolvedField

            if let rule = existingRule {
                switch rule {
                case .simple(let f):
                    self.targetField = f
                case .compound(let f, let implied):
                    self.targetField = f
                    self.impliedMethod = implied["method"] ?? MeasurementMethod.axillary.rawValue
                    self.impliedRecordType = implied["record_type"] ?? "temperature"
                case .keywordExtract(let f, let extracts):
                    self.targetField = f
                    self.extractsMedications = extracts
                case .ignore:
                    self.targetField = nil
                }
            }
        }
    }

    // MARK: - Target field options

    private let targetFieldOptions: [(id: String, displayName: String)] = [
        (id: "timestamp",             displayName: "时间"),
        (id: "record_type",           displayName: "记录类型"),
        (id: "value",                 displayName: "数值"),
        (id: "method",                displayName: "测量方式"),
        (id: "medication_type",       displayName: "药物类型"),
        (id: "concurrent_temperature", displayName: "同步体温"),
        (id: "notes",                 displayName: "备注"),
    ]

    private func displayName(for field: String) -> String {
        targetFieldOptions.first { $0.id == field }?.displayName ?? field
    }

    // MARK: - Validation

    // 6.5 Continue disabled until required fields are mapped
    private var missingRequiredFields: [String] {
        var missing: [String] = []

        let hasTimestamp = entries.contains { e in
            e.autoResolvedField == "timestamp" || e.targetField == "timestamp"
        }
        let hasRecordType = entries.contains { e in
            if e.autoResolvedField == "record_type" { return true }
            if e.targetField == "record_type" { return true }
            // Compound value columns implicitly cover record_type
            if e.targetField == "value" { return true }
            return false
        }

        if !hasTimestamp { missing.append("时间") }
        if !hasRecordType { missing.append("记录类型") }
        return missing
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                ForEach($entries) { $entry in
                    columnRow(entry: $entry)
                }

                // 6.5 Missing fields hint
                if !missingRequiredFields.isEmpty {
                    Section {
                        Label(
                            "缺少必要字段：\(missingRequiredFields.joined(separator: "、"))",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("列名映射")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("继续") {
                        onDone(buildUpdatedConfig())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!missingRequiredFields.isEmpty)
                }
            }
        }
        .onAppear { buildEntries() }
    }

    // MARK: - Column row

    @ViewBuilder
    private func columnRow(entry: Binding<MappingEntry>) -> some View {
        let e = entry.wrappedValue

        if let resolvedField = e.autoResolvedField {
            // 6.2 Auto-resolved: show ✓ (read-only)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.id).font(.headline)
                    Text("→ \(displayName(for: resolvedField))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        } else {
            // 6.2 Unresolved: show ! and picker
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(e.id).font(.headline)
                    Spacer()
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                }

                // Primary field picker
                Picker("映射为", selection: entry.targetField) {
                    // 6.6 Ignore option
                    Text("忽略此列").tag(nil as String?)
                    ForEach(targetFieldOptions, id: \.id) { option in
                        Text(option.displayName).tag(option.id as String?)
                    }
                }
                .pickerStyle(.menu)

                // 6.3 Compound inline expansion when "数值" is selected
                if entry.wrappedValue.targetField == "value" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("同时固定以下字段：")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("测量方式", selection: entry.impliedMethod) {
                            ForEach(MeasurementMethod.allCases, id: \.rawValue) { method in
                                Text(method.displayName).tag(method.rawValue)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("记录类型", selection: entry.impliedRecordType) {
                            Text("体温").tag("temperature")
                            Text("用药").tag("medication")
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.leading, 12)
                }

                // 6.4 Keyword extraction checkbox (when target is nil or "notes")
                let canExtract = entry.wrappedValue.targetField == nil
                    || entry.wrappedValue.targetField == "notes"
                if canExtract {
                    Toggle("从此列提取药物关键词", isOn: entry.extractsMedications)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Build entries from headers + config

    private func buildEntries() {
        entries = allHeaders.map { header in
            let autoResolved = aliasTable.resolveColumnName(header, config: config)
            // If auto-resolvable, don't show user config override for it
            let existingRule: ColumnMappingRule? = autoResolved == nil ? config.columnMappings[header] : nil
            return MappingEntry(
                header: header,
                autoResolvedField: autoResolved,
                existingRule: existingRule
            )
        }
    }

    // MARK: - Build updated config from current entries

    private func buildUpdatedConfig() -> ImportMappingConfig {
        var newConfig = config
        for entry in entries {
            // Skip auto-resolved columns (no override needed)
            guard entry.autoResolvedField == nil else { continue }

            let rule: ColumnMappingRule
            if let field = entry.targetField {
                if field == "value" {
                    rule = .compound(
                        field: field,
                        impliedValues: [
                            "method": entry.impliedMethod,
                            "record_type": entry.impliedRecordType,
                        ]
                    )
                } else if entry.extractsMedications {
                    rule = .keywordExtract(field: field == "notes" ? field : nil, extractsMedications: true)
                } else {
                    rule = .simple(field: field)
                }
            } else if entry.extractsMedications {
                rule = .keywordExtract(field: nil, extractsMedications: true)
            } else {
                rule = .ignore
            }
            newConfig.columnMappings[entry.id] = rule
        }
        return newConfig
    }
}
