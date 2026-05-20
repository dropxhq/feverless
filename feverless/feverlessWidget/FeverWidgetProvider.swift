//
//  FeverWidgetProvider.swift
//  feverlessWidget
//

import WidgetKit
import SwiftData
import Foundation

struct FeverWidgetProvider: TimelineProvider {

    private static let appGroupId = "group.top.dropx.feverless"

    // MARK: TimelineProvider

    func placeholder(in context: Context) -> FeverWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FeverWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(buildEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FeverWidgetEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every 15 minutes
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    // MARK: Data Fetching

    private func buildEntry() -> FeverWidgetEntry {
        guard
            let appGroupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)
        else { return .noData }

        let storeURL = appGroupURL.appendingPathComponent("feverless.store")

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return .noData
        }

        do {
            let schema = Schema([Child.self, TemperatureRecord.self, MedicationRecord.self])
            let config = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            // Determine selected child
            let selectedIdString = UserDefaults(suiteName: Self.appGroupId)?
                .string(forKey: "selectedChildIdString") ?? ""

            var childDescriptor = FetchDescriptor<Child>(sortBy: [SortDescriptor(\.createdAt)])
            childDescriptor.fetchLimit = 10
            let children = (try? context.fetch(childDescriptor)) ?? []

            let selectedChild: Child? = {
                if let id = UUID(uuidString: selectedIdString) {
                    return children.first(where: { $0.id == id })
                }
                return children.first
            }()

            guard let child = selectedChild else { return .noData }

            // Fetch last 48h of records
            let cutoff = Date().addingTimeInterval(-48 * 3600)
            let childId = child.id

            let tempDescriptor = FetchDescriptor<TemperatureRecord>(
                predicate: #Predicate { $0.childId == childId && $0.timestamp >= cutoff },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let medDescriptor = FetchDescriptor<MedicationRecord>(
                predicate: #Predicate { $0.childId == childId && $0.timestamp >= cutoff },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            let tempRecords = (try? context.fetch(tempDescriptor)) ?? []
            let medRecords  = (try? context.fetch(medDescriptor))  ?? []

            let latestTemp = tempRecords.first
            let isFever = latestTemp?.isFever ?? false
            let feverDuration = feverDurationString(from: tempRecords)

            return FeverWidgetEntry(
                date: Date(),
                childName: child.name,
                childEmoji: child.avatarEmoji,
                latestTemperature: latestTemp?.value,
                isFever: isFever,
                feverDurationString: feverDuration,
                ibuprofenStatus: medStatus(for: .ibuprofen, childId: childId, records: medRecords),
                acetaminophenStatus: medStatus(for: .acetaminophen, childId: childId, records: medRecords)
            )
        } catch {
            return .noData
        }
    }

    // MARK: Inline Logic

    private func feverDurationString(from records: [TemperatureRecord]) -> String? {
        let feverRecords = records.filter { $0.isFever }.sorted { $0.timestamp < $1.timestamp }
        guard let first = feverRecords.first, let last = feverRecords.last else { return nil }
        guard Date().timeIntervalSince(last.timestamp) < 24 * 3600 else { return nil }
        let total = Int(Date().timeIntervalSince(first.timestamp))
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func medStatus(for type: MedicationType, childId: UUID, records: [MedicationRecord]) -> MedStatus {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let relevant = records.filter { $0.type == type }
        let todayCount = relevant.filter { $0.timestamp >= startOfDay }.count

        if type.maxDailyDoses != Int.max && todayCount >= type.maxDailyDoses {
            return MedStatus(displayText: "今日已达上限", isAvailable: false)
        }
        if let lastDose = relevant.map({ $0.timestamp }).max() {
            let elapsed = now.timeIntervalSince(lastDose)
            let minInterval = type.minimumIntervalHours * 3600
            if elapsed < minInterval {
                let rem = Int(minInterval - elapsed)
                let h = rem / 3600
                let m = (rem % 3600) / 60
                let text = h > 0 ? "\(h)h \(m)m 后" : "\(m)m 后"
                return MedStatus(displayText: text, isAvailable: false)
            }
        }
        return MedStatus(displayText: "✓ 现可用", isAvailable: true)
    }
}
