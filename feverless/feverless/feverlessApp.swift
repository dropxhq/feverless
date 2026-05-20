//
//  feverlessApp.swift
//  feverless
//

import SwiftUI
import SwiftData

@main
struct feverlessApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Child.self,
            TemperatureRecord.self,
            MedicationRecord.self,
        ])

        guard let appGroupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.top.dropx.feverless") else {
            fatalError("App Group container not found. Check entitlements.")
        }
        let storeURL = appGroupURL.appendingPathComponent("feverless.store")

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // CloudKit 初始化失败（如未登录 iCloud、容器未配置），回退到本地存储
            let localConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                // 本地 store 也加载失败，说明 store 文件损坏或 schema 不兼容，删除后重建
                try? FileManager.default.removeItem(at: storeURL)
                do {
                    return try ModelContainer(for: schema, configurations: [localConfiguration])
                } catch {
                    fatalError("Could not create ModelContainer after recovery: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
