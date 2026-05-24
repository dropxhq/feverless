//
//  RecordView.swift
//  feverless
//

import SwiftUI
import SwiftData
import WidgetKit

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DataRecord.timestamp, order: .reverse) private var allRecords: [DataRecord]
    @ObservedObject private var catalog = MedicationCatalog.shared
    @ObservedObject private var positionCatalog = TemperaturePositionCatalog.shared

    let child: Child
    let initialTab: RecordTab

    @State private var selectedTab: RecordTab
    @State private var tempInteger: Int = 37
    @State private var tempDecimal: Int = 5
    @State private var selectedPositionName: String = ""
    @State private var concurrentMedName: String? = nil
    @State private var selectedMedName: String = "布洛芬"
    @State private var recordTime: Date = Date()
    @State private var notes: String = ""
    @State private var isPressing: Bool = false
    @State private var pressStepCount: Int = 0

    init(child: Child, initialTab: RecordTab) {
        self.child = child
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    private var currentTemp: Double {
        Double(tempInteger) + Double(tempDecimal) / 10.0
    }

    private var tempRingProgress: Double {
        let minTemp = 35.0, maxTemp = 42.9
        return max(0, min(1, (currentTemp - minTemp) / (maxTemp - minTemp)))
    }

    private var childRecords: [DataRecord] {
        allRecords.filter { $0.childId == child.id }
    }

    private var selectedPosition: TemperaturePositionDefinition? {
        positionCatalog.find(selectedPositionName) ?? positionCatalog.all.first
    }

    private var isTempFever: Bool {
        let threshold = selectedPosition?.feverThreshold ?? 37.5
        return currentTemp >= threshold
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("记录类型", selection: $selectedTab) {
                    Text("体温").tag(RecordTab.temperature)
                    Text("用药").tag(RecordTab.medication)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    if selectedTab == .temperature {
                        temperatureTab
                    } else {
                        medicationTab
                    }
                }
            }
            .navigationTitle("记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if selectedPositionName.isEmpty {
                    selectedPositionName = positionCatalog.all.first?.canonicalName ?? "腋下"
                }
            }
        }
    }

    // MARK: Temperature Tab

    @ViewBuilder
    private var temperatureTab: some View {
        VStack(spacing: 20) {
            // Temperature ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: tempRingProgress)
                    .stroke(
                        isTempFever ? Color.red : Color.orange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        isPressing && pressStepCount >= 8
                            ? .interactiveSpring(duration: 0.1)
                            : .spring(duration: 0.3),
                        value: tempRingProgress
                    )
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", currentTemp))
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(isTempFever ? Color.red : Color.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("°C")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("点击 ±0.1 微调")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 8)

            // Stepper
            HStack(spacing: 20) {
                Text("−")
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(currentTemp <= 35.0 ? 0.08 : 0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(currentTemp <= 35.0 ? Color.secondary : Color.blue)
                    .opacity(currentTemp <= 35.0 ? 0.5 : 1.0)
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressing {
                                    isPressing = true
                                    startRepeating(delta: -0.1)
                                }
                            }
                            .onEnded { _ in stopRepeating() }
                    )

                Text("0.1°C 微调")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("+")
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(currentTemp >= 42.9 ? 0.08 : 0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(currentTemp >= 42.9 ? Color.secondary : Color.blue)
                    .opacity(currentTemp >= 42.9 ? 0.5 : 1.0)
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressing {
                                    isPressing = true
                                    startRepeating(delta: 0.1)
                                }
                            }
                            .onEnded { _ in stopRepeating() }
                    )
            }

            Divider().padding(.horizontal)

            // Measurement method
            VStack(alignment: .leading, spacing: 8) {
                Text("测量方式")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(positionCatalog.all, id: \.canonicalName) { pos in
                            Button(pos.canonicalName) {
                                selectedPositionName = pos.canonicalName
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedPositionName == pos.canonicalName ? Color.blue : Color.primary.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedPositionName == pos.canonicalName ? Color.blue.opacity(0.08) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(
                                                selectedPositionName == pos.canonicalName ? Color.blue.opacity(0.3) : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Concurrent medication
            VStack(alignment: .leading, spacing: 8) {
                Text("同时记录用药")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                concurrentMedPicker
            }

            timeSection
            notesSection

            // Save button
            Button("保存记录") { save() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var concurrentMedPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                medChip(label: "无", isSelected: concurrentMedName == nil) { concurrentMedName = nil }
                ForEach(catalog.all) { def in
                    medChip(
                        label: catalog.emoji(for: def.canonicalName) + " " + def.canonicalName,
                        isSelected: concurrentMedName == def.canonicalName
                    ) { concurrentMedName = def.canonicalName }
                }
            }
            .padding(.horizontal)
        }
    }

    private func medChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? Color.blue : Color.primary.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
                    )
            )
            .buttonStyle(.plain)
    }

    // MARK: Medication Tab

    @ViewBuilder
    private var medicationTab: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("药物类型")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(catalog.all) { def in
                    medicationTypeRow(def)
                }
            }

            timeSection
            notesSection

            Button("保存记录") { save() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 4)
        }
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func medicationTypeRow(_ def: MedicationDefinition) -> some View {
        let avail = MedicationSafetyViewModel.availability(
            forMedicationName: def.canonicalName, childId: child.id, records: childRecords
        )
        VStack(alignment: .leading, spacing: 4) {
            Button {
                selectedMedName = def.canonicalName
            } label: {
                HStack {
                    Text(catalog.emoji(for: def.canonicalName) + " " + def.canonicalName)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    if def.hasReminder {
                        Text(avail.displayText)
                            .font(.caption)
                            .foregroundStyle(avail.isAvailable ? Color.green : avail.statusColor)
                    }
                    if selectedMedName == def.canonicalName {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedMedName == def.canonicalName
                              ? Color.blue.opacity(0.1)
                              : Color.gray.opacity(0.08))
                )
            }
            .foregroundStyle(.primary)
            .padding(.horizontal)

            if def.hasReminder, case .cooldown = avail, selectedMedName == def.canonicalName {
                Label("仍在冷却期，请谨慎服用", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: Shared Sections

    @ViewBuilder
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("记录时间")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            DatePicker(
                "记录时间",
                selection: $recordTime,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.7))
            .scaleEffect(0.8, anchor: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("可选备注…", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
        }
        .padding(.horizontal)
    }

    // MARK: Actions

    private func adjustTemp(by delta: Double) {
        let raw = currentTemp + delta
        let rounded = (raw * 10).rounded() / 10
        let clamped = max(35.0, min(42.9, rounded))
        if clamped <= 35.0 || clamped >= 42.9 {
            isPressing = false
        }
        tempInteger = Int(clamped)
        tempDecimal = Int(round((clamped - Double(Int(clamped))) * 10))
    }

    private func startRepeating(delta: Double) {
        adjustTemp(by: delta)
        pressStepCount += 1
        guard isPressing else { return }
        let interval: Double
        if pressStepCount < 3 {
            interval = 0.35
        } else if pressStepCount < 8 {
            interval = 0.15
        } else {
            interval = 0.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            guard isPressing else { return }
            startRepeating(delta: delta)
        }
    }

    private func stopRepeating() {
        isPressing = false
        pressStepCount = 0
    }

    private func save() {
        let positionName = selectedPosition?.canonicalName ?? (positionCatalog.all.first?.canonicalName ?? "腋下")

        switch selectedTab {
        case .temperature:
            let reading = TemperatureReading(positionRaw: positionName, value: currentTemp)
            var medications: [MedicationUsage] = []
            if let medName = concurrentMedName {
                medications.append(MedicationUsage(medicationNameRaw: medName))
            }
            let record = DataRecord(
                childId: child.id,
                timestamp: recordTime,
                notes: notes,
                temperatures: [reading],
                medications: medications
            )
            modelContext.insert(record)

        case .medication:
            let usage = MedicationUsage(medicationNameRaw: selectedMedName)
            let record = DataRecord(
                childId: child.id,
                timestamp: recordTime,
                notes: notes,
                temperatures: [],
                medications: [usage]
            )
            modelContext.insert(record)
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
