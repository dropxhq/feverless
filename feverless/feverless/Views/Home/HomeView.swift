//
//  HomeView.swift
//  feverless
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    @State private var animate = false
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 6, height: 6)
            .opacity(animate ? 0.5 : 1.0)
            .scaleEffect(animate ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \DataRecord.timestamp, order: .reverse) private var allRecords: [DataRecord]
    @ObservedObject private var catalog = MedicationCatalog.shared

    let selectedChild: Child?
    @Binding var selectedChildIdString: String
    @Binding var recordRequest: RecordRequest?

    @State private var editingRecord: DataRecord? = nil
    @State private var recordPendingDelete: DataRecord? = nil
    @State private var isSelecting: Bool = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showBatchDeleteConfirm: Bool = false

    private var childRecords: [DataRecord] {
        guard let child = selectedChild else { return [] }
        return allRecords.filter { $0.childId == child.id }
    }

    private var feverEpisode: FeverEpisode? {
        FeverEpisodeDetector.currentEpisode(for: childRecords)
    }

    private var recentRecords: [RecordDisplayItem] {
        var items: [RecordDisplayItem] = []
        for record in childRecords.prefix(20) {
            if let temp = record.temperatures.first, let med = record.medications.first {
                items.append(.combined(record: record, reading: temp, usage: med))
            } else if let temp = record.temperatures.first {
                items.append(.temperature(record: record, reading: temp))
            } else if let med = record.medications.first {
                items.append(.medication(record: record, usage: med))
            }
        }
        return Array(items.sorted { $0.date > $1.date }.prefix(5))
    }

    private var todayMedCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return childRecords.filter { $0.timestamp >= startOfDay }.flatMap { $0.medications }.count
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let cal = Calendar.current
        let from = Date().addingTimeInterval(-interval)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: from, to: Date())
        let years  = comps.year   ?? 0
        let months = comps.month  ?? 0
        let days   = comps.day    ?? 0
        let hours  = comps.hour   ?? 0
        let mins   = comps.minute ?? 0
        let totalDays = Int(interval) / 86400
        if totalDays >= 365 {
            return months > 0 ? "\(years)年\(months)月" : "\(years)年"
        } else if totalDays >= 30 {
            return days > 0 ? "\(months)月\(days)天" : "\(months)月"
        } else if totalDays >= 1 {
            return hours > 0 ? "\(totalDays)天\(hours)h" : "\(totalDays)天"
        } else if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private var timeSinceLastMedString: String {
        guard let lastMedRecord = childRecords.first(where: { !$0.medications.isEmpty }) else { return "—" }
        return formatInterval(Date().timeIntervalSince(lastMedRecord.timestamp))
    }

    private var lastRecordTimeString: String {
        guard let last = childRecords.first(where: { !$0.temperatures.isEmpty }) else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: last.timestamp)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.periodic(from: Date(), by: 60)) { _ in
                    VStack(spacing: 12) {
                        feverStatusCard
                        quickRecordButtons
                        medicationSafetySection
                        recentRecordsList
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    childPicker
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    multiSelectBar
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            RecordView(mode: .edit(record: record))
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
                deleteBatch(from: recentRecords)
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: Child Picker

    @ViewBuilder
    private var childPicker: some View {
        if children.count > 1 {
            Picker("儿童", selection: $selectedChildIdString) {
                ForEach(children) { child in
                    Text(child.avatarEmoji + " " + child.name)
                        .tag(child.id.uuidString)
                }
            }
            .pickerStyle(.menu)
        } else if let child = selectedChild {
            Text(child.avatarEmoji + " " + child.name)
                .font(.headline)
        } else {
            Text("烧退了").font(.headline)
        }
    }

    // MARK: Fever Status Hero Card

    @ViewBuilder
    private var feverStatusCard: some View {
        let isFever = feverEpisode != nil

        ZStack(alignment: .topTrailing) {
            // Radial glow
            if isFever {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(0.25), .clear],
                            center: .center, startRadius: 0, endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .offset(x: 50, y: -50)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Eyebrow
                HStack(spacing: 6) {
                    if isFever {
                        PulsingDot()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Color.green.opacity(0.7))
                    }
                    Text(isFever
                         ? (selectedChild?.name ?? "宝宝") + " · 发烧中"
                         : (selectedChild?.name ?? "宝宝") + " · 状态正常")
                }
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.5))

                if let latestRecord = childRecords.first,
                   let latest = latestRecord.temperatures.first {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", latest.value))
                            .font(.system(size: 60, weight: .thin))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("°C")
                            .font(.title2)
                            .fontWeight(.light)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    // Change badge
                    let allReadings = childRecords.flatMap { $0.temperatures }
                    if isFever, allReadings.count >= 2 {
                        let diff = allReadings[0].value - allReadings[1].value
                        HStack(spacing: 4) {
                            Image(systemName: diff > 0.01 ? "arrow.up" : diff < -0.01 ? "arrow.down" : "minus")
                                .font(.caption2)
                            Text(String(format: "较上次 %+.1f°", diff))
                                .font(.caption)
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }

                    // Stats grid
                    if isFever, let episode = feverEpisode {
                        HStack(spacing: 0) {
                            statCell(value: episode.durationString, label: "本次发烧")
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 1)
                            statCell(value: timeSinceLastMedString, label: "距上次用药")
                            Rectangle()
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 1)
                            statCell(value: lastRecordTimeString, label: "最近记录")
                        }
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 4)
                    }
                } else {
                    Text("暂无体温记录")
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: isFever
                    ? [Color(red: 0.11, green: 0.11, blue: 0.12),
                       Color(red: 0.17, green: 0.12, blue: 0.12)]
                    : [Color(red: 0.10, green: 0.16, blue: 0.10),
                       Color(red: 0.11, green: 0.17, blue: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: Medication Safety Section

    @ViewBuilder
    private var medicationSafetySection: some View {
        if let child = selectedChild {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("用药情况")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if todayMedCount > 0 {
                        Text("今日 \(todayMedCount) 次")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider()

                let reminderMeds = catalog.all.filter { $0.hasReminder }
                ForEach(Array(reminderMeds.enumerated()), id: \.element.id) { index, def in
                    if index > 0 { Divider().padding(.leading, 64) }
                    medicationRow(definition: def, childId: child.id)
                }

                if let lastMainRecord = childRecords.first(where: { record in
                    record.medications.contains { $0.medicationNameRaw != "其他" }
                }), let lastMed = lastMainRecord.medications.first(where: { $0.medicationNameRaw != "其他" }) {
                    let interval = Date().timeIntervalSince(lastMainRecord.timestamp)
                    let sinceText = formatInterval(interval)

                    Divider()
                    Text({
                        let base = AttributedString("距上次服用\(lastMed.medicationNameRaw)已过 ")
                        var bold = AttributedString(sinceText)
                        bold.swiftUI.font = .system(size: 12, weight: .semibold)
                        return base + bold
                    }())
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func medicationRow(definition: MedicationDefinition, childId: UUID) -> some View {
        let avail = MedicationSafetyViewModel.availability(
            forMedicationName: definition.canonicalName, childId: childId, records: childRecords
        )
        let lastDoseTimestamp = childRecords
            .flatMap { record -> [Date] in
                record.medications
                    .filter { $0.medicationNameRaw == definition.canonicalName }
                    .map { _ in record.timestamp }
            }.max()

        HStack(spacing: 12) {
            catalog.iconView(for: definition.canonicalName, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(definition.canonicalName)
                    .font(.system(size: 14, weight: .semibold))
                if let ts = lastDoseTimestamp {
                    let interval = Date().timeIntervalSince(ts)
                    let timeStr = ts.formatted(date: .omitted, time: .shortened)
                    let elapsed = formatInterval(interval)
                    Text("\(timeStr) 服用 · 距今 \(elapsed)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("今日未服用")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(avail.displayText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(avail.isAvailable ? Color.green : Color.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(avail.isAvailable ? Color.green.opacity(0.1) : Color.blue.opacity(0.08))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Quick Record Buttons

    private var quickRecordButtons: some View {
        HStack(spacing: 10) {
            Button {
                if let child = selectedChild {
                    recordRequest = RecordRequest(child: child, tab: .temperature)
                }
            } label: {
                VStack(spacing: 6) {
                    Text("🌡")
                        .font(.title2)
                    Text("记录体温")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 14))

            Button {
                if let child = selectedChild {
                    recordRequest = RecordRequest(child: child, tab: .medication)
                }
            } label: {
                VStack(spacing: 6) {
                    Text("💊")
                        .font(.title2)
                    Text("记录用药")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Recent Records List

    @ViewBuilder
    private var recentRecordsList: some View {
        if !recentRecords.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("最近记录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isSelecting {
                        let allSelected = selectedIds.count == recentRecords.count
                        Button(allSelected ? "取消全选" : "全选") {
                            if allSelected {
                                selectedIds = []
                            } else {
                                selectedIds = Set(recentRecords.map(\.id))
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                ForEach(Array(recentRecords.enumerated()), id: \.element.id) { index, item in
                    recentRecordRow(item, isLast: index == recentRecords.count - 1)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func recentRecordRow(_ item: RecordDisplayItem, isLast: Bool) -> some View {
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
                    tempRowContent(reading: reading, timestamp: record.timestamp, useRelative: true)
                case .medication(_, let usage):
                    medRowContent(usage: usage, timestamp: record.timestamp, useRelative: true)
                case .combined(_, let reading, let usage):
                    combinedRowContent(reading: reading, usage: usage, timestamp: record.timestamp, useRelative: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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

    // MARK: Row Content Builders

    @ViewBuilder
    private func tempRowContent(reading: TemperatureReading, timestamp: Date, useRelative: Bool) -> some View {
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
            if useRelative {
                Text(timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        Spacer()
        Text(isFever ? (reading.value >= 39.0 ? "高烧" : "发烧") : "正常")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isFever ? Color.red : Color.green)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFever ? Color.red.opacity(0.08) : Color.green.opacity(0.1))
            )
    }

    @ViewBuilder
    private func medRowContent(usage: MedicationUsage, timestamp: Date, useRelative: Bool) -> some View {
        MedicationCatalog.shared.iconView(for: usage.medicationNameRaw)
        VStack(alignment: .leading, spacing: 2) {
            Text(usage.medicationNameRaw)
                .font(.system(size: 14, weight: .semibold))
            if useRelative {
                Text(timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        Spacer()
        Text("用药")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.blue)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.08))
            )
    }

    @ViewBuilder
    private func combinedRowContent(reading: TemperatureReading, usage: MedicationUsage, timestamp: Date, useRelative: Bool) -> some View {
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
                Text(isFever ? (reading.value >= 39.0 ? "高烧" : "发烧") : "正常")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isFever ? Color.red : Color.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 8).fill(isFever ? Color.red.opacity(0.08) : Color.green.opacity(0.1)))
            }
            HStack(spacing: 8) {
                MedicationCatalog.shared.iconView(for: usage.medicationNameRaw, size: 28)
                Text(usage.medicationNameRaw)
                    .font(.system(size: 13, weight: .medium))
            }
            if useRelative {
                Text(timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
            } else {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
            }
        }
    }

    // MARK: Multi-select Bar

    @ViewBuilder
    private var multiSelectBar: some View {
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
}
