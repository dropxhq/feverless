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
                    Picker("时间范围", selection: $timeRange) {
                        ForEach(ChartTimeRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

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
        Chart {
            ForEach(tempRecords, id: \.id) { record in
                LineMark(
                    x: .value("时间",  record.timestamp),
                    y: .value("体温", record.value)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("时间",  record.timestamp),
                    y: .value("体温", record.value)
                )
                .foregroundStyle(record.isFever ? Color.red : Color.orange)
                .symbolSize(40)
            }

            // 37.0°C normal reference line
            RuleMark(y: .value("正常", 37.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .annotation(position: .leading, alignment: .center) {
                    Text("37°C")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            // Medication time markers
            ForEach(medRecords, id: \.id) { record in
                RuleMark(x: .value("用药", record.timestamp))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(record.type.color.opacity(0.7))
                    .annotation(position: .top) {
                        Text(record.type.emoji)
                            .font(.caption2)
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
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        switch item {
                        case .temperature(let r):
                            Image(systemName: "thermometer.medium")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f°C", r.value))
                                        .fontWeight(.medium)
                                    Text("· " + r.method.displayName)
                                        .foregroundStyle(.secondary)
                                    if r.isFever {
                                        Text("发烧")
                                            .font(.caption2)
                                            .padding(.horizontal, 6).padding(.vertical, 1)
                                            .background(Color.red.opacity(0.15))
                                            .foregroundStyle(.red)
                                            .clipShape(Capsule())
                                    }
                                }
                                .font(.subheadline)
                                Text(r.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        case .medication(let r):
                            Image(systemName: "pill.fill")
                                .foregroundStyle(r.type.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.type.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
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
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}
