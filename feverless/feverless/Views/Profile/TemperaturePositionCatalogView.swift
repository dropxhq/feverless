import SwiftUI

// MARK: - TemperaturePositionCatalogView

struct TemperaturePositionCatalogView: View {
    let isSheet: Bool

    @ObservedObject private var catalog = TemperaturePositionCatalog.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedId: UUID?
    @State private var showAddPosition = false
    @State private var newCanonicalName: String = ""
    @State private var newFeverThreshold: String = "37.5"
    @State private var newKeyword: String = ""

    init(isSheet: Bool = false) {
        self.isSheet = isSheet
    }

    private var selectedDef: TemperaturePositionDefinition? {
        guard let id = selectedId else { return nil }
        return catalog.all.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Left: position list
                List(selection: $selectedId) {
                    ForEach(catalog.all) { def in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(def.canonicalName)
                                    .font(.system(size: 15, weight: .semibold))
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
                        }
                        .tag(def.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !def.isBuiltIn {
                                Button(role: .destructive) {
                                    if selectedId == def.id { selectedId = nil }
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
                            TextField("位置名称（如：左侧液温）", text: $newCanonicalName)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Text("发烧阈值 (°C):")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("37.5", text: $newFeverThreshold)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                            }
                            HStack {
                                Spacer()
                                Button("添加") {
                                    let name = newCanonicalName.trimmingCharacters(in: .whitespaces)
                                    guard !name.isEmpty else { return }
                                    let threshold = Double(newFeverThreshold) ?? 37.5
                                    let def = TemperaturePositionDefinition(
                                        canonicalName: name,
                                        feverThreshold: threshold,
                                        isBuiltIn: false
                                    )
                                    catalog.add(def)
                                    catalog.save()
                                    selectedId = def.id
                                    newCanonicalName = ""
                                    newFeverThreshold = "37.5"
                                    showAddPosition = false
                                }
                                .fontWeight(.semibold)
                                .disabled(newCanonicalName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minWidth: 180)
                .listStyle(.insetGrouped)

                Divider()

                // Right: keyword list + threshold edit for selected position
                if let def = selectedDef, let id = selectedId {
                    rightPanel(def: def, defId: id)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack {
                        Text("选择左侧位置以编辑关键词")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("体温位置管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddPosition.toggle()
                        newCanonicalName = ""
                        newFeverThreshold = "37.5"
                    } label: {
                        Image(systemName: showAddPosition ? "xmark" : "plus")
                    }
                }
                if isSheet {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            catalog.save()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onDisappear {
                catalog.save()
            }
        }
    }

    // MARK: - Right panel

    @ViewBuilder
    private func rightPanel(def: TemperaturePositionDefinition, defId: UUID) -> some View {
        List {
            Section("发烧阈值") {
                HStack {
                    Text("阈值 (°C)")
                    Spacer()
                    let thresholdBinding = Binding<String>(
                        get: { String(format: "%.1f", def.feverThreshold) },
                        set: { newVal in
                            guard let v = Double(newVal) else { return }
                            var updated = def
                            updated.feverThreshold = v
                            catalog.update(updated)
                        }
                    )
                    TextField("37.5", text: thresholdBinding)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            Section("关键词") {
                // Keywords list — extracted directly to fix ForEach rendering
                ForEach(def.keywords, id: \.self) { keyword in
                    HStack {
                        Text(keyword)
                        Spacer()
                        Button {
                            catalog.removeKeyword(keyword, from: defId)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("添加关键词（如：左腋）", text: $newKeyword)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        let trimmed = newKeyword.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        catalog.addKeyword(trimmed, to: defId)
                        newKeyword = ""
                    }
                    .fontWeight(.semibold)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .id(defId) // force re-render when selected position changes
    }
}
