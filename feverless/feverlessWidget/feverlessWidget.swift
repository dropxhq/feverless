//
//  feverlessWidget.swift
//  feverlessWidget
//

import WidgetKit
import SwiftUI

// MARK: - Family-aware entry view

struct FeverWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FeverWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            FeverWidgetMediumView(entry: entry)
        default:
            FeverWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget configuration

struct FeverWidget: Widget {
    let kind: String = "FeverWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FeverWidgetProvider()) { entry in
            FeverWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("烧退了")
        .description("实时显示孩子的发烧状态和用药倒计时")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
