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

    private var todayMedCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return childMedRecords.filter { $0.timestamp >= startOfDay }.count
    }

    private var timeSinceLastMedString: String {
        guard let lastMed = childMedRecords.first else { return "—" }
        let interval = Date().timeIntervalSince(lastMed.timestamp)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var lastRecordTimeString: String {
        guard let last = childTempRecords.first else { return "—" }
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

                if let latest = childTempRecords.first {
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
                    if isFever, childTempRecords.count >= 2 {
                        let diff = latest.value - childTempRecords[1].value
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

                medicationRow(type: .ibuprofen, childId: child.id)
                Divider().padding(.leading, 64)
                medicationRow(type: .acetaminophen, childId: child.id)

                if let lastMainMed = childMedRecords.filter({ $0.type != .other }).first {
                    let interval = Date().timeIntervalSince(lastMainMed.timestamp)
                    let hours = Int(interval) / 3600
                    let minutes = (Int(interval) % 3600) / 60
                    let sinceText = hours > 0 ? "\(hours) 小时 \(minutes) 分" : "\(minutes) 分"

                    Divider()
                    Text({
                        var base = AttributedString("距上次服用\(lastMainMed.type.displayName)已过 ")
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
    private func medicationRow(type: MedicationType, childId: UUID) -> some View {
        let avail = MedicationSafetyViewModel.availability(
            for: type, childId: childId, records: childMedRecords
        )
        let lastDose = childMedRecords.filter { $0.type == type }.first

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(medIconBackground(for: type))
                .frame(width: 36, height: 36)
                .overlay(Text(type.emoji).font(.body))

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 14, weight: .semibold))
                if let lastDose {
                    let interval = Date().timeIntervalSince(lastDose.timestamp)
                    let h = Int(interval) / 3600
                    let m = (Int(interval) % 3600) / 60
                    let timeStr = lastDose.timestamp.formatted(date: .omitted, time: .shortened)
                    let elapsed = h > 0 ? "\(h)h \(m)m" : "\(m)m"
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

    private func medIconBackground(for type: MedicationType) -> Color {
        switch type {
        case .ibuprofen:     return Color.yellow.opacity(0.15)
        case .acetaminophen: return Color.blue.opacity(0.1)
        case .other:         return Color.gray.opacity(0.12)
        }
    }

    // MARK: Quick Record Buttons

    private var quickRecordButtons: some View {
        HStack(spacing: 10) {
            Button {
                recordInitialTab = .temperature
                showRecordView = true
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
                recordInitialTab = .medication
                showRecordView = true
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
                Text("最近记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                ForEach(Array(recentRecords.enumerated()), id: \.offset) { index, item in
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
                                }
                                Text(r.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(r.isFever ? (r.value >= 39.0 ? "高烧" : "发烧") : "正常")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(r.isFever ? Color.red : Color.green)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(r.isFever ? Color.red.opacity(0.08) : Color.green.opacity(0.1))
                                )

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
                                Text(r.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if index < recentRecords.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
