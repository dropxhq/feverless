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
    @State private var showDatePicker: Bool = false
    @State private var notes: String = ""

    init(child: Child, initialTab: RecordTab) {
        self.child = child
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    private var currentTemp: Double {
        Double(tempInteger) + Double(tempDecimal) / 10.0
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Temperature Tab

    @ViewBuilder
    private var temperatureTab: some View {
        VStack(spacing: 20) {
            // Large temperature preview
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", currentTemp))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(isTempFever ? .red : .primary)
                Text("°C")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Dual wheel pickers
            HStack(spacing: 0) {
                Picker("整数", selection: $tempInteger) {
                    ForEach(35...42, id: \.self) { i in
                        Text("\(i)").tag(i)
                    }
                }
#if os(iOS)
                .pickerStyle(.wheel)
#endif
                .frame(width: 80)

                Text(".")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                Picker("小数", selection: $tempDecimal) {
                    ForEach(0...9, id: \.self) { d in
                        Text("\(d)").tag(d)
                    }
                }
#if os(iOS)
                .pickerStyle(.wheel)
#endif
                .frame(width: 80)

                Text("°C")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .frame(height: 160)

            // Fine-adjust ±0.1°C buttons
            HStack(spacing: 32) {
                Button {
                    adjustTemp(by: -0.1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                .disabled(currentTemp <= 35.0)

                Button {
                    adjustTemp(by: 0.1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .disabled(currentTemp >= 42.9)
            }
            .foregroundStyle(.orange)

            // Measurement method chips
            VStack(alignment: .leading, spacing: 8) {
                Text("测量方式")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MeasurementMethod.allCases, id: \.self) { method in
                            Button(method.displayName) {
                                selectedMethod = method
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedMethod == method ? .orange : .gray)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .padding(.horizontal)

            // Concurrent medication option
            VStack(alignment: .leading, spacing: 8) {
                Text("同时记录用药")
                    .font(.headline)
                concurrentMedPicker
            }
            .padding(.horizontal)

            timeSection
            notesSection
        }
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var concurrentMedPicker: some View {
        Picker("用药", selection: $concurrentMed) {
            Text("无").tag(Optional<MedicationType>.none)
            Text(MedicationType.ibuprofen.displayName).tag(Optional(MedicationType.ibuprofen))
            Text(MedicationType.acetaminophen.displayName).tag(Optional(MedicationType.acetaminophen))
            Text(MedicationType.other.displayName).tag(Optional(MedicationType.other))
        }
        .pickerStyle(.segmented)
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
            HStack {
                Text("记录时间")
                    .font(.headline)
                Spacer()
                Button(showDatePicker ? "完成" : "修改") {
                    showDatePicker.toggle()
                }
                .font(.subheadline)
            }

            if showDatePicker {
                DatePicker(
                    "时间",
                    selection: $recordTime,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            } else {
                Text(recordTime.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
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
        tempInteger = Int(clamped)
        tempDecimal = Int(round((clamped - Double(Int(clamped))) * 10))
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
