import SwiftUI

// MARK: - MedicationCatalogView

/// Allows the user to view and manage MedicationDefinitions in MedicationCatalog.
struct MedicationCatalogView: View {
    let isSheet: Bool

    @ObservedObject private var catalog = MedicationCatalog.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddMedication = false
    @State private var newName: String = ""
    @State private var editingDef: MedicationDefinition?

    init(isSheet: Bool = false) {
        self.isSheet = isSheet
    }

    var body: some View {
        List {
            ForEach(catalog.all) { def in
                Button {
                    editingDef = def
                } label: {
                    HStack(spacing: 12) {
                        Text(catalog.emoji(for: def.canonicalName))
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def.canonicalName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            if def.keywords.isEmpty {
                                Text("暂无关键词")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(def.keywords.prefix(3).joined(separator: "、"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if def.isBuiltIn {
                            Text("内置")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.1), in: Capsule())
                        }
                        if def.hasReminder {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !def.isBuiltIn {
                        Button(role: .destructive) {
                            catalog.remove(id: def.id)
                            catalog.save()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }

            if showAddMedication {
                HStack {
                    TextField("药品名称", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        let name = newName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let def = MedicationDefinition(canonicalName: name, keywords: [], isBuiltIn: false, hasReminder: false)
                        catalog.add(def)
                        catalog.save()
                        newName = ""
                        showAddMedication = false
                    }
                    .fontWeight(.semibold)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("药品管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showAddMedication.toggle()
                    newName = ""
                } label: {
                    Image(systemName: showAddMedication ? "xmark" : "plus")
                }
            }
        }
        .sheet(item: $editingDef) { def in
            MedicationEditSheet(def: def)
        }
    }
}

// MARK: - MedicationEditSheet

private struct MedicationEditSheet: View {
    @ObservedObject private var catalog = MedicationCatalog.shared
    @Environment(\.dismiss) private var dismiss

    let def: MedicationDefinition

    @State private var canonicalName: String
    @State private var keywords: [String]
    @State private var hasReminder: Bool
    @State private var minIntervalHours: String
    @State private var maxDailyDoses: String
    @State private var newKeyword: String = ""

    init(def: MedicationDefinition) {
        self.def = def
        _canonicalName = State(initialValue: def.canonicalName)
        _keywords = State(initialValue: def.keywords)
        _hasReminder = State(initialValue: def.hasReminder)
        _minIntervalHours = State(initialValue: def.minIntervalHours.map { String($0) } ?? "")
        _maxDailyDoses = State(initialValue: def.maxDailyDoses.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("药品名称") {
                    TextField("名称", text: $canonicalName)
                        .disabled(def.isBuiltIn)
                        .foregroundStyle(def.isBuiltIn ? .secondary : .primary)
                }

                Section {
                    ForEach(keywords, id: \.self) { kw in
                        Text(kw)
                    }
                    .onDelete { indexSet in
                        keywords.remove(atOffsets: indexSet)
                    }
                    HStack {
                        TextField("添加关键词", text: $newKeyword)
                        Button("添加") {
                            let kw = newKeyword.trimmingCharacters(in: .whitespaces)
                            guard !kw.isEmpty, !keywords.contains(kw) else { return }
                            keywords.append(kw)
                            newKeyword = ""
                        }
                        .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("识别关键词")
                } footer: {
                    Text("CSV 导入时，列值匹配任意关键词即视为此药品。左滑可删除。")
                }

                Section("提醒设置") {
                    Toggle("用药提醒", isOn: $hasReminder)
                    if hasReminder {
                        HStack {
                            Text("最短间隔（小时）")
                            Spacer()
                            TextField("如 6", text: $minIntervalHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("每日最多次数")
                            Spacer()
                            TextField("如 4", text: $maxDailyDoses)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }
            }
            .navigationTitle("编辑药品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = def
                        if !def.isBuiltIn {
                            updated.canonicalName = canonicalName.trimmingCharacters(in: .whitespaces)
                        }
                        updated.keywords = keywords
                        updated.hasReminder = hasReminder
                        updated.minIntervalHours = Double(minIntervalHours)
                        updated.maxDailyDoses = Int(maxDailyDoses)
                        catalog.update(updated)
                        catalog.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(canonicalName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
