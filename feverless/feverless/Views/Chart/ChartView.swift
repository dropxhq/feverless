//
//  ChartView.swift
//  feverless
//

import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers
import WidgetKit

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

    // Edit / Delete / Multi-select state
    @State private var editingRecord: DataRecord? = nil
    @State private var recordPendingDelete: DataRecord? = nil
    @State private var isSelecting: Bool = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showBatchDeleteConfirm: Bool = false

    private var range: (start: Date, end: Date) {
        timeRange == .custom
            ? (Calendar.current.startOfDay(for: customStart), customEnd)
            : timeRange.dateRange
    }

    /// 实际数据起点："全部"模式 range.start 为 distantPast，改用第一个数据点时间
    private var effectiveRangeStart: Date {
        range.start == .distantPast ? (tempPoints.first?.timestamp ?? Date()) : range.start
    }

    private var axisSpanDays: Int {
        Calendar.current.dateComponents([.day], from: effectiveRangeStart, to: range.end).day ?? 0
    }
    private var axisSpanMonths: Int {
        Calendar.current.dateComponents([.month], from: effectiveRangeStart, to: range.end).month ?? 0
    }
    private var useAxisDateOnly: Bool { axisSpanDays > 14 }
    private var useAxisMultiDay: Bool { axisSpanDays > 1 }
    private var useMonthlyAggregation: Bool { axisSpanMonths >= 3 && axisSpanMonths < 12 }

    /// 月度视图横坐标步长：根据实际月份数等间隔抽取，保证屏幕能放下
    private var xAxisMonthStride: Int {
        let totalMonths = max(1, axisSpanMonths)
        let maxFit = 4   // 保守估计屏幕能容纳的最大标签数
        return max(1, Int(ceil(Double(totalMonths) / Double(maxFit))))
    }

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

    // 数据量超过阈值时，chart 切换到聚合视图以减少 GPU mark 数量
    private let chartPointThreshold = 80

    private var useSeasonalChart: Bool { axisSpanMonths >= 12 }
    private var useAggregatedChart: Bool { useSeasonalChart || useMonthlyAggregation || tempPoints.count > chartPointThreshold }

    /// 用于图表渲染的体温点：
    /// - 超过 6 个月 → 每月最高体温
    /// - 超过阈值点数 → 每日最高体温
    private var chartTempPoints: [TempPoint] {
        let cal = Calendar.current
        if useMonthlyAggregation {
            var byMonth: [Date: TempPoint] = [:]
            for pt in tempPoints {
                let comps = cal.dateComponents([.year, .month], from: pt.timestamp)
                let key = cal.date(from: comps)!
                if let existing = byMonth[key] {
                    if pt.value > existing.value { byMonth[key] = pt }
                } else {
                    byMonth[key] = pt
                }
            }
            return byMonth.values.sorted { $0.timestamp < $1.timestamp }
        } else if tempPoints.count > chartPointThreshold {
            var byDay: [Date: TempPoint] = [:]
            for pt in tempPoints {
                let day = cal.startOfDay(for: pt.timestamp)
                if let existing = byDay[day] {
                    if pt.value > existing.value { byDay[day] = pt }
                } else {
                    byDay[day] = pt
                }
            }
            return byDay.values.sorted { $0.timestamp < $1.timestamp }
        } else {
            return tempPoints
        }
    }

    /// 超阈值时每天只保留第一条用药记录；月度聚合及季节性视图不显示用药
    private var chartMedPoints: [MedPoint] {
        if useSeasonalChart || useMonthlyAggregation { return [] }
        guard useAggregatedChart else { return medPoints }
        let cal = Calendar.current
        var seenDays = Set<Date>()
        return medPoints.filter { pt in
            let day = cal.startOfDay(for: pt.timestamp)
            return seenDays.insert(day).inserted
        }
    }

    // MARK: - Seasonal analysis (span > 1 year)

    private struct SeasonalPoint: Identifiable {
        let id: Int          // 1–12
        let monthLabel: String
        let ratio: Double    // feverDays / totalCalendarDays
        let feverDays: Int
        let totalCalendarDays: Int
    }

    private var seasonalPoints: [SeasonalPoint] {
        guard let child = selectedChild else { return [] }
        let cal = Calendar.current
        let childRecords = allRecords.filter {
            $0.childId == child.id && $0.timestamp >= range.start && $0.timestamp <= range.end
        }
        guard !childRecords.isEmpty else { return [] }

        let dataStart = childRecords.map { $0.timestamp }.min()!
        let dataEnd   = childRecords.map { $0.timestamp }.max()!
        let firstYear = cal.component(.year, from: dataStart)
        let lastYear  = cal.component(.year, from: dataEnd)

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"

        var feverDaysByMonth = [Int: Set<String>]()
        for record in childRecords {
            let hasFever = record.temperatures.contains { temp in
                TemperaturePositionCatalog.shared.find(temp.positionRaw)
                    .map { temp.value >= $0.feverThreshold } ?? (temp.value >= 37.5)
            }
            if hasFever {
                let month = cal.component(.month, from: record.timestamp)
                feverDaysByMonth[month, default: []].insert(dayFmt.string(from: record.timestamp))
            }
        }

        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "M月"

        return (1...12).map { month in
            var totalDays = 0
            for year in firstYear...lastYear {
                var comps = DateComponents()
                comps.year = year; comps.month = month; comps.day = 1
                if let d = cal.date(from: comps), let r = cal.range(of: .day, in: .month, for: d) {
                    totalDays += r.count
                }
            }
            var lc = DateComponents(); lc.year = 2000; lc.month = month; lc.day = 1
            let labelDate = cal.date(from: lc)!
            let feverDays = feverDaysByMonth[month]?.count ?? 0
            return SeasonalPoint(
                id: month,
                monthLabel: monthFmt.string(from: labelDate),
                ratio: totalDays > 0 ? Double(feverDays) / Double(totalDays) : 0,
                feverDays: feverDays,
                totalCalendarDays: totalDays
            )
        }
    }

    private var combinedRecords: [RecordDisplayItem] {
        guard let child = selectedChild else { return [] }
        let childRecords = allRecords.filter {
            $0.childId == child.id && $0.timestamp >= range.start && $0.timestamp <= range.end
        }
        var items: [RecordDisplayItem] = []
        for record in childRecords {
            if let temp = record.temperatures.first, let med = record.medications.first {
                items.append(.combined(record: record, reading: temp, usage: med))
            } else if let temp = record.temperatures.first {
                items.append(.temperature(record: record, reading: temp))
            } else if let med = record.medications.first {
                items.append(.medication(record: record, usage: med))
            }
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
            .sheet(item: $editingRecord) { record in
                RecordView(mode: .edit(record: record))
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    chartMultiSelectBar
                }
            }
            .onChange(of: timeRange) { _, _ in
                isSelecting = false
                selectedIds = []
            }
        }
        .confirmationDialog(
            recordPendingDelete.map { $0.temperatures.isEmpty || $0.medications.isEmpty ? "" : "将同时删除关联的体温和用药记录" } ?? "",
            isPresented: Binding(get: { recordPendingDelete != nil }, set: { if !$0 { recordPendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let record = recordPendingDelete {
                Button("删除记录", role: .destructive) {
                    deleteRecord(record)
                    recordPendingDelete = nil
                }
                Button("取消", role: .cancel) { recordPendingDelete = nil }
            }
        }
        .confirmationDialog("确认批量删除", isPresented: $showBatchDeleteConfirm, titleVisibility: .visible) {
            Button("删除 \(selectedIds.count) 条记录", role: .destructive) {
                deleteBatch(from: combinedRecords)
            }
            Button("取消", role: .cancel) {}
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
            } else if useSeasonalChart {
                // 季节性发烧规律图：各月份发烧天数占比
                let maxRatio = seasonalPoints.map { $0.ratio }.max() ?? 0.1
                Chart {
                    ForEach(seasonalPoints) { point in
                        BarMark(
                            x: .value("月份", point.monthLabel),
                            yStart: .value("底", 0.0),
                            yEnd: .value("发烧比例", point.ratio)
                        )
                        .foregroundStyle(
                            point.ratio > 0
                                ? Color.red.opacity(0.35 + point.ratio / max(maxRatio, 0.01) * 0.55)
                                : Color.gray.opacity(0.15)
                        )
                        .cornerRadius(4)
                        .annotation(position: .top, spacing: 2) {
                            if point.feverDays > 0 {
                                Text("\(Int((point.ratio * 100).rounded()))%")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(Color.red.opacity(0.75))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(max(maxRatio, 0.05) * 1.35))
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int((v * 100).rounded()))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in AxisValueLabel().font(.caption2) }
                }
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
                ForEach(chartTempPoints) { point in
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
                    .symbolSize(chartTempPoints.count > 20 ? 20 : 50)
                    .annotation(position: .top, spacing: 4) {
                        if chartTempPoints.count <= 20 {
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

                // Medication time markers (only when dataset is small enough)
                ForEach(chartMedPoints) { point in
                    let medColor = MedicationCatalog.shared.color(for: point.medicationNameRaw)
                    RuleMark(x: .value("用药", point.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(medColor.opacity(0.6))
                        .annotation(position: .top, spacing: 4) {
                            if chartTempPoints.count <= 20 {
                                MedicationCatalog.shared.iconView(for: point.medicationNameRaw, size: 20)
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
                if useMonthlyAggregation {
                    // 月度聚合视图：每月一个刻度，显示 “N月”，最多展示全部12个
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month())
                    }
                } else if chartTempPoints.count <= 8 {
                    // 数据点较少：直接用实际时间戳作为刻度，确保每个点都有标签
                    AxisMarks(values: chartTempPoints.map { $0.timestamp }) { _ in
                        AxisGridLine()
                        if useAxisDateOnly {
                            AxisValueLabel(format: .dateTime.month().day())
                        } else if useAxisMultiDay {
                            AxisValueLabel(format: .dateTime.month().day().hour())
                        } else {
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: axisSpanDays > 30 ? 4 : 5)) { _ in
                        AxisGridLine()
                        if useAxisDateOnly {
                            // 超 14 天：简短 M/d 格式，避免重叠
                            AxisValueLabel(format: .dateTime.month().day())
                        } else if useAxisMultiDay {
                            AxisValueLabel(format: .dateTime.month().day().hour())
                        } else {
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                }
            }
            .chartPlotStyle { $0.padding(.top, 26) }  // 为顶部 annotation 预留空间，防止溢出到按钮行
            .frame(height: 220)
            } // end if tempPoints.isEmpty

            // Legend
            if useSeasonalChart {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.7)).frame(width: 12, height: 12)
                    Text("有发烧记录的天数占该月总天数的比例").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
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
            } // end legend switch

            // 聚合模式提示
            if useSeasonalChart {
                Text("数据跨度超过 1 年，显示各月份历史发烧天数占比")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if useAggregatedChart {
                Text(useMonthlyAggregation ? "数据跨度超过 3 个月，图表显示每月最高体温" : "数据点较多，图表显示每日最高体温")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .sheet(isPresented: $showingCustomPicker) { customPickerSheet }
    }

    // MARK: Month grouping

    private struct MonthGroup: Identifiable {
        let id: String          // "yyyy-MM"
        let header: String      // "2026年5月"
        let items: [RecordDisplayItem]
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
        let vals = chartTempPoints.map { $0.value }
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
                // Section header with global select-all
                HStack {
                    Text("记录明细")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isSelecting {
                        let allVisible = combinedRecords.map(\.id)
                        let allSelected = !allVisible.isEmpty && allVisible.allSatisfy { selectedIds.contains($0) }
                        Button(allSelected ? "取消全选" : "全选") {
                            if allSelected {
                                selectedIds.subtract(allVisible)
                            } else {
                                selectedIds.formUnion(allVisible)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                ForEach(groups) { group in
                    // Month header
                    if groups.count > 1 {
                        HStack {
                            Text(group.header)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isSelecting {
                                Button("全选本组") {
                                    selectedIds.formUnion(group.items.map(\.id))
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(Color(.systemGroupedBackground).opacity(0.6))
                    }

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        chartRecordRow(item, isLast: index == group.items.count - 1 && group.id == groups.last?.id)
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

    @ViewBuilder
    private func chartRecordRow(_ item: RecordDisplayItem, isLast: Bool) -> some View {
        let record = item.record
        let isSelected = selectedIds.contains(record.id)

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }

                switch item {
                case .temperature(_, let reading):
                    chartTempRowContent(reading: reading, timestamp: record.timestamp)
                case .medication(_, let usage):
                    chartMedRowContent(usage: usage, timestamp: record.timestamp)
                case .combined(_, let reading, let usage):
                    chartCombinedRowContent(reading: reading, usage: usage, timestamp: record.timestamp)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .background(isSelected ? Color.blue.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelecting {
                    if isSelected { selectedIds.remove(record.id) } else { selectedIds.insert(record.id) }
                    if selectedIds.isEmpty { isSelecting = false }
                } else {
                    editingRecord = record
                }
            }
            .onLongPressGesture {
                guard !isSelecting else { return }
                isSelecting = true
                selectedIds.insert(record.id)
            }
            .swipeToDelete(isActive: !isSelecting) {
                if !record.temperatures.isEmpty && !record.medications.isEmpty {
                    recordPendingDelete = record
                } else {
                    deleteRecord(record)
                }
            }

            if !isLast {
                Divider().padding(.leading, isSelecting ? 68 : 62)
            }
        }
    }

    // MARK: Chart Row Content Builders

    @ViewBuilder
    private func chartTempRowContent(reading: TemperatureReading, timestamp: Date) -> some View {
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
            }
            Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
        if isFever {
            Text(reading.value >= 39.0 ? "高烧" : "发烧")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.red)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
        }
    }

    @ViewBuilder
    private func chartMedRowContent(usage: MedicationUsage, timestamp: Date) -> some View {
        MedicationCatalog.shared.iconView(for: usage.medicationNameRaw)
        VStack(alignment: .leading, spacing: 2) {
            Text(usage.medicationNameRaw)
                .font(.system(size: 14, weight: .semibold))
            Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
    }

    @ViewBuilder
    private func chartCombinedRowContent(reading: TemperatureReading, usage: MedicationUsage, timestamp: Date) -> some View {
        let isFever = reading.isFever()
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFever ? Color.red.opacity(0.08) : Color.green.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 12))
                            .foregroundStyle(isFever ? Color.red : Color.green)
                    )
                Text(String(format: "%.1f°C", reading.value))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isFever ? Color.red : Color.primary)
                Text("· " + reading.positionRaw)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isFever {
                    Text(reading.value >= 39.0 ? "高烧" : "发烧")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            HStack(spacing: 8) {
                MedicationCatalog.shared.iconView(for: usage.medicationNameRaw, size: 28)
                Text(usage.medicationNameRaw)
                    .font(.system(size: 13, weight: .medium))
            }
            Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Chart Multi-select Bar

    @ViewBuilder
    private var chartMultiSelectBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button {
                    isSelecting = false
                    selectedIds = []
                } label: {
                    Text("取消")
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                }

                Divider().frame(height: 20)

                Text(selectedIds.isEmpty ? "未选中" : "已选 \(selectedIds.count) 条")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Divider().frame(height: 20)

                Button {
                    showBatchDeleteConfirm = true
                } label: {
                    Text("删除")
                        .foregroundStyle(selectedIds.isEmpty ? Color.gray : Color.red)
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIds.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    // MARK: Actions

    private func deleteRecord(_ record: DataRecord) {
        modelContext.delete(record)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func deleteBatch(from items: [RecordDisplayItem]) {
        let toDelete = items.filter { selectedIds.contains($0.id) }.map(\.record)
        for record in toDelete { modelContext.delete(record) }
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        selectedIds = []
        isSelecting = false
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
            ("method", "测量方式"),
            ("medication_type", "药品列"),
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
