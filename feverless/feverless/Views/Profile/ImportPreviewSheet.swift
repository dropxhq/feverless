import SwiftUI
import SwiftData

// MARK: - 4.1 Import preview sheet

struct ImportPreviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let parseResult: CSVParseResult
    let onComplete: (Int) -> Void

    // MARK: - Computed

    // 4.5 All-duplicate check
    private var isAllDuplicate: Bool {
        parseResult.temperatureRows.isEmpty && parseResult.medicationRows.isEmpty
    }

    private var totalImportCount: Int {
        parseResult.temperatureRows.count + parseResult.medicationRows.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // 4.4 Preview counts
                Section("导入预览") {
                    HStack {
                        Label("体温记录", systemImage: "thermometer")
                        Spacer()
                        Text("\(parseResult.temperatureRows.count) 条")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("用药记录", systemImage: "pill")
                        Spacer()
                        Text("\(parseResult.medicationRows.count) 条")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("重复跳过", systemImage: "arrow.uturn.backward.circle")
                        Spacer()
                        Text("\(parseResult.skippedCount) 条")
                            .foregroundStyle(.secondary)
                    }
                }

                // 4.5 All-duplicate message
                if isAllDuplicate {
                    Section {
                        Text("全部 \(parseResult.skippedCount) 条记录已存在，无需导入")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("确认导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                // 4.5 Confirm button disabled when all duplicates
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认导入") { confirmImport() }
                        .fontWeight(.semibold)
                        .disabled(isAllDuplicate)
                }
            }
        }
    }

    // MARK: - 4.6 Confirm import

    private func confirmImport() {
        for record in parseResult.temperatureRows {
            modelContext.insert(record)
        }
        for record in parseResult.medicationRows {
            modelContext.insert(record)
        }
        try? modelContext.save()
        onComplete(totalImportCount)
        dismiss()
    }
}
