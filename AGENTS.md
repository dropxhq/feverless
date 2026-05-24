# feverless — Agent 指令

一款 SwiftUI/SwiftData iOS 应用，专为凌晨三点追踪儿童发烧和用药而设计。支持多儿童档案、体温记录、用药安全检查、CloudKit iCloud 同步及主屏 Widget。

## 构建与测试

通过 Xcode 或 `xcodebuild` 构建和测试。

Xcode 项目：`feverless/feverless.xcodeproj`  
Target：`feverless`（主应用）、`feverlessWidget`（Widget Extension）

## 架构

MVVM + SwiftData。App Group `group.top.dropx.feverless`，`feverless.store` 在主应用与 Widget 之间共享。

```
Models/       — @Model SwiftData 类（Child, DataRecord, TemperatureReading, MedicationUsage, ...）
Services/     — ObservableObject 单例（MedicationCatalog, TemperaturePositionCatalog, CSVImporter/Exporter）
ViewModels/   — （MedicationSafetyViewModel）
Utilities/    — FeverEpisodeDetector
Views/
  Chart/   Home/   Profile/   Record/
feverlessWidget/  — Widget Extension（TimelineProvider，Small + Medium 视图）
```

**ModelContainer schema**（需与 `feverlessApp.swift` 保持同步）：
`[Child.self, DataRecord.self, TemperatureReading.self, MedicationUsage.self, MedicationDefinition.self, TemperaturePositionDefinition.self, ImportMapping.self]`

CloudKit 同步策略：优先使用 `.automatic`，失败时降级为 `.none`。若 `ModelContainer` 初始化抛出异常，则删除 App Group 路径下的 `.store` 文件并以空容器重新初始化；CloudKit 将在下次同步时重新下载数据。

## 关键约定

**视图双模式呈现**：视图接受 `isSheet: Bool` 参数，在 sheet 模式下显示"完成"关闭按钮，在 push 模式下使用系统返回导航。任何可同时从 `.sheet` 和 `NavigationLink` 打开的视图均应使用此模式。

**Catalog 生命周期**：在 `App.init()` 中调用 `catalog.load()`。仅在**直接修改 catalog 数据的根级视图**（如 `MedicationCatalogView`、`TemperaturePositionCatalogView`）的 `.onDisappear` 中调用 `catalog.save()`，不要在每个使用 catalog 的视图中都添加 save 调用。`MedicationCatalog` 和 `TemperaturePositionCatalog` 均遵循此模式。

**服务**：`static let shared` 单例，`ObservableObject` + `@Published`。`MedicationCatalog` 和 `TemperaturePositionCatalog` 服务通过 UserDefaults（key：`medication_catalog_v1`、`temperature_position_catalog_v1`）序列化其内存状态，这是 catalog 服务层的持久化方式。对应的 `MedicationDefinition` 和 `TemperaturePositionDefinition` 同时作为 SwiftData 模型存在于 schema 中（供未来 CloudKit 同步使用）；读写 catalog 数据时应通过服务单例而非直接操作 SwiftData。

**CSV**：一行 CSV = 一条 `DataRecord`，可包含多条 `TemperatureReading` 和 `MedicationUsage` 子记录。导入使用 `ImportAliasTable` + `MedicationKeywordMatcher` 进行模糊列/值匹配。

**关键词渲染 Bug**：在 catalog 列表视图中添加关键词后，需显式调用 `objectWillChange.send()` 或切换本地 `@State` 标志来强制重新渲染。这是本项目中已知的 SwiftUI 列表刷新问题。

## 任务完成规范

每次任务（包括代码修改、重构、功能实现等）完成后，必须通过 `mcp_xcode-tools_XcodeListNavigatorIssues` 或 `mcp_xcode-tools_XcodeRefreshCodeIssuesInFile` 确认 Xcode 中无编译报错。若存在报错，须立即修复后再回复用户。

## openspec 工作流

本项目采用规格驱动的 AI 工作流，所有重要变更均通过 openspec 进行：

| 目录 | 用途 |
|------|------|
| `openspec/specs/` | 长期权威能力规格文档 |
| `openspec/changes/` | 活跃变更（proposal → design → tasks → implementation） |
| `openspec/changes/archive/` | 已完成变更的归档 |

**Skills**（通过 `/` 调用）：
- `/openspec-propose` — 提出新变更
- `/openspec-apply-change` — 实施变更中的任务
- `/openspec-explore` — 变更前的思路探索
- `/openspec-archive-change` — 实施完成后归档变更

实施变更时，始终查阅 `openspec/changes/<name>/tasks.md` 的任务清单，以及 `openspec/changes/<name>/specs/` 中覆盖全局规格的本地规格。

## 数据模型参考

权威数据模型规格见 [`openspec/specs/data-models/`](openspec/specs/data-models/)。

核心关系：
- `Child` 通过 `childId` 拥有多条 `DataRecord`
- `DataRecord` 通过 `@Relationship(deleteRule: .cascade)` 关联 `[TemperatureReading]` 和 `[MedicationUsage]`
- Catalog 定义（`MedicationDefinition`、`TemperaturePositionDefinition`）存在于 SwiftData schema 中；但当前读写均通过 `MedicationCatalog`/`TemperaturePositionCatalog` 服务（UserDefaults）完成，不直接查询 SwiftData
