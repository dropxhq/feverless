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
        }
    }
}

struct ChartView: View {
    @Query(sort: \TemperatureRecord.timestamp) private var allTempRecords: [TemperatureRecord]
    @Query(sort: \MedicationRecord.timestamp)  private var allMedRecords:  [MedicationRecord]

    let selectedChild: Child?
    @State private var timeRange: ChartTimeRange = .today

    private var range: (start: Date, end: Date) { timeRange.dateRange }

    private var tempRecords: [TemperatureRecord] {
        guard let child = selectedChild else { return [] }
        return allTempRecords.filter {
            $0.childId == child.id &&
            $0.timestamp >= range.start &&
            $0.timestamp <= range.end
        }
    }

    private var medRecords: [MedicationRecord] {
        guard let child = selectedChild else { return [] }
        return allMedRecords.filter {
            $0.childId == child.id &&
            $0.timestamp >= range.start &&
            $0.timestamp <= range.end
        }
    }

    private var combinedRecords: [AnyRecentRecord] {
        var items: [AnyRecentRecord] = tempRecords.map { .temperature($0) }
        items += medRecords.map { .medication($0) }
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if tempRecords.isEmpty {
                        ContentUnavailableView(
                            "暂无记录",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("\(timeRange.rawValue)内没有体温记录")
                        )
                        .padding(.top, 60)
                    } else {
                        chartSection
                    }

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
                    if let first = tempRecords.first {
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

            Chart {
                // Normal zone background (below 37°)
                RectangleMark(
                    yStart: .value("lo", yDomain.lowerBound),
                    yEnd: .value("hi", 37.0)
                )
                .foregroundStyle(Color.green.opacity(0.07))

                // Temperature area fill + line + labeled points
                ForEach(tempRecords, id: \.id) { record in
                    AreaMark(
                        x: .value("时间", record.timestamp),
                        yStart: .value("底", yDomain.lowerBound),
                        yEnd: .value("体温", record.value)
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
                        x: .value("时间", record.timestamp),
                        y: .value("体温", record.value)
                    )
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("时间", record.timestamp),
                        y: .value("体温", record.value)
                    )
                    .foregroundStyle(Color.red)
                    .symbolSize(50)
                    .annotation(position: .top, spacing: 4) {
                        Text(String(format: "%.1f", record.value))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(record.isFever ? Color.red : Color.secondary)
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
                ForEach(medRecords, id: \.id) { record in
                    RuleMark(x: .value("用药", record.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(record.type.color.opacity(0.6))
                        .annotation(position: .top, spacing: 4) {
                            HStack(spacing: 2) {
                                Text(record.type.emoji).font(.system(size: 8))
                                Text(record.type.displayName)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(record.type.color)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(record.type.color.opacity(0.15)))
                        }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .frame(height: 220)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text("体温").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if medRecords.contains(where: { $0.type == .ibuprofen }) {
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.yellow).frame(width: 14, height: 2)
                        Text("布洛芬").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                if medRecords.contains(where: { $0.type == .acetaminophen }) {
                    HStack(spacing: 4) {
                        Rectangle().fill(Color.blue).frame(width: 14, height: 2)
                        Text("对乙酰氨基酚").font(.system(size: 10)).foregroundStyle(.secondary)
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
        let vals = tempRecords.map { $0.value }
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
                        case .temperature(let r):
                            RoundedRectangle(cornerRadius: 10)
                                .fill(r.isFever ? Color.red.opacity(0.08) : Color.green.opacity(0.1))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "thermometer.medium")
                                        .font(.system(size: 14))
                                        .foregroundStyle(r.isFever ? Color.red : Color.green)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f°C", r.value))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(r.isFever ? Color.red : Color.primary)
                                    Text("· " + r.method.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if r.isFever {
                                        Text(r.value >= 39.0 ? "高烧" : "发烧")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.red)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                Text(r.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        case .medication(let r):
                            RoundedRectangle(cornerRadius: 10)
                                .fill(r.type == .ibuprofen ? Color.yellow.opacity(0.12) : Color.blue.opacity(0.08))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "pill.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(r.type.color)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.type.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(r.timestamp.formatted(date: .abbreviated, time: .shortened))
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
