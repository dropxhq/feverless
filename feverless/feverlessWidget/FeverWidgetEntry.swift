//
//  FeverWidgetEntry.swift
//  feverlessWidget
//

import WidgetKit
import Foundation

struct MedStatus {
    let displayText: String
    let isAvailable: Bool
}

struct FeverWidgetEntry: TimelineEntry {
    let date: Date
    let childName: String
    let childEmoji: String
    let latestTemperature: Double?
    let isFever: Bool
    let feverDurationString: String?
    let ibuprofenStatus: MedStatus
    let acetaminophenStatus: MedStatus

    // MARK: Placeholder / empty states

    static let placeholder = FeverWidgetEntry(
        date: Date(),
        childName: "小明",
        childEmoji: "🧒",
        latestTemperature: 38.5,
        isFever: true,
        feverDurationString: "3h 20m",
        ibuprofenStatus: MedStatus(displayText: "1h 40m 后", isAvailable: false),
        acetaminophenStatus: MedStatus(displayText: "✓ 现可用", isAvailable: true)
    )

    static let noData = FeverWidgetEntry(
        date: Date(),
        childName: "烧退了",
        childEmoji: "🧒",
        latestTemperature: nil,
        isFever: false,
        feverDurationString: nil,
        ibuprofenStatus: MedStatus(displayText: "✓ 现可用", isAvailable: true),
        acetaminophenStatus: MedStatus(displayText: "✓ 现可用", isAvailable: true)
    )
}
