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
    @Query(sort: \MedicationRecord.timestamp, order: .reverse) private var allMedRecords: [MedicationRecord]

    let child: Child
    let initialTab: RecordTab

    @State private var selectedTab: RecordTab
    @State private var tempInteger: Int = 37
    @State private var tempDecimal: Int = 5
    @State private var selectedMethod: MeasurementMethod = .axillary
    @State private var concurrentMed: MedicationType? = nil
    @State private var selectedMedType: MedicationType = .ibuprofen
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

    private var childMedRecords: [MedicationRecord] {
        allMedRecords.filter { $0.childId == child.id }
    }

    private var isTempFever: Bool {
        currentTemp >= selectedMethod.feverThreshold
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
                        ForEach(MeasurementMethod.allCases, id: \.self) { method in
                            Button(method.displayName) {
                                selectedMethod = method
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedMethod == method ? Color.blue : Color.primary.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedMethod == method ? Color.blue.opacity(0.08) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(
                                                selectedMethod == method ? Color.blue.opacity(0.3) : Color.clear,
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
                medChip(label: "无", isSelected: concurrentMed == nil)  { concurrentMed = nil }
                medChip(label: MedicationType.ibuprofen.emoji + " " + MedicationType.ibuprofen.displayName,
                        isSelected: concurrentMed == .ibuprofen)           { concurrentMed = .ibuprofen }
                medChip(label: MedicationType.acetaminophen.emoji + " " + MedicationType.acetaminophen.displayName,
                        isSelected: concurrentMed == .acetaminophen)       { concurrentMed = .acetaminophen }
                medChip(label: MedicationType.other.emoji + " " + MedicationType.other.displayName,
                        isSelected: concurrentMed == .other)               { concurrentMed = .other }
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
                    .font(.headline)
                    .padding(.horizontal)

                medicationTypeRow(.ibuprofen)
                medicationTypeRow(.acetaminophen)
                medicationTypeRow(.other)
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
    private func medicationTypeRow(_ med: MedicationType) -> some View {
        let avail = MedicationSafetyViewModel.availability(
            for: med, childId: child.id, records: childMedRecords
        )
        VStack(alignment: .leading, spacing: 4) {
            Button {
                selectedMedType = med
            } label: {
                HStack {
                    Text(med.emoji + " " + med.displayName)
                        .fontWeight(.medium)
                    Spacer()
                    Text(avail.displayText)
                        .font(.caption)
                        .foregroundStyle(avail.isAvailable ? Color.green : avail.statusColor)
                    if selectedMedType == med {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedMedType == med
                              ? Color.blue.opacity(0.1)
                              : Color.gray.opacity(0.08))
                )
            }
            .foregroundStyle(.primary)
            .padding(.horizontal)

            if case .cooldown = avail, selectedMedType == med {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.headline)
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
        switch selectedTab {
        case .temperature:
            let tempRecord = TemperatureRecord(
                childId: child.id,
                value: currentTemp,
                method: selectedMethod,
                timestamp: recordTime,
                notes: notes
            )
            modelContext.insert(tempRecord)

            if let med = concurrentMed {
                let medRecord = MedicationRecord(
                    childId: child.id,
                    type: med,
                    timestamp: recordTime,
                    concurrentTemperature: currentTemp,
                    notes: ""
                )
                modelContext.insert(medRecord)
            }

        case .medication:
            let medRecord = MedicationRecord(
                childId: child.id,
                type: selectedMedType,
                timestamp: recordTime,
                notes: notes
            )
            modelContext.insert(medRecord)
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
