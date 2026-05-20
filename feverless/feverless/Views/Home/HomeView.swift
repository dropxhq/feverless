//
//  HomeView.swift
//  feverless
//

import SwiftUI
import SwiftData

// MARK: - Shared record union type (used by HomeView and ChartView)

enum AnyRecentRecord {
    case temperature(TemperatureRecord)
    case medication(MedicationRecord)

    var date: Date {
        switch self {
        case .temperature(let r): return r.timestamp
        case .medication(let r):  return r.timestamp
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \TemperatureRecord.timestamp, order: .reverse) private var allTempRecords: [TemperatureRecord]
    @Query(sort: \MedicationRecord.timestamp, order: .reverse) private var allMedRecords: [MedicationRecord]

    let selectedChild: Child?
    @Binding var selectedChildIdString: String
    @Binding var showRecordView: Bool
    @Binding var recordInitialTab: RecordTab

    private var childTempRecords: [TemperatureRecord] {
        guard let child = selectedChild else { return [] }
        return allTempRecords.filter { $0.childId == child.id }
    }

    private var childMedRecords: [MedicationRecord] {
        guard let child = selectedChild else { return [] }
        return allMedRecords.filter { $0.childId == child.id }
    }

    private var feverEpisode: FeverEpisode? {
        FeverEpisodeDetector.currentEpisode(for: childTempRecords)
    }

    private var recentRecords: [AnyRecentRecord] {
        var items: [AnyRecentRecord] = []
        items += childTempRecords.prefix(5).map { .temperature($0) }
        items += childMedRecords.prefix(5).map  { .medication($0) }
        return Array(items.sorted { $0.date > $1.date }.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    feverStatusCard
                    TimelineView(.periodic(from: Date(), by: 60)) { _ in
                        medicationSafetySection
                    }
                    quickRecordButtons
                    recentRecordsList
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    childPicker
                }
            }
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

    // MARK: Fever Status Card

    @ViewBuilder
    private var feverStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if feverEpisode != nil {
                    Label("发烧中", systemImage: "thermometer.high")
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                } else {
                    Label("状态正常", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }
                Spacer()
                if let episode = feverEpisode {
                    Text(episode.durationString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let latest = childTempRecords.first {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", latest.value))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(latest.isFever ? .red : .primary)
                    Text("°C")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(latest.method.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(latest.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if childTempRecords.count >= 2 {
                    let prev = childTempRecords[1].value
                    let diff = latest.value - prev
                    HStack(spacing: 4) {
                        Image(systemName: diff > 0.01 ? "arrow.up" : diff < -0.01 ? "arrow.down" : "minus")
                            .font(.caption2)
                        Text(String(format: "%.1f°C 较上次", abs(diff)))
                            .font(.caption)
                    }
                    .foregroundStyle(diff > 0.01 ? Color.red : diff < -0.01 ? Color.blue : Color.secondary)
                }
            } else {
                Text("暂无体温记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Medication Safety

    @ViewBuilder
    private var medicationSafetySection: some View {
        if let child = selectedChild {
            VStack(alignment: .leading, spacing: 8) {
                Text("用药状态")
                    .font(.headline)
                HStack(spacing: 12) {
                    ForEach([MedicationType.ibuprofen, .acetaminophen], id: \.self) { medType in
                        medicationCard(type: medType, childId: child.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func medicationCard(type: MedicationType, childId: UUID) -> some View {
        let avail = MedicationSafetyViewModel.availability(
            for: type, childId: childId, records: childMedRecords
        )
        VStack(alignment: .leading, spacing: 6) {
            Text(type.emoji + " " + type.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(avail.displayText)
                .font(.caption)
                .foregroundStyle(avail.isAvailable ? Color.green : avail.statusColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Quick Record Buttons

    private var quickRecordButtons: some View {
        HStack(spacing: 12) {
            Button {
                recordInitialTab = .temperature
                showRecordView = true
            } label: {
                Label("记录体温", systemImage: "thermometer.medium")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button {
                recordInitialTab = .medication
                showRecordView = true
            } label: {
                Label("记录用药", systemImage: "pill.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }

    // MARK: Recent Records List

    @ViewBuilder
    private var recentRecordsList: some View {
        if !recentRecords.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("最近记录")
                    .font(.headline)
                    .padding(.bottom, 6)

                ForEach(Array(recentRecords.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        switch item {
                        case .temperature(let r):
                            Image(systemName: "thermometer.medium")
                                .foregroundStyle(.orange)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f°C", r.value))
                                        .font(.subheadline)
                                    Text("· " + r.method.displayName)
                                        .font(.caption)
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
                            }
                        case .medication(let r):
                            Image(systemName: "pill.fill")
                                .foregroundStyle(r.type.color)
                                .frame(width: 22)
                            Text(r.type.displayName)
                                .font(.subheadline)
                        }
                        Spacer()
                        Text(item.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    if index < recentRecords.count - 1 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
