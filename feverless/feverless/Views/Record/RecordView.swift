//
//  RecordView.swift
//  feverless
//

import SwiftUI
import SwiftData
import WidgetKit

struct RecordView: View {

    // MARK: - Mode

    enum Mode {
        case create(child: Child, initialTab: RecordTab)
        case edit(record: DataRecord)
    }

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DataRecord.timestamp, order: .reverse) private var allRecords: [DataRecord]
    @ObservedObject private var catalog = MedicationCatalog.shared
    @ObservedObject private var positionCatalog = TemperaturePositionCatalog.shared

    // MARK: - Properties

    let mode: Mode

    @State private var includeTemp: Bool
    @State private var tempInteger: Int
    @State private var tempDecimal: Int
    @State private var selectedPositionName: String
    @State private var selectedMedName: String?
    @State private var recordTime: Date
    @State private var notes: String
    @State private var isPressing: Bool = false
    @State private var pressStepCount: Int = 0

    // MARK: - Init

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(_, let initialTab):
            _includeTemp = State(initialValue: initialTab == .temperature)
            _tempInteger = State(initialValue: 37)
            _tempDecimal = State(initialValue: 5)
            _selectedPositionName = State(initialValue: "")
            _selectedMedName = State(initialValue: initialTab == .medication ? MedicationCatalog.shared.all.first?.canonicalName : nil)
            _recordTime = State(initialValue: Date())
            _notes = State(initialValue: "")
        case .edit(let record):
            _includeTemp = State(initialValue: !record.temperatures.isEmpty)
            let temp = record.temperatures.first
            let rawValue = temp?.value ?? 37.5
            _tempInteger = State(initialValue: Int(rawValue))
            _tempDecimal = State(initialValue: Int(round((rawValue - Double(Int(rawValue))) * 10)))
            _selectedPositionName = State(initialValue: temp?.positionRaw ?? TemperaturePositionCatalog.shared.all.first?.canonicalName ?? "腋下")
            _selectedMedName = State(initialValue: record.medications.first?.medicationNameRaw)
            _recordTime = State(initialValue: record.timestamp)
            _notes = State(initialValue: record.notes)
        }
    }

    // MARK: - Computed

    private var childId: UUID {
        switch mode {
        case .create(let child, _): return child.id
        case .edit(let record): return record.childId
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "记录"
        case .edit: return "编辑记录"
        }
    }

    private var currentTemp: Double {
        Double(tempInteger) + Double(tempDecimal) / 10.0
    }

    private var tempRingProgress: Double {
        let minTemp = 35.0, maxTemp = 42.9
        return max(0, min(1, (currentTemp - minTemp) / (maxTemp - minTemp)))
    }

    private var selectedPosition: TemperaturePositionDefinition? {
        positionCatalog.find(selectedPositionName) ?? positionCatalog.all.first
    }

    private var isTempFever: Bool {
        let threshold = selectedPosition?.feverThreshold ?? 37.5
        return currentTemp >= threshold
    }

    private var childRecords: [DataRecord] {
        allRecords.filter { $0.childId == childId }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    temperatureSection
                    Divider().padding(.horizontal)
                    medicationSection
                    timeSection
                    notesSection
                    saveButton
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode({
                if case .edit = mode { return .inline }
                return .automatic
            }())
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

    // MARK: - Temperature Section

    @ViewBuilder
    private var temperatureSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("体温")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $includeTemp.animation(.easeInOut(duration: 0.2)))
                    .labelsHidden()
                    .scaleEffect(0.75, anchor: .trailing)
                    .frame(width: 42)
            }
            .padding(.horizontal)

            if includeTemp {
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

                HStack(spacing: 16) {
                    Text("−")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(currentTemp <= 35.0 ? 0.08 : 0.12), in: RoundedRectangle(cornerRadius: 11))
                        .foregroundStyle(currentTemp <= 35.0 ? Color.secondary : Color.blue)
                        .opacity(currentTemp <= 35.0 ? 0.5 : 1.0)
                        .contentShape(RoundedRectangle(cornerRadius: 11))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in if !isPressing { isPressing = true; startRepeating(delta: -0.1) } }
                                .onEnded { _ in stopRepeating() }
                        )
                    Text("0.1°C 微调")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("+")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(currentTemp >= 42.9 ? 0.08 : 0.12), in: RoundedRectangle(cornerRadius: 11))
                        .foregroundStyle(currentTemp >= 42.9 ? Color.secondary : Color.blue)
                        .opacity(currentTemp >= 42.9 ? 0.5 : 1.0)
                        .contentShape(RoundedRectangle(cornerRadius: 11))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in if !isPressing { isPressing = true; startRepeating(delta: 0.1) } }
                                .onEnded { _ in stopRepeating() }
                        )
                }

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
            }
        }
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: includeTemp)
    }

    // MARK: - Medication Section

    @ViewBuilder
    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用药")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    medChip(label: "无", isSelected: selectedMedName == nil) {
                        selectedMedName = nil
                    }
                    ForEach(catalog.all) { def in
                        medChip(
                            label: def.canonicalName,
                            medName: def.canonicalName,
                            isSelected: selectedMedName == def.canonicalName
                        ) {
                            selectedMedName = def.canonicalName
                        }
                    }
                }
                .padding(.horizontal)
            }

            if case .create = mode,
               let medName = selectedMedName,
               let def = catalog.all.first(where: { $0.canonicalName == medName }),
               def.hasReminder {
                let avail = MedicationSafetyViewModel.availability(
                    forMedicationName: medName, childId: childId, records: childRecords
                )
                if case .cooldown = avail {
                    Label("仍在冷却期，请谨慎服用", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedMedName)
    }

    // MARK: - Shared Components

    private func medChip(label: String, medName: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let name = medName {
                    Image(systemName: "pill.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(catalog.color(for: name))
                }
                Text(label)
            }
        }
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

    @ViewBuilder
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("记录时间")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Group {
                if case .create = mode {
                    DatePicker(
                        "记录时间",
                        selection: $recordTime,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } else {
                    DatePicker(
                        "记录时间",
                        selection: $recordTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
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

    @ViewBuilder
    private var saveButton: some View {
        let label: String = {
            if case .create = mode { return "保存记录" }
            return "保存"
        }()
        Button(label) { save() }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                (includeTemp || selectedMedName != nil) ? Color.blue : Color.gray,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 4)
            .disabled(!includeTemp && selectedMedName == nil)
    }

    // MARK: - Actions

    private func adjustTemp(by delta: Double) {
        let raw = currentTemp + delta
        let rounded = (raw * 10).rounded() / 10
        let clamped = max(35.0, min(42.9, rounded))
        if clamped <= 35.0 || clamped >= 42.9 { isPressing = false }
        tempInteger = Int(clamped)
        tempDecimal = Int(round((clamped - Double(Int(clamped))) * 10))
    }

    private func startRepeating(delta: Double) {
        adjustTemp(by: delta)
        pressStepCount += 1
        guard isPressing else { return }
        let interval: Double
        if pressStepCount < 3 { interval = 0.35 }
        else if pressStepCount < 8 { interval = 0.15 }
        else { interval = 0.08 }
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
        guard includeTemp || selectedMedName != nil else { return }
        switch mode {
        case .create(let child, _):
            let positionName = selectedPosition?.canonicalName ?? (positionCatalog.all.first?.canonicalName ?? "腋下")
            var readings: [TemperatureReading] = []
            if includeTemp {
                readings = [TemperatureReading(positionRaw: positionName, value: currentTemp)]
            }
            var medications: [MedicationUsage] = []
            if let medName = selectedMedName {
                medications = [MedicationUsage(medicationNameRaw: medName)]
            }
            let record = DataRecord(
                childId: child.id,
                timestamp: recordTime,
                notes: notes,
                temperatures: readings,
                medications: medications
            )
            modelContext.insert(record)

        case .edit(let record):
            record.timestamp = recordTime
            record.notes = notes
            if includeTemp {
                if let temp = record.temperatures.first {
                    temp.value = currentTemp
                    temp.positionRaw = selectedPositionName
                } else {
                    record.temperatures.append(TemperatureReading(positionRaw: selectedPositionName, value: currentTemp))
                }
            } else {
                for temp in record.temperatures { modelContext.delete(temp) }
                record.temperatures.removeAll()
            }
            if let medName = selectedMedName {
                if let med = record.medications.first {
                    med.medicationNameRaw = medName
                } else {
                    record.medications.append(MedicationUsage(medicationNameRaw: medName))
                }
            } else {
                for med in record.medications { modelContext.delete(med) }
                record.medications.removeAll()
            }
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
