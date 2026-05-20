## Why

现有代码仅为 Xcode 模板骨架（`Item.swift` + 空列表），缺乏任何业务功能。设计稿 `fever_app_design.html` 已完成，定义了一款面向家长的儿童发烧记录 iOS App「烧退了」的完整交互，需要将其落地为可用的 SwiftUI 应用。

## What Changes

- 删除模板代码（`Item.swift`、`ContentView.swift` 现有实现）
- **新增**：完整数据模型（Child、TemperatureRecord、MedicationRecord）
- **新增**：首页（HomeView）——当前孩子发烧状态、用药安全倒计时、快捷记录入口
- **新增**：记录页（RecordView）——体温输入（原生 Picker 滚轮）、测量方式选择、同时记录用药
- **新增**：图表页（ChartView）——Swift Charts 体温折线 + 用药标记 + 记录明细列表
- **新增**：我的页面（ProfileView）——儿童档案管理
- **新增**：用药安全逻辑——布洛芬（≥6h 间隔）、对乙酰氨基酚（≥4h 间隔）倒计时与可用状态
- **新增**：发烧周期自动识别（开始/进行中/结束）
- **新增**：iCloud CloudKit 同步（`ModelConfiguration(cloudKitDatabase: .automatic)`）
- **新增**：桌面小组件（feverlessWidget）——小/中尺寸，展示当前体温、发烧时长、用药倒计时
- **新增**：主 App 与 Widget 通过 App Group 共享 SwiftData 存储

## Capabilities

### New Capabilities

- `data-models`: Child、TemperatureRecord、MedicationRecord SwiftData 模型及 CloudKit 同步配置
- `home-screen`: 首页状态卡片、用药安全提醒、最近记录列表
- `record-entry`: 体温 + 用药记录输入表单（Picker 滚轮、测量方式、用药类型）
- `fever-chart`: 体温趋势图表（Swift Charts）及记录明细
- `medication-safety`: 用药间隔计算、可用状态、倒计时业务逻辑
- `fever-episode`: 发烧周期自动检测与状态管理
- `home-widget`: WidgetKit 桌面小组件（小/中尺寸，App Group 数据共享）
- `profile-management`: 儿童档案 CRUD、当前孩子切换

### Modified Capabilities

（无已有 spec，无需变更）

## Impact

- **删除**：`feverless/feverless/Item.swift`（替换为新数据模型文件）
- **重写**：`feverless/feverless/ContentView.swift` → 改为 TabView 入口
- **重写**：`feverless/feverless/feverlessApp.swift` → 启用 CloudKit + App Group 容器
- **新增文件**：Models/、Views/、ViewModels/（或直接 Views 内联逻辑）目录结构
- **修改**：`feverless/feverlessWidget/feverlessWidget.swift` 等 Widget 模板文件
- **依赖**：SwiftData（iOS 17+）、Swift Charts（iOS 16+）、WidgetKit、CloudKit
- **Entitlements**：已配置 `iCloud.top.dropx.feverless` + `group.top.dropx.feverless`
