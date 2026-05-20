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
    /// Returns the current availability for a given medication type for a specific child.
    /// - Parameters:
    ///   - type: The medication type to check.
    ///   - childId: The child's UUID.
    ///   - records: All MedicationRecord objects (unfiltered).
    static func availability(
        for type: MedicationType,
        childId: UUID,
        records: [MedicationRecord]
    ) -> MedicationAvailability {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let childRecords = records.filter { $0.childId == childId && $0.type == type }

        // Check daily dose limit
        let todayCount = childRecords.filter { $0.timestamp >= startOfDay }.count
        if type.maxDailyDoses != Int.max && todayCount >= type.maxDailyDoses {
            return .dailyLimitReached
        }

        // Check minimum interval since last dose
        if let lastDose = childRecords.map({ $0.timestamp }).max() {
            let elapsed = now.timeIntervalSince(lastDose)
            let minInterval = type.minimumIntervalHours * 3600
            if elapsed < minInterval {
                return .cooldown(remaining: minInterval - elapsed)
            }
        }

        return .available
    }
}
