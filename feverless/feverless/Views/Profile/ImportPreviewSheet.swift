import SwiftUI
import SwiftData

// MARK: - ImportPreviewSheet

struct ImportPreviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let parseResult: CSVParseResult
    let importConfig: ImportMappingConfig
    let onComplete: (Int) -> Void

    // MARK: - Helpers

    private var isAllDuplicate: Bool {
        parseResult.records.isEmpty
    }

    private var totalImportCount: Int {
        parseResult.records.count
    }

    private var tempCount: Int {
        parseResult.records.reduce(0) { $0 + $1.temperatures.count }
    }

    private var medCount: Int {
        parseResult.records.reduce(0) { $0 + $1.medications.count }
    }

    // 8.1 Preview time formatter (HH:mm)
    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    // 8.1 First 3 records merged and sorted by timestamp
    private var previewRecords: [PreviewRecord] {
        return parseResult.records.prefix(3).map { record in
            let tempStr = record.temperatures.map { String(format: "%.1f°C %@", $0.value, $0.positionRaw) }.joined(separator: " / ")
            let medStr = record.medications.map { $0.medicationNameRaw }.joined(separator: " / ")
            let label: String
            if !tempStr.isEmpty && !medStr.isEmpty {
                label = "\(tempStr) · \(medStr)"
            } else if !tempStr.isEmpty {
                label = tempStr
            } else {
                label = medStr
            }
            return PreviewRecord(timestamp: record.timestamp, label: label + " " + timeFmt.string(from: record.timestamp))
        }
    }

    private struct PreviewRecord {
        let timestamp: Date
        let label: String
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Counts section
                Section("导入预览") {
                    HStack {
                        Label("数据记录", systemImage: "doc.text")
                        Spacer()
                        Text("\(parseResult.records.count) 条").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("体温读数", systemImage: "thermometer")
                        Spacer()
                        Text("\(tempCount) 次").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("用药记录", systemImage: "pill")
                        Spacer()
                        Text("\(medCount) 次").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("重复跳过", systemImage: "arrow.uturn.backward.circle")
                        Spacer()
                        Text("\(parseResult.skippedCount) 条").foregroundStyle(.secondary)
                    }
                }

                // 8.1 Sample records preview
                if !previewRecords.isEmpty {
                    Section("示例记录") {
                        ForEach(previewRecords.indices, id: \.self) { i in
                            Text(previewRecords[i].label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 8.2 Mapping summary
                let report = parseResult.mappingReport
                let hasColumnMappings = !report.appliedColumnMappings.isEmpty
                let hasValueMappings = !report.appliedValueCounts.isEmpty
                let hasKeywordExtraction = report.keywordExtractionCount > 0

                if hasColumnMappings || hasValueMappings || hasKeywordExtraction {
                    Section("映射摘要") {
                        if hasColumnMappings {
                            HStack {
                                Text("列名映射")
                                Spacer()
                                Text("\(report.appliedColumnMappings.count) 列").foregroundStyle(.secondary)
                            }
                            ForEach(report.appliedColumnMappings.keys.sorted(), id: \.self) { header in
                                if let field = report.appliedColumnMappings[header] {
                                    Text("\(header) → \(fieldDisplayName(field))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if hasValueMappings {
                            ForEach(report.appliedValueCounts.keys.sorted(), id: \.self) { field in
                                if let counts = report.appliedValueCounts[field] {
                                    let total = counts.values.reduce(0, +)
                                    HStack {
                                        Text("值映射（\(fieldDisplayName(field))）")
                                        Spacer()
                                        Text("\(total) 条").foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // 8.3 Keyword extraction count
                        if hasKeywordExtraction {
                            HStack {
                                Text("关键词提取")
                                Spacer()
                                Text("\(report.keywordExtractionCount) 条用药记录").foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // All-duplicate message
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认导入") { confirmImport() }
                        .fontWeight(.semibold)
                        .disabled(isAllDuplicate)
                }
            }
        }
    }

    // MARK: - Confirm import

    private func confirmImport() {
        for record in parseResult.records { modelContext.insert(record) }
        try? modelContext.save()

        // Persist mapping config for future imports
        ImportConfigStore.save(importConfig)

        onComplete(totalImportCount)
        dismiss()
    }

    // MARK: - Helpers

    private let fieldDisplayNames: [String: String] = [
        "timestamp": "时间",
        "value": "体温",
        "method": "测量方式",
        "medication_type": "药品列",
        "concurrent_temperature": "同步体温",
        "notes": "备注",
    ]

    private func fieldDisplayName(_ field: String) -> String {
        fieldDisplayNames[field] ?? field
    }
}
