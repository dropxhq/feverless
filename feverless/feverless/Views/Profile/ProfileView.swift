//
//  ProfileView.swift
//  feverless

import SwiftUI
import SwiftData

// MARK: - ProfileView

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]
    @Query(sort: \DataRecord.timestamp, order: .reverse) private var allRecords: [DataRecord]

    @Binding var selectedChildIdString: String
    @State private var showAddChild = false
    @State private var childToEdit: Child?

    private var selectedChild: Child? {
        guard let id = UUID(uuidString: selectedChildIdString) else { return nil }
        return children.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            List {
                // Children list
                ForEach(children) { child in
                    childRow(child)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteChild(child)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                childToEdit = child
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }

                // 7.4 Medication management section
                NavigationLink {
                    MedicationCatalogView()
                } label: {
                    Label("药品管理", systemImage: "pills.circle")
                }

                NavigationLink {
                    TemperaturePositionCatalogView(isSheet: false)
                } label: {
                    Label("体温位置管理", systemImage: "thermometer.medium")
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddChild = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddChild) {
                AddChildView(onSave: nil)
            }
            .sheet(item: $childToEdit) { child in
                EditChildView(child: child)
            }
        }
    }

    // MARK: - 5.1 Card-style child row

    @ViewBuilder
    private func childRow(_ child: Child) -> some View {
        HStack(spacing: 12) {
            Text(child.avatarEmoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.headline)
                Text(latestTempSubtitle(for: child))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selectedChildIdString == child.id.uuidString {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedChildIdString = child.id.uuidString
        }
    }

    // MARK: - Latest temp helpers

    private func latestTempSubtitle(for child: Child) -> String {
        guard let record = allRecords.first(where: { $0.childId == child.id }),
              let reading = record.temperatures.first else {
            return "暂无体温记录"
        }
        return "最近体温: \(String(format: "%.1f", reading.value))°C · \(relativeTimeString(record.timestamp))"
    }

    private func relativeTimeString(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        if cal.isDateInToday(date) {
            return "今天 \(timeFmt.string(from: date))"
        } else if cal.isDateInYesterday(date) {
            return "昨天 \(timeFmt.string(from: date))"
        } else {
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "M月d日 HH:mm"
            return dateFmt.string(from: date)
        }
    }

    // MARK: - Import flow

    // MARK: - Delete child

    private func deleteChild(_ child: Child) {
        let childId = child.id

        let recordDescriptor = FetchDescriptor<DataRecord>(
            predicate: #Predicate { $0.childId == childId }
        )

        if let records = try? modelContext.fetch(recordDescriptor) {
            records.forEach { modelContext.delete($0) }
        }

        if selectedChildIdString == child.id.uuidString {
            selectedChildIdString = ""
        }

        modelContext.delete(child)
        try? modelContext.save()
    }
}

// MARK: - AddChildView

private let childEmojiOptions = ["🧒", "👦", "👧", "🧑", "🐣", "🌟", "🦊", "🐶", "🐱", "🐼"]

struct AddChildView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date()
    @State private var hasBirthDate: Bool = false
    @State private var avatarEmoji: String = "🧒"

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名（必填）", text: $name)
                    Toggle("设置出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker(
                            "出生日期",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section("头像") {
                    emojiPicker(selection: $avatarEmoji)
                }
            }
            .navigationTitle("添加儿童")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let child = Child(
            name: name.trimmingCharacters(in: .whitespaces),
            birthDate: hasBirthDate ? birthDate : nil,
            avatarEmoji: avatarEmoji
        )
        modelContext.insert(child)
        try? modelContext.save()
        onSave?()
        dismiss()
    }
}

// MARK: - EditChildView

struct EditChildView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let child: Child

    @State private var name: String
    @State private var birthDate: Date
    @State private var hasBirthDate: Bool
    @State private var avatarEmoji: String

    init(child: Child) {
        self.child = child
        _name         = State(initialValue: child.name)
        _birthDate    = State(initialValue: child.birthDate ?? Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date())
        _hasBirthDate = State(initialValue: child.birthDate != nil)
        _avatarEmoji  = State(initialValue: child.avatarEmoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名（必填）", text: $name)
                    Toggle("设置出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker(
                            "出生日期",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section("头像") {
                    emojiPicker(selection: $avatarEmoji)
                }
            }
            .navigationTitle("编辑儿童")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        child.name      = name.trimmingCharacters(in: .whitespaces)
        child.birthDate = hasBirthDate ? birthDate : nil
        child.avatarEmoji = avatarEmoji
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared Emoji Picker

@ViewBuilder
private func emojiPicker(selection: Binding<String>) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            ForEach(childEmojiOptions, id: \.self) { emoji in
                Button(emoji) {
                    selection.wrappedValue = emoji
                }
                .font(.title2)
                .padding(8)
                .background(
                    Circle().fill(selection.wrappedValue == emoji
                                  ? Color.blue.opacity(0.2)
                                  : Color.clear)
                )
            }
        }
    }
}
