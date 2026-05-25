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
    /// An episode is considered ended if the last fever reading is older than 24 hours.
    /// The episode start is determined by walking backwards: a gap > 12h between
    /// consecutive fever readings marks the boundary of the current episode.
    static func currentEpisode(for records: [DataRecord]) -> FeverEpisode? {
        let allReadings: [(isFever: Bool, timestamp: Date)] = records.flatMap { record in
            record.temperatures.map { reading in
                (reading.isFever(), record.timestamp)
            }
        }.sorted { $0.timestamp < $1.timestamp }

        let feverReadings = allReadings.filter { $0.isFever }

        guard let lastFever = feverReadings.last else { return nil }

        // Episode ends if the last fever record is older than 24 hours
        guard Date().timeIntervalSince(lastFever.timestamp) < 24 * 3600 else { return nil }

        // If a normal reading came in after the last fever reading, fever has subsided
        if let latestReading = allReadings.last, !latestReading.isFever,
           latestReading.timestamp > lastFever.timestamp {
            return nil
        }

        // Find the start of THIS episode: walk backwards until a gap > 12h
        var episodeStartIndex = 0
        for i in stride(from: feverReadings.count - 1, through: 1, by: -1) {
            let gap = feverReadings[i].timestamp.timeIntervalSince(feverReadings[i - 1].timestamp)
            if gap > 12 * 3600 {
                episodeStartIndex = i
                break
            }
        }

        return FeverEpisode(startDate: feverReadings[episodeStartIndex].timestamp, isOngoing: true)
    }
}
