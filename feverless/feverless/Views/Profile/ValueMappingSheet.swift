import SwiftUI

// MARK: - UnresolvedValueGroup

struct UnresolvedValueGroup: Identifiable {
    let id: String              // internal field name
    let fieldDisplayName: String
    var items: [(value: String, count: Int)]
}

// MARK: - ValueMappingSheet

/// Displays unrecognized enum values grouped by field and lets the user map them
/// to known enum rawValues (or ignore them).
struct ValueMappingSheet: View {
    let valueGroups: [UnresolvedValueGroup]
    let config: ImportMappingConfig
    let onDone: (ImportMappingConfig) -> Void

    @State private var localConfig: ImportMappingConfig
    @State private var newKeyword: String = ""
    @State private var newKeywordType: MedicationType = .ibuprofen
    @State private var showAddKeyword: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(valueGroups: [UnresolvedValueGroup], config: ImportMappingConfig, onDone: @escaping (ImportMappingConfig) -> Void) {
        self.valueGroups = valueGroups
        self.config = config
        self.onDone = onDone
        _localConfig = State(initialValue: config)
    }

    // MARK: - Enum options per field

    private let recordTypeOptions: [(displayName: String, rawValue: String)] = [
        ("体温", "temperature"),
        ("用药", "medication"),
        ("忽略，记为默认值", ""),
    ]

    private let measurementMethodOptions: [(displayName: String, rawValue: String)] =
        MeasurementMethod.allCases.map { ($0.displayName, $0.rawValue) }
        + [("忽略，记为默认值", "")]

    private let medicationTypeOptions: [(displayName: String, rawValue: String)] =
        MedicationType.allCases.map { ($0.displayName, $0.rawValue) }
        + [("忽略，记为默认值", "")]

    private func options(for field: String) -> [(displayName: String, rawValue: String)] {
        switch field {
        case "record_type":     return recordTypeOptions
        case "method":          return measurementMethodOptions
        case "medication_type": return medicationTypeOptions
        default:                return []
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // 7.2 Sections per field
                ForEach(valueGroups) { group in
                    Section(group.fieldDisplayName) {
                        // 7.3 Each row: original value (×N) + target picker
                        ForEach(group.items, id: \.value) { item in
                            valueMappingRow(
                                originalValue: item.value,
                                count: item.count,
                                field: group.id
                            )
                        }

                        // 7.4 Keyword extension entry (drug type section only)
                        if group.id == "medication_type" {
                            addKeywordButton()
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

    // MARK: - 7.4 Add keyword button and inline form

    @ViewBuilder
    private func addKeywordButton() -> some View {
        if showAddKeyword {
            VStack(alignment: .leading, spacing: 8) {
                TextField("关键词（如：小儿布洛芬）", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)

                Picker("药物类型", selection: $newKeywordType) {
                    ForEach(MedicationType.allCases.filter { $0 != .other }, id: \.rawValue) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("取消") {
                        newKeyword = ""
                        showAddKeyword = false
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("添加") {
                        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        localConfig.keywordExtensions[trimmed] = newKeywordType.rawValue
                        newKeyword = ""
                        showAddKeyword = false
                    }
                    .fontWeight(.semibold)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.vertical, 4)
        } else {
            Button {
                showAddKeyword = true
            } label: {
                Label("添加关键词", systemImage: "plus")
                    .font(.subheadline)
            }
        }

        // Show existing custom keywords
        ForEach(Array(localConfig.keywordExtensions.keys.sorted()), id: \.self) { keyword in
            if let typeRaw = localConfig.keywordExtensions[keyword],
               let type = MedicationType(rawValue: typeRaw) {
                HStack {
                    Text(keyword).font(.subheadline)
                    Spacer()
                    Text(type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        localConfig.keywordExtensions.removeValue(forKey: keyword)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
