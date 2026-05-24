import SwiftUI

// MARK: - TemperaturePositionCatalogView

struct TemperaturePositionCatalogView: View {
    let isSheet: Bool

    @ObservedObject private var catalog = TemperaturePositionCatalog.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddPosition = false
    @State private var newName: String = ""
    @State private var newThreshold: String = "37.5"
    @State private var editingDef: TemperaturePositionDefinition?

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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def.canonicalName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("阈值 \(String(format: "%.1f", def.feverThreshold))°C")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

            if showAddPosition {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("位置名称（如：左侧液温）", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("发烧阈值 (°C):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("37.5", text: $newThreshold)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    HStack {
                        Spacer()
                        Button("添加") {
                            let name = newName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            let threshold = Double(newThreshold) ?? 37.5
                            let def = TemperaturePositionDefinition(
                                canonicalName: name,
                                feverThreshold: threshold,
                                isBuiltIn: false
                            )
                            catalog.add(def)
                            catalog.save()
                            newName = ""
                            newThreshold = "37.5"
                            showAddPosition = false
                        }
                        .fontWeight(.semibold)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("体温位置管理")
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
                    showAddPosition.toggle()
                    newName = ""
                    newThreshold = "37.5"
                } label: {
                    Image(systemName: showAddPosition ? "xmark" : "plus")
                }
            }
        }
        .sheet(item: $editingDef) { def in
            TemperaturePositionEditSheet(def: def)
        }
    }
}

// MARK: - TemperaturePositionEditSheet

private struct TemperaturePositionEditSheet: View {
    @ObservedObject private var catalog = TemperaturePositionCatalog.shared
    @Environment(\.dismiss) private var dismiss

    let def: TemperaturePositionDefinition

    @State private var canonicalName: String
    @State private var feverThreshold: String
    @State private var keywords: [String]
    @State private var newKeyword: String = ""

    init(def: TemperaturePositionDefinition) {
        self.def = def
        _canonicalName = State(initialValue: def.canonicalName)
        _feverThreshold = State(initialValue: String(format: "%.1f", def.feverThreshold))
        _keywords = State(initialValue: def.keywords)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("位置名称") {
                    TextField("名称", text: $canonicalName)
                        .disabled(def.isBuiltIn)
                        .foregroundStyle(def.isBuiltIn ? .secondary : .primary)
                }

                Section("发烧阈值") {
                    HStack {
                        Text("阈值 (°C)")
                        Spacer()
                        TextField("37.5", text: $feverThreshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
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
                    Text("CSV 导入时，列头或列值匹配任意关键词即视为此测量位置。左滑可删除。")
                }
            }
            .navigationTitle("编辑位置")
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
                        updated.feverThreshold = Double(feverThreshold) ?? def.feverThreshold
                        updated.keywords = keywords
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
