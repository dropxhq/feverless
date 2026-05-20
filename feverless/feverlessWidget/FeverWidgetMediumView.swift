//
//  FeverWidgetMediumView.swift
//  feverlessWidget
//

import SwiftUI
import WidgetKit

struct FeverWidgetMediumView: View {
    let entry: FeverWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: status card (same as small)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(entry.childEmoji).font(.caption)
                    Text(entry.childName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let temp = entry.latestTemperature {
                    Text(String(format: "%.1f°C", temp))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(entry.isFever ? .red : .primary)
                } else {
                    Text("暂无记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.isFever ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(entry.isFever ? "发烧中" : "正常")
                        .font(.caption2)
                        .foregroundStyle(entry.isFever ? .red : .green)
                }

                if let dur = entry.feverDurationString {
                    Text(dur).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .leading)

            Divider()
                .padding(.vertical, 12)

            // Right: medication status + deep link buttons
            VStack(alignment: .leading, spacing: 8) {
                medRow(emoji: "🟡", name: "布洛芬", status: entry.ibuprofenStatus)
                medRow(emoji: "🔵", name: "对乙酰氨基酚", status: entry.acetaminophenStatus)

                Spacer()

                HStack(spacing: 8) {
                    Link(destination: URL(string: "feverless://record?type=temperature")!) {
                        Text("记体温")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }

                    Link(destination: URL(string: "feverless://record?type=medication")!) {
                        Text("记用药")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            if entry.isFever { Color.red.opacity(0.06) }
        }
    }

    @ViewBuilder
    private func medRow(emoji: String, name: String, status: MedStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(emoji + " " + name)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(status.displayText)
                .font(.caption)
                .foregroundStyle(status.isAvailable ? Color.green : Color.orange)
                .fontWeight(.medium)
        }
    }
}
