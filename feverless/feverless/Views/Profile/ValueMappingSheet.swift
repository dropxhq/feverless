import SwiftUI

// MARK: - UnresolvedValueGroup

struct UnresolvedValueGroup: Identifiable {
    let id: String              // internal field name
    let fieldDisplayName: String
    var items: [(value: String, count: Int)]
}

// MARK: - ValueMappingSheet

/// Displays unrecognized enum values grouped by field and lets the user map them
/// to known canonical values (or ignore them). Also provides shortcuts to open
/// MedicationCatalogView or TemperaturePositionCatalogView as sheets.
struct ValueMappingSheet: View {
    let valueGroups: [UnresolvedValueGroup]
    let config: ImportMappingConfig
    let hasKeywordColumns: Bool
    let onDone: (ImportMappingConfig) -> Void

    @State private var localConfig: ImportMappingConfig
    @ObservedObject private var medicationCatalog = MedicationCatalog.shared
    @ObservedObject private var positionCatalog = TemperaturePositionCatalog.shared

    @State private var showMedicationCatalog: Bool = false
    @State private var showPositionCatalog: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var hasUnresolvedPositions: Bool {
        valueGroups.contains { $0.id == "method" }
    }

    init(valueGroups: [UnresolvedValueGroup], config: ImportMappingConfig, hasKeywordColumns: Bool = false, onDone: @escaping (ImportMappingConfig) -> Void) {
        self.valueGroups = valueGroups
        self.config = config
        self.hasKeywordColumns = hasKeywordColumns
        self.onDone = onDone
        _localConfig = State(initialValue: config)
    }

    // MARK: - Enum options per field

    private let recordTypeOptions: [(displayName: String, rawValue: String)] = [
        ("体温", "temperature"),
        ("用药", "medication"),
        ("忽略，记为默认值", ""),
    ]

    private func measurementMethodOptions() -> [(displayName: String, rawValue: String)] {
        positionCatalog.all.map { ($0.canonicalName, $0.canonicalName) }
        + [("忽略，记为默认值", "")]
    }

    private func medicationTypeOptions() -> [(displayName: String, rawValue: String)] {
        medicationCatalog.all.map { ($0.canonicalName, $0.canonicalName) }
        + [("忽略，记为默认值", "")]
    }

    private func options(for field: String) -> [(displayName: String, rawValue: String)] {
        switch field {
        case "record_type":     return recordTypeOptions
        case "method":          return measurementMethodOptions()
        case "medication_type": return medicationTypeOptions()
        default:                return []
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Sections per field
                ForEach(valueGroups) { group in
                    Section(group.fieldDisplayName) {
                        ForEach(group.items, id: \.value) { item in
                            valueMappingRow(
                                originalValue: item.value,
                                count: item.count,
                                field: group.id
                            )
                        }
                    }
                }

                // Medication keyword summary — show all drugs and their aliases inline
                if hasKeywordColumns {
                    Section("药物关键词") {
                        ForEach(medicationCatalog.all) { def in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(def.canonicalName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if def.keywords.isEmpty {
                                    Text("暂无别名")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(def.keywords.joined(separator: "、"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        Button {
                            showMedicationCatalog = true
                        } label: {
                            Label("管理药品", systemImage: "pills.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Temperature position management shortcut (shown when unresolved positions exist)
                if hasUnresolvedPositions {
                    Section("体温位置") {
                        Button {
                            showPositionCatalog = true
                        } label: {
                            Label("管理体温位置", systemImage: "thermometer.medium")
                        }
                    }
                }
            }
            .navigationTitle("值映射")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("继续") {
                        onDone(localConfig)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showMedicationCatalog) {
                MedicationCatalogView(isSheet: true)
            }
            .sheet(isPresented: $showPositionCatalog) {
                TemperaturePositionCatalogView(isSheet: true)
            }
        }
    }

    // MARK: - Value mapping row

    @ViewBuilder
    private func valueMappingRow(originalValue: String, count: Int, field: String) -> some View {
        let opts = options(for: field)
        let bindingVal = Binding<String>(
            get: { localConfig.valueMappings[field]?[originalValue] ?? "" },
            set: { newVal in
                if localConfig.valueMappings[field] == nil {
                    localConfig.valueMappings[field] = [:]
                }
                if newVal.isEmpty {
                    localConfig.valueMappings[field]?.removeValue(forKey: originalValue)
                } else {
                    localConfig.valueMappings[field]?[originalValue] = newVal
                }
            }
        )

        HStack {
            Text("\(originalValue) (×\(count))")
                .font(.body)
            Spacer()
            Picker("", selection: bindingVal) {
                ForEach(opts, id: \.rawValue) { opt in
                    Text(opt.displayName).tag(opt.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

