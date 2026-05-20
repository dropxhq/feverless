## Context

项目 `feverless`（Bundle ID: `top.dropx.feverless`）当前仅为 Xcode 模板骨架：单一 `Item` SwiftData 模型、空列表 UI。设计稿已完整定义「烧退了」iOS App 的交互与视觉规范。

基础设施已就绪：
- iOS 26 部署目标，Swift 5.0
- Widget Extension target `feverlessWidget`（Bundle ID: `top.dropx.feverless.feverlessWidget`）
- Entitlements 已配置：`iCloud.top.dropx.feverless`（CloudKit）、`group.top.dropx.feverless`（App Group）

## Goals / Non-Goals

**Goals:**
- 基于设计稿实现完整的儿童发烧记录功能
- 数据通过 CloudKit 在家庭成员间同步
- 桌面小组件实时展示发烧状态
- 体验流畅、单手可操作

**Non-Goals:**
- Android / Web 版本
- 医疗诊断功能（仅记录与提醒）
- 推送通知（本期不做）
- Apple Watch 版本

## Decisions

### D1：数据层 — SwiftData + CloudKit `.automatic`

使用 `ModelConfiguration(cloudKitDatabase: .automatic)` 开启 iCloud 同步。

**理由**：Apple iOS 17+ 主推方案，与 SwiftData `@Model` 无缝集成，无需手写 CloudKit 代码。冲突策略为 last-write-wins，对体温记录场景可接受。

**替代方案**：`NSPersistentCloudKitContainer`（CoreData）— 工作量更大，且本项目已选择 SwiftData。

**约束**：所有 `@Model` 属性需有默认值或声明为可选，以满足 CloudKit schema 要求。

### D2：Widget 数据共享 — App Group SwiftData 容器

Widget 通过相同 App Group 路径读取 SwiftData 存储，主 App 负责写入与 CloudKit 同步，Widget 只读。

```
主 App                    Widget
  │                         │
  ▼                         ▼
ModelContainer          ModelContainer
(cloudKitDatabase:      (isStoredInMemoryOnly: false,
 .automatic,             url: appGroupURL)  ← 只读
 url: appGroupURL)
```

**理由**：避免 Widget 直接写入引发并发冲突；Widget 刷新频率低，只读足够。

### D3：图表 — Swift Charts（原生）

使用 `Charts` 框架绘制体温折线图，用 `RuleMark` 标注用药时间。

**理由**：iOS 16+ 原生支持，与 SwiftUI 集成最佳，无第三方依赖。

### D4：温度输入 — 原生 `Picker(.wheel)` 组合

整数部分（35–42）和小数部分（0、1、…、9）各用一个 `.wheel` Picker，组合展示。

**理由**：系统原生，无需自定义手势；精度 0.1°C 满足需求；可访问性由系统保障。

### D5：文件结构

```
feverless/feverless/
├── Models/
│   ├── Child.swift
│   ├── TemperatureRecord.swift
│   └── MedicationRecord.swift
├── Views/
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Record/
│   │   └── RecordView.swift
│   ├── Chart/
│   │   └── ChartView.swift
│   └── Profile/
│       └── ProfileView.swift
├── ViewModels/
│   └── MedicationSafetyViewModel.swift
├── Utilities/
│   └── FeverEpisodeDetector.swift
├── ContentView.swift   (TabView 入口)
└── feverlessApp.swift  (ModelContainer 配置)

feverless/feverlessWidget/
├── FeverWidgetProvider.swift
├── FeverWidgetView.swift
├── feverlessWidgetBundle.swift
└── AppIntent.swift
```

### D6：发烧阈值标准

| 测量方式 | 发烧阈值 |
|--------|---------|
| 腋下    | ≥ 37.5°C |
| 耳温    | ≥ 38.0°C |
| 肛温    | ≥ 38.0°C |
| 口腔    | ≥ 38.0°C |
| 额温    | ≥ 37.5°C（偏差修正） |

### D7：用药安全间隔

| 药物 | 最短间隔 | 每日上限 |
|-----|--------|--------|
| 布洛芬（Ibuprofen） | 6 小时 | 4 次 |
| 对乙酰氨基酚（Acetaminophen） | 4 小时 | 5 次 |

两药可交替，但同一药物不得低于上述间隔。

## Risks / Trade-offs

- **CloudKit 首次同步延迟** → 本地数据立即可用，后台异步同步，UI 无需等待
- **SwiftData CloudKit 属性限制**（不支持 `Unique` 约束在 CloudKit 模式下） → 使用 UUID + 逻辑去重
- **Widget 数据实时性** → Widget 最快刷新约 15 分钟；用户录入后调用 `WidgetCenter.shared.reloadAllTimelines()` 强制刷新
- **iOS 26 beta 稳定性** → 尽量使用稳定 API，避免 beta-only 特性

## Migration Plan

1. 删除 `Item.swift` 和现有 `ContentView` 实现
2. 建立新数据模型，注册到 `ModelContainer`
3. 更新 `feverlessApp.swift` 启用 App Group 路径 + CloudKit
4. 实现各 View 层
5. 实现 Widget
6. 首次运行自动建立 CloudKit schema（无需手动迁移）

## Open Questions

- 多儿童切换：首页顶部下拉还是 Tab 我的页中切换？（当前设计稿仅展示单儿童，建议首页顶部 Picker）
- 发烧结束判定：连续 24h 正常体温自动结束，还是需要用户手动确认？（建议自动 + 可手动覆盖）
