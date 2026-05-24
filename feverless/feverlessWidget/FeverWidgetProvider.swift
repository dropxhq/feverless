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
            let schema = Schema([Child.self, DataRecord.self, TemperatureReading.self, MedicationUsage.self])
            let config = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            // Load position catalog from UserDefaults (shared App Group)
            // Note: widget uses TemperatureReading.isFever() with default threshold

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

            let recordDescriptor = FetchDescriptor<DataRecord>(
                predicate: #Predicate { $0.childId == childId && $0.timestamp >= cutoff },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            let records = (try? context.fetch(recordDescriptor)) ?? []

            let latestReading = records.first?.temperatures.first
            let isFever = latestReading.map { $0.isFever() } ?? false
            let feverDuration = feverDurationString(from: records)

            return FeverWidgetEntry(
                date: Date(),
                childName: child.name,
                childEmoji: child.avatarEmoji,
                latestTemperature: latestReading?.value,
                isFever: isFever,
                feverDurationString: feverDuration,
                ibuprofenStatus: medStatus(forName: "布洛芬", records: records),
                acetaminophenStatus: medStatus(forName: "对乙酰氨基酚", records: records)
            )
        } catch {
            return .noData
        }
    }

    // MARK: Inline Logic

    private func feverDurationString(from records: [DataRecord]) -> String? {
        let feverTimestamps = records.compactMap { record -> Date? in
            guard record.temperatures.contains(where: { $0.isFever() }) else { return nil }
            return record.timestamp
        }.sorted()
        guard let first = feverTimestamps.first, let last = feverTimestamps.last else { return nil }
        guard Date().timeIntervalSince(last) < 24 * 3600 else { return nil }
        let total = Int(Date().timeIntervalSince(first))
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func medStatus(forName name: String, records: [DataRecord]) -> MedStatus {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let timestamps = records.flatMap { record -> [Date] in
            record.medications.filter { $0.medicationNameRaw == name }.map { _ in record.timestamp }
        }
        let todayCount = timestamps.filter { $0 >= startOfDay }.count

        // Hardcoded intervals for common medications (widget cannot access MedicationCatalog)
        let (maxDoses, minIntervalHours): (Int, Double) = {
            switch name {
            case "布洛芬": return (4, 6)
            case "对乙酰氨基酚": return (5, 4)
            default: return (Int.max, 0)
            }
        }()

        if maxDoses != Int.max && todayCount >= maxDoses {
            return MedStatus(displayText: "今日已达上限", isAvailable: false)
        }
        if let lastDose = timestamps.max() {
            let elapsed = now.timeIntervalSince(lastDose)
            let minInterval = minIntervalHours * 3600
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
