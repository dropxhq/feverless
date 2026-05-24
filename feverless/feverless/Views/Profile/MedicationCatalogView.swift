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
                HStack(spacing: 12) {
                    Text(catalog.emoji(for: def.canonicalName))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(def.canonicalName)
                            .font(.system(size: 15, weight: .semibold))
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
    }
}
