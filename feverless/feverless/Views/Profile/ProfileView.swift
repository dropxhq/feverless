//
//  ProfileView.swift
//  feverless
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \DataRecord.timestamp, order: .reverse) private var allRecords: [DataRecord]

    @Binding var selectedChildIdString: String
    @State private var showAddChild = false
    @State private var childToEdit: Child?

    // 5.4 / 5.5 Export / Import state
    @State private var childForExport: Child?
    @State private var showFileImporter = false

    // Import error alert
    @State private var importError: String?
    @State private var showImportError = false

    // Import preview sheet
    @State private var importPreviewResult: CSVParseResult?
    @State private var showImportPreview = false

    // Multi-step import flow state
    @State private var csvRawRows: [[String]] = []
    @State private var pendingConfig: ImportMappingConfig = ImportMappingConfig()
    @State private var showColumnMappingSheet = false
    @State private var showValueMappingSheet = false
    @State private var unresolvedValueGroups: [UnresolvedValueGroup] = []
    @State private var hasKeywordColumns: Bool = false
    @State private var columnMappingDidComplete: Bool = false
    @State private var valueMappingDidComplete: Bool = false

    // Toast
    @State private var toastMessage: String?

    private var selectedChild: Child? {
        guard let id = UUID(uuidString: selectedChildIdString) else { return nil }
        return children.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            List {
                // Children list
                ForEach(children) { child in
                    childRow(child)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteChild(child)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                childToEdit = child
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }

                // 5.3 / 5.6 Data management section (hidden when no selected child)
                if let child = selectedChild {
                    Section("\(child.name) 的数据") {
                        // 5.4 Export row
                        Button {
                            childForExport = child
                        } label: {
                            Label("导出数据...", systemImage: "square.and.arrow.up")
                        }
                        .foregroundStyle(.primary)

                        // 5.5 Import row
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("导入数据...", systemImage: "square.and.arrow.down")
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // 7.4 Medication management section
                NavigationLink {
                    MedicationCatalogView()
                } label: {
                    Label("药品管理", systemImage: "pills.circle")
                }

                NavigationLink {
                    TemperaturePositionCatalogView(isSheet: false)
                } label: {
                    Label("体温位置管理", systemImage: "thermometer.medium")
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddChild = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // 4.7 Toast overlay
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: toastMessage)
            .sheet(isPresented: $showAddChild) {
                AddChildView(onSave: nil)
            }
            .sheet(item: $childToEdit) { child in
                EditChildView(child: child)
            }
            // 3.1 Export sheet
            .sheet(item: $childForExport) { child in
                ExportSheet(child: child)
            }
            // Import preview sheet
            .sheet(isPresented: $showImportPreview) {
                if let result = importPreviewResult {
                    ImportPreviewSheet(parseResult: result, importConfig: pendingConfig) { count in
                        showToast("已成功导入 \(count) 条记录")
                    }
                }
            }
            // File importer
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText]
            ) { result in
                handleFileImport(result: result)
            }
            // 9.2 Column mapping sheet
            .sheet(isPresented: $showColumnMappingSheet, onDismiss: {
                guard columnMappingDidComplete else { return }
                columnMappingDidComplete = false
                proceedToValueDetection()
            }) {
                ColumnMappingSheet(
                    allHeaders: csvRawRows.first?.map { $0.trimmingCharacters(in: .whitespaces) } ?? [],
                    config: pendingConfig
                ) { updatedConfig in
                    pendingConfig = updatedConfig
                    columnMappingDidComplete = true
                }
            }
            // 9.3 Value mapping sheet
            .sheet(isPresented: $showValueMappingSheet, onDismiss: {
                guard valueMappingDidComplete else { return }
                valueMappingDidComplete = false
                proceedToParse()
            }) {
                ValueMappingSheet(
                    valueGroups: unresolvedValueGroups,
                    config: pendingConfig,
                    hasKeywordColumns: hasKeywordColumns
                ) { updatedConfig in
                    pendingConfig = updatedConfig
                    valueMappingDidComplete = true
                }
            }
            // Import error alert
            .alert("导入失败", isPresented: $showImportError) {
                Button("好") {}
            } message: {
                Text(importError ?? "未知错误")
            }
        }
    }

    // MARK: - 5.1 Card-style child row

    @ViewBuilder
    private func childRow(_ child: Child) -> some View {
        HStack(spacing: 12) {
            Text(child.avatarEmoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.headline)
                // 5.1 Latest temperature subtitle
                Text(latestTempSubtitle(for: child))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // 5.2 Selected child highlight
            if selectedChildIdString == child.id.uuidString {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedChildIdString = child.id.uuidString
        }
    }

    // MARK: - Latest temp helpers

    private func latestTempSubtitle(for child: Child) -> String {
        guard let record = allRecords.first(where: { $0.childId == child.id }),
              let reading = record.temperatures.first else {
            return "暂无体温记录"
        }
        return "最近体温: \(String(format: "%.1f", reading.value))°C · \(relativeTimeString(record.timestamp))"
    }

    private func relativeTimeString(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        if cal.isDateInToday(date) {
            return "今天 \(timeFmt.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            return "昨天 \(timeFmt.string(from: date))"
        } else {
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "M月d日 HH:mm"
            return dateFmt.string(from: date)
        }
    }

    // MARK: - Import flow

    // 9.1 Entry point: load saved config, read raw rows, detect unresolved columns
    private func handleFileImport(result: Result<URL, Error>) {
        guard selectedChild != nil else { return }
        switch result {
        case .failure:
            break
        case .success(let url):
            do {
                let importer = CSVImporter()
                csvRawRows = try importer.readRawRows(url: url)
                pendingConfig = ImportConfigStore.load()

                let headers = csvRawRows.first?.map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                let unresolved = importer.detectUnresolvedColumns(headers: headers, config: pendingConfig)

                if !unresolved.isEmpty {
                    // 9.2 Show column mapping sheet
                    showColumnMappingSheet = true
                } else {
                    proceedToValueDetection()
                }
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

    // 9.3 After column mapping: detect unresolved enum values
    private func proceedToValueDetection() {
        let importer = CSVImporter()
        let aliasTable = ImportAliasTable()
        let dataRows = Array(csvRawRows.dropFirst())
        let headerRow = csvRawRows.first ?? []

        var groups: [UnresolvedValueGroup] = []
        let enumFields: [(field: String, displayName: String)] = [
            ("record_type", "记录类型"),
            ("method", "测量方式"),
            ("medication_type", "药物类型"),
        ]

        for (i, header) in headerRow.enumerated() {
            let trimmed = header.trimmingCharacters(in: .whitespaces)
            // Skip columns with non-simple rules (compound/keyword)
            guard let resolvedField = aliasTable.resolveColumnName(trimmed, config: pendingConfig) else { continue }
            guard let fieldInfo = enumFields.first(where: { $0.field == resolvedField }) else { continue }

            let unresolved = importer.detectUnresolvedValues(
                rows: dataRows, columnIndex: i,
                field: resolvedField, config: pendingConfig
            )
            if !unresolved.isEmpty {
                groups.append(UnresolvedValueGroup(
                    id: resolvedField,
                    fieldDisplayName: fieldInfo.displayName,
                    items: unresolved
                ))
            }
        }

        if !groups.isEmpty {
            unresolvedValueGroups = groups
        }

        // 2.1 Check if any column uses keyword extraction (regardless of enum groups)
        let keywordColumnsExist = pendingConfig.columnMappings.values.contains {
            if case .keywordExtract(_, let extracts) = $0 { return extracts }
            return false
        }
        hasKeywordColumns = keywordColumnsExist

        // 2.2 Show ValueMappingSheet if there are unresolved enum values OR keyword columns
        if !groups.isEmpty || hasKeywordColumns {
            showValueMappingSheet = true
        } else {
            proceedToParse()
        }
    }

    // 9.4 After value mapping: full parse + dedup + preview
    private func proceedToParse() {
        guard let child = selectedChild else { return }
        let importer = CSVImporter()
        do {
            let parsed = try importer.parseRows(csvRawRows, childId: child.id, config: pendingConfig)

            let childId = child.id
            let existingRecords = (try? modelContext.fetch(
                FetchDescriptor<DataRecord>(predicate: #Predicate { $0.childId == childId })
            )) ?? []

            let deduped = importer.deduplicated(
                parseResult: parsed,
                existingRecords: existingRecords
            )

            importPreviewResult = deduped
            showImportPreview = true
        } catch let error as CSVImportError {
            // 9.5 Row-level errors shown with Chinese column names
            importError = error.errorDescription
            showImportError = true
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    // MARK: - 4.7 Toast

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toastMessage = nil
        }
    }

    // MARK: - Delete child

    private func deleteChild(_ child: Child) {
        let childId = child.id

        let recordDescriptor = FetchDescriptor<DataRecord>(
            predicate: #Predicate { $0.childId == childId }
        )

        if let records = try? modelContext.fetch(recordDescriptor) {
            records.forEach { modelContext.delete($0) }
        }

        if selectedChildIdString == child.id.uuidString {
            selectedChildIdString = ""
        }

        modelContext.delete(child)
        try? modelContext.save()
    }
}

// MARK: - AddChildView

private let childEmojiOptions = ["🧒", "👦", "👧", "🧑", "🐣", "🌟", "🦊", "🐶", "🐱", "🐼"]

struct AddChildView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date()
    @State private var hasBirthDate: Bool = false
    @State private var avatarEmoji: String = "🧒"

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名（必填）", text: $name)
                    Toggle("设置出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker(
                            "出生日期",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section("头像") {
                    emojiPicker(selection: $avatarEmoji)
                }
            }
            .navigationTitle("添加儿童")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let child = Child(
            name: name.trimmingCharacters(in: .whitespaces),
            birthDate: hasBirthDate ? birthDate : nil,
            avatarEmoji: avatarEmoji
        )
        modelContext.insert(child)
        try? modelContext.save()
        onSave?()
        dismiss()
    }
}

// MARK: - EditChildView

struct EditChildView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let child: Child

    @State private var name: String
    @State private var birthDate: Date
    @State private var hasBirthDate: Bool
    @State private var avatarEmoji: String

    init(child: Child) {
        self.child = child
        _name         = State(initialValue: child.name)
        _birthDate    = State(initialValue: child.birthDate ?? Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date())
        _hasBirthDate = State(initialValue: child.birthDate != nil)
        _avatarEmoji  = State(initialValue: child.avatarEmoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名（必填）", text: $name)
                    Toggle("设置出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker(
                            "出生日期",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section("头像") {
                    emojiPicker(selection: $avatarEmoji)
                }
            }
            .navigationTitle("编辑儿童")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        child.name      = name.trimmingCharacters(in: .whitespaces)
        child.birthDate = hasBirthDate ? birthDate : nil
        child.avatarEmoji = avatarEmoji
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared Emoji Picker

@ViewBuilder
private func emojiPicker(selection: Binding<String>) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            ForEach(childEmojiOptions, id: \.self) { emoji in
                Button(emoji) {
                    selection.wrappedValue = emoji
                }
                .font(.title2)
                .padding(8)
                .background(
                    Circle().fill(selection.wrappedValue == emoji
                                  ? Color.blue.opacity(0.2)
                                  : Color.clear)
                )
            }
        }
    }
}
