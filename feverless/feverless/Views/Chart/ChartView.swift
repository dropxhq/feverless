//
//  ChartView.swift
//  feverless
//

import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

enum ChartTimeRange: String, CaseIterable {
    case today     = "今天"
    case yesterday = "昨天"
    case week      = "7天"
    case custom    = "自定义"
    case all       = "全部"

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let cal = Calendar.current
        switch self {
        case .today:
            return (cal.startOfDay(for: now), now)
        case .yesterday:
            let yStart = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: now)!)
            let yEnd   = cal.date(byAdding: .day, value: 1, to: yStart)!
            return (yStart, min(yEnd, now))
        case .week:
            return (cal.date(byAdding: .day, value: -7, to: now)!, now)
        case .custom:
            return (.distantPast, now) // overridden in ChartView
        case .all:
            return (.distantPast, now)
        }
    }

    var spansMultipleDays: Bool {
        switch self {
        case .today, .yesterday:    return false
        case .week, .custom, .all:  return true
        }
    }
}

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DataRecord.timestamp) private var allRecords: [DataRecord]
    @ObservedObject private var catalog = MedicationCatalog.shared

    let selectedChild: Child?
    @State private var timeRange: ChartTimeRange = .today
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()
    @State private var showingCustomPicker = false

    // Import / Export state
    @State private var childForExport: Child?
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var importPreviewResult: CSVParseResult? = nil
    @State private var csvRawRows: [[String]] = []
    @State private var pendingConfig: ImportMappingConfig = ImportMappingConfig()
    @State private var showColumnMappingSheet = false
    @State private var valueMappingInput: ValueMappingInput? = nil
    @State private var columnMappingDidComplete: Bool = false
    @State private var valueMappingConfirmed: Bool = false
    @State private var toastMessage: String?

    private var range: (start: Date, end: Date) {
        timeRange == .custom
            ? (Calendar.current.startOfDay(for: customStart), customEnd)
            : timeRange.dateRange
    }

    private var axisSpanDays: Int {
        Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
    }
    private var useAxisDateOnly: Bool { axisSpanDays > 14 }
    private var useAxisMultiDay: Bool { axisSpanDays > 1 }

    private var customRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: customStart))–\(fmt.string(from: customEnd))"
    }

    private var feverEpisode: FeverEpisode? {
        guard let child = selectedChild else { return nil }
        let records = allRecords.filter { $0.childId == child.id }
        return FeverEpisodeDetector.currentEpisode(for: records)
    }

    // Flattened temperature readings with their parent record timestamps
    private struct TempPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let value: Double
        let positionRaw: String
        var isFever: Bool { TemperaturePositionCatalog.shared.find(positionRaw).map { value >= $0.feverThreshold } ?? (value >= 37.5) }
    }

    private struct MedPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let medicationNameRaw: String
    }

    private var tempPoints: [TempPoint] {
        guard let child = selectedChild else { return [] }
        return allRecords
            .filter { $0.childId == child.id && $0.timestamp >= range.start && $0.timestamp <= range.end }
            .flatMap { record in
                record.temperatures.map { TempPoint(timestamp: record.timestamp, value: $0.value, positionRaw: $0.positionRaw) }
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var medPoints: [MedPoint] {
        guard let child = selectedChild else { return [] }
        return allRecords
            .filter { $0.childId == child.id && $0.timestamp >= range.start && $0.timestamp <= range.end }
            .flatMap { record in
                record.medications.map { MedPoint(timestamp: record.timestamp, medicationNameRaw: $0.medicationNameRaw) }
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var combinedRecords: [AnyRecentRecord] {
        guard let child = selectedChild else { return [] }
        let childRecords = allRecords.filter {
            $0.childId == child.id && $0.timestamp >= range.start && $0.timestamp <= range.end
        }
        var items: [AnyRecentRecord] = []
        for record in childRecords {
            items += record.temperatures.map { .temperature(record: record, reading: $0) }
            items += record.medications.map { .medication(record: record, usage: $0) }
        }
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    chartSection
                    recordsListSection
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("图表")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(item: $childForExport) { child in
                ExportSheet(child: child)
            }
            .sheet(item: $importPreviewResult) { result in
                ImportPreviewSheet(parseResult: result, importConfig: pendingConfig) { count in
                    showToast("已成功导入 \(count) 条记录")
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText]
            ) { result in
                handleFileImport(result: result)
            }
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
            .sheet(item: $valueMappingInput, onDismiss: {
                guard valueMappingConfirmed else { return }
                valueMappingConfirmed = false
                proceedToParse()
            }) { input in
                ValueMappingSheet(
                    valueGroups: input.valueGroups,
                    config: input.config,
                    hasKeywordColumns: input.hasKeywordColumns
                ) { updatedConfig in
                    pendingConfig = updatedConfig
                    valueMappingConfirmed = true
                    valueMappingInput = nil
                }
            }
            .alert("导入失败", isPresented: $showImportError) {
                Button("好") {}
            } message: {
                Text(importError ?? "未知错误")
            }
        }
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        if feverEpisode != nil {
                            Text("本次发烧")
                                .font(.system(size: 15, weight: .bold))
                            if let episode = feverEpisode {
                                Text(
                                    episode.startDate.formatted(date: .abbreviated, time: .omitted)
                                    + " "
                                    + episode.startDate.formatted(date: .omitted, time: .shortened)
                                    + " 起"
                                )
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("体温记录")
                                .font(.system(size: 15, weight: .bold))
                            if let last = tempPoints.last {
                                Text("最近记录：" + last.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    Menu {
                        Button {
                            if let child = selectedChild { childForExport = child }
                        } label: {
                            Label("导出数据...", systemImage: "square.and.arrow.up")
                        }
                        .disabled(selectedChild == nil)
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("导入数据...", systemImage: "square.and.arrow.down")
                        }
                        .disabled(selectedChild == nil)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    ForEach(ChartTimeRange.allCases, id: \.self) { r in
                        Button {
                            timeRange = r
                            if r == .custom { showingCustomPicker = true }
                        } label: {
                            if r == .custom {
                                HStack(spacing: 3) {
                                    Image(systemName: "calendar").font(.system(size: 10))
                                    Text(r.rawValue)
                                }
                            } else {
                                Text(r.rawValue)
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(timeRange == r ? .white : Color.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(timeRange == r ? Color.blue : Color.gray.opacity(0.1))
                        )
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            if tempPoints.isEmpty {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(timeRange == .all ? "暂无任何体温记录" : "\(timeRange.rawValue)内没有体温记录")
                )
                .frame(height: 220)
            } else {
            Chart {
                // Normal zone background (below 37°)
                RectangleMark(
                    yStart: .value("lo", yDomain.lowerBound),
                    yEnd: .value("hi", 37.0)
                )
                .foregroundStyle(Color.green.opacity(0.07))

                // Temperature area fill + line + labeled points
                ForEach(tempPoints) { point in
                    AreaMark(
                        x: .value("时间", point.timestamp),
                        yStart: .value("底", yDomain.lowerBound),
                        yEnd: .value("体温", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.red.opacity(0.25), Color.red.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("体温", point.value)
                    )
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("时间", point.timestamp),
                        y: .value("体温", point.value)
                    )
                    .foregroundStyle(Color.red)
                    .symbolSize(tempPoints.count > 20 ? 20 : 50)
                    .annotation(position: .top, spacing: 4) {
                        if tempPoints.count <= 20 {
                            Text(String(format: "%.1f", point.value))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(point.isFever ? Color.red : Color.secondary)
                        }
                    }
                }

                // 38.5°C fever threshold line
                RuleMark(y: .value("发烧", 38.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.red.opacity(0.55))

                // 37.0°C normal reference line
                RuleMark(y: .value("正常", 37.0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.teal.opacity(0.5))

                // Medication time markers
                ForEach(medPoints) { point in
                    let medColor = MedicationCatalog.shared.color(for: point.medicationNameRaw)
                    RuleMark(x: .value("用药", point.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(medColor.opacity(0.6))
                        .annotation(position: .top, spacing: 4) {
                            if tempPoints.count <= 20 {
                                HStack(spacing: 2) {
                                    Text(MedicationCatalog.shared.emoji(for: point.medicationNameRaw)).font(.system(size: 8))
                                    Text(point.medicationNameRaw)
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(medColor)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(medColor.opacity(0.15)))
                            }
                        }
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            if abs(v - 38.5) < 0.01 {
                                Text("38.5°")
                                    .font(.caption2)
                                    .foregroundStyle(Color.red.opacity(0.85))
                            } else if abs(v - 37.0) < 0.01 {
                                Text("37°")
                                    .font(.caption2)
                                    .foregroundStyle(Color.teal.opacity(0.85))
                            } else {
                                Text(String(Int(v)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                AxisMarks(values: [38.5]) { _ in
                    AxisGridLine().foregroundStyle(Color.red.opacity(0.2))
                    AxisValueLabel {
                        Text("38.5°")
                            .font(.caption2)
                            .foregroundStyle(Color.red.opacity(0.85))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    if useAxisDateOnly {
                        AxisValueLabel(format: .dateTime.year().month().day())
                    } else if useAxisMultiDay {
                        AxisValueLabel(format: .dateTime.month().day().hour())
                    } else {
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
            }
            .sheet(isPresented: $showingCustomPicker) { customPickerSheet }
            .frame(height: 220)
            } // end if tempPoints.isEmpty

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text("体温").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                let shownMedNames = Set(medPoints.map { $0.medicationNameRaw }).subtracting(["其他"])
                ForEach(Array(shownMedNames.sorted()), id: \.self) { name in
                    HStack(spacing: 4) {
                        Rectangle().fill(MedicationCatalog.shared.color(for: name)).frame(width: 14, height: 2)
                        Text(name).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 14, height: 9)
                    Text("正常区间").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: Month grouping

    private struct MonthGroup: Identifiable {
        let id: String          // "yyyy-MM"
        let header: String      // "2026年5月"
        let items: [AnyRecentRecord]
    }

    private var groupedRecords: [MonthGroup] {
        let items = combinedRecords
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"
        var groups: [MonthGroup] = []
        var indexMap: [String: Int] = [:]
        for item in items {
            let comps = cal.dateComponents([.year, .month], from: item.date)
            let key = String(format: "%04d-%02d", comps.year!, comps.month!)
            if let idx = indexMap[key] {
                let g = groups[idx]
                groups[idx] = MonthGroup(id: g.id, header: g.header, items: g.items + [item])
            } else {
                indexMap[key] = groups.count
                groups.append(MonthGroup(id: key, header: fmt.string(from: item.date), items: [item]))
            }
        }
        return groups
    }

    @ViewBuilder
    private var customPickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker("开始日期", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                DatePicker("结束日期", selection: $customEnd, in: customStart...Date(), displayedComponents: .date)
            }
            .navigationTitle("自定义范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingCustomPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var yDomain: ClosedRange<Double> {
        let vals = tempPoints.map { $0.value }
        let lo = (vals.min() ?? 36.0) - 0.5
        let hi = (vals.max() ?? 39.0) + 0.5
        return min(lo, 35.5)...max(hi, 38.5)
    }

    // MARK: Records List

    @ViewBuilder
    private var recordsListSection: some View {
        let groups = groupedRecords
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("记录明细")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                ForEach(groups) { group in
                    // Month header — only show when viewing multiple months
                    if groups.count > 1 {
                        HStack {
                            Text(group.header)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(Color(.systemGroupedBackground).opacity(0.6))
                    }

                    ForEach(Array(group.items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            switch item {
                            case .temperature(let record, let reading):
                                let isFever = reading.isFever()
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isFever ? Color.red.opacity(0.08) : Color.green.opacity(0.1))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "thermometer.medium")
                                            .font(.system(size: 14))
                                            .foregroundStyle(isFever ? Color.red : Color.green)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(String(format: "%.1f°C", reading.value))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(isFever ? Color.red : Color.primary)
                                        Text("· " + reading.positionRaw)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if isFever {
                                            Text(reading.value >= 39.0 ? "高烧" : "发烧")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Color.red)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                        }
                                    }
                                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                            case .medication(let record, let usage):
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(MedicationCatalog.shared.color(for: usage.medicationNameRaw).opacity(0.12))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "pill.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(MedicationCatalog.shared.color(for: usage.medicationNameRaw))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(usage.medicationNameRaw)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)

                        if index < group.items.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }

                    if group.id != groups.last?.id {
                        Divider()
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    // MARK: Import flow

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
                // 始终显示列名映射，让用户确认或调整
                showColumnMappingSheet = true
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

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
        let keywordColumnsExist = pendingConfig.columnMappings.values.contains {
            if case .keywordExtract(_, let extracts) = $0 { return extracts }
            return false
        }
        if !groups.isEmpty || keywordColumnsExist {
            valueMappingInput = ValueMappingInput(
                valueGroups: groups,
                config: pendingConfig,
                hasKeywordColumns: keywordColumnsExist
            )
        } else {
            proceedToParse()
        }
    }

    private func proceedToParse() {
        guard let child = selectedChild else { return }
        let importer = CSVImporter()
        do {
            let parsed = try importer.parseRows(csvRawRows, childId: child.id, config: pendingConfig)
            let childId = child.id
            let existingRecords = (try? modelContext.fetch(
                FetchDescriptor<DataRecord>(predicate: #Predicate { $0.childId == childId })
            )) ?? []
            let deduped = importer.deduplicated(parseResult: parsed, existingRecords: existingRecords)
            importPreviewResult = deduped
        } catch let error as CSVImportError {
            importError = error.errorDescription
            showImportError = true
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toastMessage = nil
        }
    }
}
