//
//  ContentView.swift
//  feverless
//

import SwiftUI
import SwiftData

// MARK: - Shared Tab Enum (used by HomeView and RecordView)

enum RecordTab {
    case temperature, medication
}

// MARK: - Record Request (atomic sheet trigger)

struct RecordRequest: Identifiable {
    let id = UUID()
    let child: Child
    let tab: RecordTab
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]

    // Persisted in App Group UserDefaults so the Widget can read the selected child
    @AppStorage("selectedChildIdString",
                store: UserDefaults(suiteName: "group.top.dropx.feverless"))
    private var selectedChildIdString: String = ""

    @State private var recordRequest: RecordRequest? = nil

    var selectedChild: Child? {
        if let id = UUID(uuidString: selectedChildIdString),
           let match = children.first(where: { $0.id == id }) {
            return match
        }
        return children.first
    }

    var body: some View {
        if children.isEmpty {
            // First launch: guide user to create their first child profile
            AddChildView(onSave: nil)
        } else {
            TabView {
                HomeView(
                    selectedChild:          selectedChild,
                    selectedChildIdString:  $selectedChildIdString,
                    recordRequest:          $recordRequest
                )
                .tabItem { Label("首页", systemImage: "house.fill") }

                ChartView(selectedChild: selectedChild)
                    .tabItem { Label("图表", systemImage: "chart.line.uptrend.xyaxis") }

                ProfileView(selectedChildIdString: $selectedChildIdString)
                    .tabItem { Label("我的", systemImage: "person.fill") }
            }
            // Sheet for RecordView — also opened via deep link
            .sheet(item: $recordRequest) { request in
                RecordView(mode: .create(child: request.child, initialTab: request.tab))
            }
            // Deep link: feverless://record?type=temperature | medication
            .onOpenURL { url in
                guard url.scheme == "feverless", url.host == "record" else { return }
                guard let child = selectedChild else { return }
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let type = queryItems?.first(where: { $0.name == "type" })?.value
                let tab: RecordTab = type == "medication" ? .medication : .temperature
                recordRequest = RecordRequest(child: child, tab: tab)
            }
        }
    }
}
