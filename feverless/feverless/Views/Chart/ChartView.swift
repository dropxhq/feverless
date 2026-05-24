//
//  ChartView.swift
//  feverless
//

import SwiftUI
import SwiftData
import Charts

enum ChartTimeRange: String, CaseIterable {
    case today     = "今天"
    case yesterday = "昨天"
    case week      = "7天"
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
        case .all:
            return (.distantPast, now)
        }
    }

    var spansMultipleDays: Bool {
        switch self {
        case .today, .yesterday: return false
        case .week, .all:        return true
        }
    }
}

struct ChartView: View {
    @Query(sort: \DataRecord.timestamp) private var allRecords: [DataRecord]
    @ObservedObject private var catalog = MedicationCatalog.shared

    let selectedChild: Child?
    @State private var timeRange: ChartTimeRange = .today

    private var range: (start: Date, end: Date) { timeRange.dateRange }

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
                .padding(.bottom, 32)
            }
            .navigationTitle("图表")
        }
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with range selector
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本次发烧")
                        .font(.system(size: 15, weight: .bold))
                    if let first = tempPoints.first {
                        Text(
                            first.timestamp.formatted(date: .abbreviated, time: .omitted)
                            + " "
                            + first.timestamp.formatted(date: .omitted, time: .shortened)
                            + " 起"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(ChartTimeRange.allCases, id: \.self) { r in
                        Button(r.rawValue) { timeRange = r }
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
                    .symbolSize(50)
                    .annotation(position: .top, spacing: 4) {
                        Text(String(format: "%.1f", point.value))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(point.isFever ? Color.red : Color.secondary)
                    }
                }

                // 38.5°C fever threshold line
                RuleMark(y: .value("发烧", 38.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.red.opacity(0.55))
                    .annotation(position: .leading, alignment: .center) {
                        Text("38.5°")
                            .font(.caption2)
                            .foregroundStyle(Color.red.opacity(0.8))
                    }

                // 37.0°C normal reference line
                RuleMark(y: .value("正常", 37.0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.teal.opacity(0.5))
                    .annotation(position: .leading, alignment: .center) {
                        Text("37°")
                            .font(.caption2)
                            .foregroundStyle(Color.teal.opacity(0.8))
                    }

                // Medication time markers
                ForEach(medPoints) { point in
                    let medColor = MedicationCatalog.shared.color(for: point.medicationNameRaw)
                    RuleMark(x: .value("用药", point.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(medColor.opacity(0.6))
                        .annotation(position: .top, spacing: 4) {
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
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    if timeRange.spansMultipleDays {
                        AxisValueLabel(format: .dateTime.month().day().hour())
                    } else {
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
            }
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

    private var yDomain: ClosedRange<Double> {
        let vals = tempPoints.map { $0.value }
        let lo = (vals.min() ?? 36.0) - 0.5
        let hi = (vals.max() ?? 39.0) + 0.5
        return min(lo, 35.5)...max(hi, 38.5)
    }

    // MARK: Records List

    @ViewBuilder
    private var recordsListSection: some View {
        let items = combinedRecords
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("记录明细")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
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

                    if index < items.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}
