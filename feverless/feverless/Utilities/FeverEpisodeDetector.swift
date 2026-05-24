//
//  FeverEpisodeDetector.swift
//  feverless
//

import Foundation

struct FeverEpisode {
    let startDate: Date
    let isOngoing: Bool

    var duration: TimeInterval {
        Date().timeIntervalSince(startDate)
    }

    var durationString: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct FeverEpisodeDetector {
    /// Returns the current (ongoing) fever episode for the given records,
    /// or nil if no active episode exists.
    static func currentEpisode(for records: [DataRecord]) -> FeverEpisode? {
        let feverReadings: [(value: Double, timestamp: Date)] = records.flatMap { record in
            record.temperatures.compactMap { reading in
                reading.isFever() ? (reading.value, record.timestamp) : nil
            }
        }.sorted { $0.timestamp < $1.timestamp }

        guard let lastFever = feverReadings.last else { return nil }

        // Episode ends if the last fever record is older than 24 hours
        let isOngoing = Date().timeIntervalSince(lastFever.timestamp) < 24 * 3600
        guard isOngoing, let firstFever = feverReadings.first else { return nil }

        return FeverEpisode(startDate: firstFever.timestamp, isOngoing: true)
    }
}
