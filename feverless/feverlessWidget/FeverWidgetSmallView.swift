//
//  FeverWidgetSmallView.swift
//  feverlessWidget
//

import SwiftUI
import WidgetKit

struct FeverWidgetSmallView: View {
    let entry: FeverWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Child name
            HStack(spacing: 4) {
                Text(entry.childEmoji)
                    .font(.caption)
                Text(entry.childName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Temperature
            if let temp = entry.latestTemperature {
                Text(String(format: "%.1f°C", temp))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isFever ? .red : .primary)
            } else {
                Text("暂无记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.isFever ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text(entry.isFever ? "发烧中" : "状态正常")
                    .font(.caption2)
                    .foregroundStyle(entry.isFever ? .red : .green)
            }

            // Fever duration
            if let dur = entry.feverDurationString {
                Text(dur)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            if entry.isFever { Color.red.opacity(0.08) }
        }
    }
}
