//
//  MedicationSafetyViewModel.swift
//  feverless
//

import Foundation
import SwiftUI

enum MedicationAvailability {
    case available
    case cooldown(remaining: TimeInterval)
    case dailyLimitReached

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .available:
            return "✓ 现可用"
        case .cooldown(let remaining):
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m 后"
            } else {
                return "\(minutes)m 后"
            }
        case .dailyLimitReached:
            return "今日已达上限"
        }
    }

    var statusColor: Color {
        switch self {
        case .available:        return .green
        case .cooldown:         return .orange
        case .dailyLimitReached: return .red
        }
    }
}

struct MedicationSafetyViewModel {
    /// Returns the current availability for a given medication (by canonical name) for a specific child.
    /// - Parameters:
    ///   - name: The medication's canonical name (e.g. "布洛芬").
    ///   - catalog: The MedicationCatalog to look up safety parameters.
    ///   - childId: The child's UUID.
    ///   - records: All DataRecord objects (unfiltered).
    static func availability(
        forMedicationName name: String,
        catalog: MedicationCatalog = .shared,
        childId: UUID,
        records: [DataRecord]
    ) -> MedicationAvailability {
        // If no reminder configured, or medication not in catalog, always available
        guard let def = catalog.findByCanonicalName(name),
              def.hasReminder,
              let minIntervalHours = def.minIntervalHours else {
            return .available
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let timestamps = records
            .filter { $0.childId == childId }
            .flatMap { record -> [Date] in
                record.medications
                    .filter { $0.medicationNameRaw == name }
                    .map { _ in record.timestamp }
            }

        // Check daily dose limit
        if let maxDoses = def.maxDailyDoses {
            let todayCount = timestamps.filter { $0 >= startOfDay }.count
            if todayCount >= maxDoses {
                return .dailyLimitReached
            }
        }

        // Check minimum interval since last dose
        if let lastDose = timestamps.max() {
            let elapsed = now.timeIntervalSince(lastDose)
            let minInterval = minIntervalHours * 3600
            if elapsed < minInterval {
                return .cooldown(remaining: minInterval - elapsed)
            }
        }

        return .available
    }
}
