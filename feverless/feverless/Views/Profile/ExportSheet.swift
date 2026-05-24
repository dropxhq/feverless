import SwiftUI
import SwiftData
import UIKit

// MARK: - 3.2 Time range options

enum ExportTimeRange: String, CaseIterable, Identifiable {
    case last7Days   = "最近 7 天"
    case last30Days  = "最近 30 天"
    case last3Months = "最近 3 个月"
    case allTime     = "全部数据"
    case custom      = "自定义"

    var id: String { rawValue }
}

// MARK: - Share sheet wrapper (for UIActivityViewController)

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - 3.1 Export sheet

struct ExportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let child: Child

    @Query(sort: \DataRecord.timestamp) private var allRecords: [DataRecord]

    // 3.2 Time range state
    @State private var timeRange: ExportTimeRange = .last30Days
    // 3.3 Custom date range state
    @State private var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var isExporting = false

    // MARK: - Filtered records

    private var childRecords: [DataRecord] {
        allRecords.filter { $0.childId == child.id }
    }

    private var filteredRecords: [DataRecord] {
        childRecords.filter { isInRange($0.timestamp) }
    }

    private var tempCount: Int {
        filteredRecords.reduce(0) { $0 + $1.temperatures.count }
    }

    private var medCount: Int {
        filteredRecords.reduce(0) { $0 + $1.medications.count }
    }

    private var totalRecordCount: Int {
        filteredRecords.count
    }

    private func isInRange(_ date: Date) -> Bool {
        let now = Date()
        let cal = Calendar.current
        switch timeRange {
        case .last7Days:
            return date >= (cal.date(byAdding: .day, value: -7, to: now) ?? now)
        case .last30Days:
            return date >= (cal.date(byAdding: .day, value: -30, to: now) ?? now)
        case .last3Months:
            return date >= (cal.date(byAdding: .month, value: -3, to: now) ?? now)
        case .allTime:
            return true
        case .custom:
            return date >= cal.startOfDay(for: customStart) && date <= endOfDay(customEnd)
        }
    }

    private func endOfDay(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    private var exportDateRange: (start: Date, end: Date) {
        let now = Date()
        let cal = Calendar.current
        switch timeRange {
        case .last7Days:
            return (cal.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case .last30Days:
            return (cal.date(byAdding: .day, value: -30, to: now) ?? now, now)
        case .last3Months:
            return (cal.date(byAdding: .month, value: -3, to: now) ?? now, now)
        case .allTime:
            let allDates = filteredRecords.map { $0.timestamp }
            return (allDates.min() ?? now, allDates.max() ?? now)
        case .custom:
            return (customStart, customEnd)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // 3.2 Time range picker
                Section("时间范围") {
                    Picker("选择范围", selection: $timeRange) {
                        ForEach(ExportTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    // 3.3 Custom date range pickers
                    if timeRange == .custom {
                        DatePicker("开始日期", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                        DatePicker("结束日期", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    }
                }

                // 3.4 Real-time preview
                Section("导出预览") {
                    HStack {
                        Label("体温次数", systemImage: "thermometer")
                        Spacer()
                        Text("\(tempCount) 次")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("用药次数", systemImage: "pill")
                        Spacer()
                        Text("\(medCount) 次")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("记录条数", systemImage: "doc.text")
                        Spacer()
                        Text("\(totalRecordCount) 条")
                            .foregroundStyle(.secondary)
                    }
                    // 3.5 No-record hint
                    if totalRecordCount == 0 {
                        Text("所选时间范围内无记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 3.5 / 3.6 Export button
                Section {
                    Button {
                        exportCSV()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                            } else {
                                Text("导出 CSV")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(totalRecordCount == 0 || isExporting)
                }
            }
            .navigationTitle("导出数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            // 3.6 ShareSheet
            .sheet(isPresented: $showShareSheet) {
                ActivityShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - 3.6 Export action

    private func exportCSV() {
        isExporting = true
        defer { isExporting = false }

        let exporter = CSVExporter()
        let csvString = exporter.export(records: filteredRecords)
        let range = exportDateRange
        let fileName = exporter.generateFileName(childName: child.name, startDate: range.start, endDate: range.end)

        guard let url = try? exporter.writeToTemporaryFile(csvString: csvString, fileName: fileName) else { return }
        shareItems = [url]
        showShareSheet = true
    }
}
